package ai.openclix.engine

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import ai.openclix.models.CampaignQueuedMessage
import ai.openclix.models.CampaignStateRecord
import ai.openclix.models.CampaignStateRepository
import ai.openclix.models.CampaignStateSnapshot
import ai.openclix.models.CampaignTriggerHistory
import ai.openclix.models.ClixClock
import ai.openclix.models.ClixLocalMessageScheduler
import ai.openclix.models.ClixLogger
import ai.openclix.models.Config
import ai.openclix.models.DecisionTrace
import ai.openclix.models.Event
import ai.openclix.models.QueuedMessage
import ai.openclix.models.SkipReason
import ai.openclix.models.SystemEventName
import ai.openclix.models.TriggerContext
import ai.openclix.models.TriggerResult
import ai.openclix.models.TriggerType
import java.util.UUID

data class TriggerServiceDependencies(
    val campaignStateRepository: CampaignStateRepository,
    val scheduler: ClixLocalMessageScheduler,
    val clock: ClixClock,
    val logger: ClixLogger,
    val recordEvent: (suspend (Event) -> Unit)? = null
)

private const val MAXIMUM_TRIGGER_HISTORY_SIZE = 5_000

class TriggerService(
    private val dependencies: TriggerServiceDependencies
) {
    private val mutex = Mutex()
    private var config: Config? = null

    private val eventConditionProcessor = EventConditionProcessor()
    private val scheduleCalculator = ScheduleCalculator()
    private val campaignProcessor = CampaignProcessor()

    fun replaceConfig(newConfig: Config) {
        config = newConfig
        dependencies.logger.info(
            "[TriggerService] Config replaced (version: ${newConfig.config_version}, campaigns: ${newConfig.campaigns.size})"
        )
    }

    fun getConfig(): Config? = config

    suspend fun trigger(triggerContext: TriggerContext): TriggerResult {
        return mutex.withLock {
            evaluateTrigger(triggerContext)
        }
    }

    private suspend fun evaluateTrigger(triggerContext: TriggerContext): TriggerResult {
        val campaignStateRepository = dependencies.campaignStateRepository
        val scheduler = dependencies.scheduler
        val clock = dependencies.clock
        val logger = dependencies.logger

        val loadedConfig = config
        if (loadedConfig == null) {
            logger.debug("[TriggerService] No config loaded, returning empty report")
            val now = triggerContext.now ?: clock.now()
            return TriggerResult(
                evaluated_at = now,
                trigger = triggerContext.trigger,
                traces = emptyList(),
                queued_messages = emptyList()
            )
        }

        val now = triggerContext.now ?: clock.now()
        val snapshot = campaignStateRepository.loadSnapshot(now)

        val traces = mutableListOf<DecisionTrace>()
        val queuedMessages = mutableListOf<QueuedMessage>()

        if (triggerContext.trigger != "event_tracked") {
            reconcileQueuedMessages(snapshot, logger)
        }

        if (triggerContext.trigger == "event_tracked" && triggerContext.event != null) {
            traces.addAll(cancelQueuedMessages(triggerContext.event, snapshot, now, logger))
        }

        logger.debug("[TriggerService] Processing ${loadedConfig.campaigns.size} campaigns")

        for ((campaignId, campaign) in loadedConfig.campaigns) {
            try {
                val decision = campaignProcessor.process(
                    campaignId = campaignId,
                    campaign = campaign,
                    context = triggerContext,
                    snapshot = snapshot,
                    dependencies = CampaignProcessorDependencies(
                        eventConditionProcessor = eventConditionProcessor,
                        scheduleCalculator = scheduleCalculator,
                        logger = logger,
                        settings = loadedConfig.settings
                    )
                )

                traces.add(decision.trace)
                logger.debug(
                    "[TriggerService] Campaign $campaignId decision: action=${decision.action}, result=${decision.trace.result}, reason=${decision.trace.reason}"
                )

                if (decision.action != "trigger" || decision.queued_message == null) {
                    continue
                }

                val queuedMessage = decision.queued_message
                try {
                    scheduler.schedule(queuedMessage)
                } catch (scheduleError: Exception) {
                    emitSystemEvent(
                        name = SystemEventName.MESSAGE_FAILED,
                        properties = mapOf(
                            "campaign_id" to campaignId,
                            "queued_message_id" to queuedMessage.id,
                            "channel_type" to queuedMessage.channel_type.value,
                            "failure_reason" to (scheduleError.message ?: scheduleError.toString())
                        ),
                        createdAt = now
                    )
                    logger.error(
                        "[TriggerService] Error scheduling message for campaign $campaignId:",
                        scheduleError
                    )
                    continue
                }

                applyQueuedMessage(
                    snapshot = snapshot,
                    campaignId = campaignId,
                    triggerType = campaign.trigger.type,
                    queuedMessage = queuedMessage,
                    now = now,
                    scheduledFor = decision.scheduled_for
                )

                emitSystemEvent(
                    name = SystemEventName.MESSAGE_SCHEDULED,
                    properties = mapOf(
                        "campaign_id" to campaignId,
                        "queued_message_id" to queuedMessage.id,
                        "channel_type" to queuedMessage.channel_type.value,
                        "execute_at" to queuedMessage.execute_at
                    ),
                    createdAt = now
                )

                queuedMessages.add(queuedMessage)
            } catch (error: Exception) {
                logger.error("[TriggerService] Error processing campaign $campaignId:", error)
            }
        }

        snapshot.updated_at = now
        try {
            campaignStateRepository.saveSnapshot(snapshot)
        } catch (error: Exception) {
            logger.error(
                "[TriggerService] Failed to persist campaign state snapshot:",
                error.message ?: error.toString()
            )
        }

        val triggerResult = TriggerResult(
            evaluated_at = now,
            trigger = triggerContext.trigger,
            traces = traces,
            queued_messages = queuedMessages
        )

        logger.debug(
            "[TriggerService] Trigger complete: ${traces.size} traces, ${queuedMessages.size} messages queued"
        )

        return triggerResult
    }

    private suspend fun reconcileQueuedMessages(
        snapshot: CampaignStateSnapshot,
        logger: ClixLogger
    ) {
        val pendingMessagesFromScheduler = try {
            dependencies.scheduler.listPending()
        } catch (error: Exception) {
            logger.warn(
                "[TriggerService] Failed to reconcile pending scheduler records:",
                error.message ?: error.toString()
            )
            return
        }

        val liveMessageIds = mutableSetOf<String>()

        for (pendingMessage in pendingMessagesFromScheduler) {
            liveMessageIds.add(pendingMessage.id)

            val existingQueuedMessage = getQueuedMessage(snapshot, pendingMessage.id)
            val inferredTriggerType = config?.campaigns?.get(pendingMessage.campaign_id)?.trigger?.type
                ?: TriggerType.EVENT

            upsertQueuedMessage(
                snapshot,
                CampaignQueuedMessage(
                    message_id = pendingMessage.id,
                    campaign_id = pendingMessage.campaign_id,
                    execute_at = pendingMessage.execute_at,
                    trigger_type = existingQueuedMessage?.trigger_type ?: inferredTriggerType,
                    trigger_event_id = existingQueuedMessage?.trigger_event_id ?: pendingMessage.trigger_event_id,
                    created_at = if (!existingQueuedMessage?.created_at.isNullOrBlank()) {
                        existingQueuedMessage!!.created_at
                    } else {
                        pendingMessage.created_at
                    }
                )
            )
        }

        snapshot.queued_messages.retainAll { queuedMessage ->
            liveMessageIds.contains(queuedMessage.message_id)
        }
    }

    private suspend fun cancelQueuedMessages(
        event: Event,
        snapshot: CampaignStateSnapshot,
        now: String,
        logger: ClixLogger
    ): List<DecisionTrace> {
        val traces = mutableListOf<DecisionTrace>()
        val pendingMessages = snapshot.queued_messages.toList()
        val loadedConfig = config ?: return traces

        for (pendingMessage in pendingMessages) {
            val campaign = loadedConfig.campaigns[pendingMessage.campaign_id]
            if (campaign == null) {
                removeQueuedMessage(snapshot, pendingMessage.message_id)
                continue
            }

            if (campaign.trigger.type != TriggerType.EVENT) continue

            val cancelEventGroup = campaign.trigger.event?.cancel_event ?: continue
            val isMatched = eventConditionProcessor.process(cancelEventGroup, event)
            if (!isMatched) continue
            if (!isWithinCancellationWindow(event, pendingMessage, now)) continue

            try {
                dependencies.scheduler.cancel(pendingMessage.message_id)
                removeQueuedMessage(snapshot, pendingMessage.message_id)
                markCampaignUntriggered(snapshot, pendingMessage.campaign_id)

                traces.add(
                    DecisionTrace(
                        campaign_id = pendingMessage.campaign_id,
                        action = "cancel_message",
                        result = "applied",
                        skip_reason = SkipReason.TRIGGER_CANCEL_EVENT_MATCHED,
                        reason = "Cancelled queued message ${pendingMessage.message_id} for campaign ${pendingMessage.campaign_id} " +
                                "because event '${event.name}' matched cancel_event"
                    )
                )

                emitSystemEvent(
                    name = SystemEventName.MESSAGE_CANCELLED,
                    properties = mapOf(
                        "campaign_id" to pendingMessage.campaign_id,
                        "queued_message_id" to pendingMessage.message_id,
                        "skip_reason" to SkipReason.TRIGGER_CANCEL_EVENT_MATCHED.value
                    ),
                    createdAt = event.created_at
                )

                logger.debug(
                    "[TriggerService] Cancelled queued message ${pendingMessage.message_id} for campaign ${pendingMessage.campaign_id}"
                )
            } catch (error: Exception) {
                emitSystemEvent(
                    name = SystemEventName.MESSAGE_FAILED,
                    properties = mapOf(
                        "campaign_id" to pendingMessage.campaign_id,
                        "queued_message_id" to pendingMessage.message_id,
                        "channel_type" to "app_push",
                        "failure_reason" to (error.message ?: error.toString())
                    ),
                    createdAt = event.created_at
                )
                logger.warn(
                    "[TriggerService] Failed to cancel queued message ${pendingMessage.message_id}:",
                    error.message ?: error.toString()
                )
            }
        }

        return traces
    }

    private fun isWithinCancellationWindow(
        event: Event,
        pendingMessage: CampaignQueuedMessage,
        now: String
    ): Boolean {
        val cancellationAtMilliseconds = parseTimestamp(event.created_at) ?: parseTimestamp(now)
        val windowStartMilliseconds = parseTimestamp(pendingMessage.created_at)
        val windowEndMilliseconds = parseTimestamp(pendingMessage.execute_at)

        if (cancellationAtMilliseconds == null || windowStartMilliseconds == null || windowEndMilliseconds == null) {
            return false
        }

        return cancellationAtMilliseconds >= windowStartMilliseconds &&
                cancellationAtMilliseconds <= windowEndMilliseconds
    }

    private fun parseTimestamp(value: String?): Long? {
        if (value.isNullOrBlank()) return null

        val formats = listOf(
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'"
        )

        for (pattern in formats) {
            try {
                val formatter = java.text.SimpleDateFormat(pattern, java.util.Locale.US).apply {
                    timeZone = java.util.TimeZone.getTimeZone("UTC")
                    isLenient = false
                }
                val parsedDate = formatter.parse(value)
                if (parsedDate != null) {
                    return parsedDate.time
                }
            } catch (_: Exception) {
                continue
            }
        }

        return null
    }

    private suspend fun emitSystemEvent(
        name: SystemEventName,
        properties: Map<String, Any?>,
        createdAt: String
    ) {
        val recordEvent = dependencies.recordEvent ?: return
        val compactProperties = mutableMapOf<String, Any?>()
        for ((key, value) in properties) {
            if (value != null) {
                compactProperties[key] = value
            }
        }

        try {
            recordEvent(
                Event(
                    id = UUID.randomUUID().toString(),
                    name = name.value,
                    source_type = ai.openclix.models.EventSourceType.SYSTEM,
                    properties = compactProperties,
                    created_at = createdAt
                )
            )
        } catch (error: Exception) {
            dependencies.logger.warn(
                "[TriggerService] Failed to persist system event '${name.value}':",
                error.message ?: error.toString()
            )
        }
    }

    private fun applyQueuedMessage(
        snapshot: CampaignStateSnapshot,
        campaignId: String,
        triggerType: TriggerType,
        queuedMessage: QueuedMessage,
        now: String,
        scheduledFor: String?
    ) {
        val campaignState = getCampaignState(snapshot, campaignId) ?: CampaignStateRecord(
            campaign_id = campaignId,
            triggered = false,
            delivery_count = 0
        )

        if (triggerType != TriggerType.RECURRING) {
            campaignState.triggered = true
        } else {
            campaignState.triggered = false
            campaignState.recurring_anchor_at =
                campaignState.recurring_anchor_at ?: (scheduledFor ?: queuedMessage.execute_at)
            campaignState.recurring_last_scheduled_at = scheduledFor ?: queuedMessage.execute_at
        }

        campaignState.delivery_count += 1
        campaignState.last_triggered_at = now
        upsertCampaignState(snapshot, campaignState)

        appendTriggerHistory(snapshot, campaignId, now, MAXIMUM_TRIGGER_HISTORY_SIZE)

        upsertQueuedMessage(
            snapshot,
            CampaignQueuedMessage(
                message_id = queuedMessage.id,
                campaign_id = queuedMessage.campaign_id,
                execute_at = queuedMessage.execute_at,
                trigger_type = triggerType,
                trigger_event_id = queuedMessage.trigger_event_id,
                created_at = queuedMessage.created_at
            )
        )
    }

    private fun getCampaignState(
        snapshot: CampaignStateSnapshot,
        campaignId: String
    ): CampaignStateRecord? {
        return snapshot.campaign_states.firstOrNull { state ->
            state.campaign_id == campaignId
        }
    }

    private fun upsertCampaignState(
        snapshot: CampaignStateSnapshot,
        state: CampaignStateRecord
    ) {
        val index = snapshot.campaign_states.indexOfFirst { row ->
            row.campaign_id == state.campaign_id
        }
        if (index >= 0) {
            snapshot.campaign_states[index] = state
        } else {
            snapshot.campaign_states.add(state)
        }
    }

    private fun getQueuedMessage(
        snapshot: CampaignStateSnapshot,
        messageId: String
    ): CampaignQueuedMessage? {
        return snapshot.queued_messages.firstOrNull { queued ->
            queued.message_id == messageId
        }
    }

    private fun upsertQueuedMessage(
        snapshot: CampaignStateSnapshot,
        queuedMessage: CampaignQueuedMessage
    ) {
        val index = snapshot.queued_messages.indexOfFirst { row ->
            row.message_id == queuedMessage.message_id
        }
        if (index >= 0) {
            snapshot.queued_messages[index] = queuedMessage
        } else {
            snapshot.queued_messages.add(queuedMessage)
        }
    }

    private fun removeQueuedMessage(
        snapshot: CampaignStateSnapshot,
        messageId: String
    ) {
        val index = snapshot.queued_messages.indexOfFirst { queuedMessage ->
            queuedMessage.message_id == messageId
        }
        if (index >= 0) {
            snapshot.queued_messages.removeAt(index)
        }
    }

    private fun markCampaignUntriggered(
        snapshot: CampaignStateSnapshot,
        campaignId: String
    ) {
        val campaignState = getCampaignState(snapshot, campaignId) ?: return
        campaignState.triggered = false
        upsertCampaignState(snapshot, campaignState)
    }

    private fun appendTriggerHistory(
        snapshot: CampaignStateSnapshot,
        campaignId: String,
        triggeredAt: String,
        maxTriggerHistory: Int
    ) {
        snapshot.trigger_history.add(
            CampaignTriggerHistory(
                campaign_id = campaignId,
                triggered_at = triggeredAt
            )
        )
        if (snapshot.trigger_history.size > maxTriggerHistory) {
            val overflow = snapshot.trigger_history.size - maxTriggerHistory
            repeat(overflow) {
                snapshot.trigger_history.removeAt(0)
            }
        }
    }
}
