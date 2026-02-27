package ai.openclix.engine

import ai.openclix.models.Campaign
import ai.openclix.models.CampaignStateRecord
import ai.openclix.models.CampaignStateSnapshot
import ai.openclix.models.DayOfWeek
import ai.openclix.models.DecisionTrace
import ai.openclix.models.QueuedMessage
import ai.openclix.models.QueuedMessageContent
import ai.openclix.models.QueuedMessageStatus
import ai.openclix.models.RecurringTriggerConfig
import ai.openclix.models.Settings
import ai.openclix.models.SkipReason
import ai.openclix.models.TriggerContext
import ai.openclix.models.TriggerType
import ai.openclix.models.ClixLogger
import ai.openclix.services.renderTemplate
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

data class CampaignDecision(
    val trace: DecisionTrace,
    val action: String,
    val queued_message: QueuedMessage? = null,
    val scheduled_for: String? = null
)

data class CampaignProcessorDependencies(
    val eventConditionProcessor: EventConditionProcessor,
    val scheduleCalculator: ScheduleCalculator,
    val logger: ClixLogger,
    val settings: Settings? = null
)

private data class ExecutionResolution(
    val execute_at: String? = null,
    val scheduled_for: String? = null,
    val trigger_event_id: String? = null,
    val reason: String? = null,
    val skip_reason: SkipReason? = null
)

private fun createTrace(
    campaign_id: String,
    action: String,
    result: String,
    reason: String,
    skip_reason: SkipReason? = null
): DecisionTrace = DecisionTrace(
    campaign_id = campaign_id,
    action = action,
    result = result,
    skip_reason = skip_reason,
    reason = reason
)

private fun createSkipDecision(
    campaignId: String,
    reason: String,
    skipReason: SkipReason? = null
): CampaignDecision {
    return CampaignDecision(
        action = "skip",
        trace = createTrace(
            campaign_id = campaignId,
            action = "skip_campaign",
            result = "skipped",
            reason = reason,
            skip_reason = skipReason
        )
    )
}

private fun parseIso8601OrNull(isoString: String?): Long? {
    if (isoString.isNullOrBlank()) return null

    val formats = listOf(
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'Z'"
    )

    for (pattern in formats) {
        try {
            val formatter = SimpleDateFormat(pattern, Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
                isLenient = false
            }
            val parsedDate = formatter.parse(isoString)
            if (parsedDate != null) {
                return parsedDate.time
            }
        } catch (_: Exception) {
            continue
        }
    }

    return null
}

private fun startOfWeek(date: Date): Date {
    val calendar = Calendar.getInstance().apply {
        time = date
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        add(Calendar.DAY_OF_MONTH, -get(Calendar.DAY_OF_WEEK) + Calendar.SUNDAY)
    }
    return calendar.time
}

private fun withTime(baseDate: Date, hour: Int, minute: Int): Date {
    val calendar = Calendar.getInstance().apply {
        time = baseDate
        set(Calendar.HOUR_OF_DAY, hour)
        set(Calendar.MINUTE, minute)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }
    return calendar.time
}

class CampaignProcessor {

    fun process(
        campaignId: String,
        campaign: Campaign,
        context: TriggerContext,
        snapshot: CampaignStateSnapshot,
        dependencies: CampaignProcessorDependencies
    ): CampaignDecision {
        val eventConditionProcessor = dependencies.eventConditionProcessor
        val scheduleCalculator = dependencies.scheduleCalculator
        val logger = dependencies.logger
        val settings = dependencies.settings

        val now = context.now ?: toIso8601(System.currentTimeMillis())
        val campaignState = getCampaignState(snapshot, campaignId)

        if (campaign.status.value != "running") {
            val reason = "Campaign status is '${campaign.status.value}', not 'running'"
            logger.debug("[CampaignProcessor] Campaign $campaignId skipped: $reason")
            return createSkipDecision(campaignId, reason, SkipReason.CAMPAIGN_NOT_RUNNING)
        }

        if (
            (campaign.trigger.type == TriggerType.EVENT && context.trigger != "event_tracked") ||
            (campaign.trigger.type != TriggerType.EVENT && context.trigger == "event_tracked")
        ) {
            val reason = "Trigger type '${campaign.trigger.type.value}' is not eligible for '${context.trigger}'"
            logger.debug("[CampaignProcessor] Campaign $campaignId skipped: $reason")
            return createSkipDecision(campaignId, reason)
        }

        if (campaign.trigger.type != TriggerType.RECURRING && campaignState?.triggered == true) {
            val reason = "Campaign already triggered"
            logger.debug("[CampaignProcessor] Campaign $campaignId skipped: $reason")
            return createSkipDecision(campaignId, reason)
        }

        if (settings?.frequency_cap != null) {
            val frequencyCap = settings.frequency_cap
            val windowStartEpoch = parseIso8601(now) - frequencyCap.window_seconds * 1000L
            val windowStart = toIso8601(windowStartEpoch)
            val countInWindow = snapshot.trigger_history.count { historyRow ->
                historyRow.triggered_at >= windowStart
            }

            if (countInWindow >= frequencyCap.max_count) {
                val reason = "Frequency cap exceeded ($countInWindow/${frequencyCap.max_count} within ${frequencyCap.window_seconds}s)"
                logger.debug("[CampaignProcessor] Campaign $campaignId skipped: $reason")
                return createSkipDecision(
                    campaignId,
                    reason,
                    SkipReason.CAMPAIGN_FREQUENCY_CAP_EXCEEDED
                )
            }
        }

        if (campaign.trigger.type == TriggerType.RECURRING && hasFuturePendingForCampaign(snapshot, campaignId, now)) {
            val reason = "Recurring campaign already has a queued message"
            logger.debug("[CampaignProcessor] Campaign $campaignId skipped: $reason")
            return createSkipDecision(campaignId, reason)
        }

        val executionResolution = resolveExecutionTime(
            campaign = campaign,
            context = context,
            campaignState = campaignState,
            now = now,
            eventConditionProcessor = eventConditionProcessor
        )

        if (executionResolution.execute_at == null) {
            val reason = executionResolution.reason ?: "Campaign trigger conditions were not met"
            logger.debug("[CampaignProcessor] Campaign $campaignId skipped: $reason")
            return createSkipDecision(campaignId, reason, executionResolution.skip_reason)
        }

        if (hasPendingForCampaignAt(snapshot, campaignId, executionResolution.execute_at)) {
            val reason = "Duplicate schedule prevented for campaign at ${executionResolution.execute_at}"
            logger.debug("[CampaignProcessor] Campaign $campaignId skipped: $reason")
            return createSkipDecision(campaignId, reason)
        }

        val scheduleResult = scheduleCalculator.calculate(
            ScheduleInput(
                now = now,
                execute_at = executionResolution.execute_at,
                do_not_disturb = settings?.do_not_disturb
            )
        )

        if (scheduleResult.skipped) {
            val reason = "Blocked by do-not-disturb window"
            logger.debug("[CampaignProcessor] Campaign $campaignId skipped: $reason")
            return createSkipDecision(
                campaignId,
                reason,
                scheduleResult.skip_reason
            )
        }

        val templateVariables = mutableMapOf<String, Any?>()
        context.event?.properties?.let { eventProperties ->
            templateVariables.putAll(eventProperties)
        }

        val renderedTitle = renderTemplate(campaign.message.content.title, templateVariables)
        val renderedBody = renderTemplate(campaign.message.content.body, templateVariables)

        val queuedMessage = QueuedMessage(
            id = UUID.randomUUID().toString(),
            campaign_id = campaignId,
            channel_type = campaign.message.channel_type,
            status = QueuedMessageStatus.SCHEDULED,
            content = QueuedMessageContent(
                title = renderedTitle,
                body = renderedBody,
                image_url = campaign.message.content.image_url,
                landing_url = campaign.message.content.landing_url
            ),
            trigger_event_id = executionResolution.trigger_event_id,
            execute_at = scheduleResult.execute_at,
            created_at = now
        )

        logger.debug(
            "[CampaignProcessor] Campaign $campaignId: triggered, scheduled for ${scheduleResult.execute_at}"
        )

        return CampaignDecision(
            action = "trigger",
            trace = createTrace(
                campaign_id = campaignId,
                action = "trigger_campaign",
                result = "applied",
                reason = "Campaign triggered, message scheduled for ${scheduleResult.execute_at}"
            ),
            queued_message = queuedMessage,
            scheduled_for = executionResolution.scheduled_for ?: scheduleResult.execute_at
        )
    }

    private fun resolveExecutionTime(
        campaign: Campaign,
        context: TriggerContext,
        campaignState: CampaignStateRecord?,
        now: String,
        eventConditionProcessor: EventConditionProcessor
    ): ExecutionResolution {
        if (campaign.trigger.type == TriggerType.EVENT) {
            val eventConfig = campaign.trigger.event
            if (eventConfig == null) {
                return ExecutionResolution(
                    reason = "Trigger type 'event' requires trigger.event configuration",
                    skip_reason = SkipReason.TRIGGER_EVENT_NOT_MATCHED
                )
            }

            if (context.event == null) {
                return ExecutionResolution(
                    reason = "Event trigger requires an event in context",
                    skip_reason = SkipReason.TRIGGER_EVENT_NOT_MATCHED
                )
            }

            val isMatched = eventConditionProcessor.process(eventConfig.trigger_event, context.event)
            if (!isMatched) {
                return ExecutionResolution(
                    reason = "Trigger event conditions did not match event '${context.event.name}'",
                    skip_reason = SkipReason.TRIGGER_EVENT_NOT_MATCHED
                )
            }

            val delaySeconds = eventConfig.delay_seconds ?: 0
            val executeAt = toIso8601(parseIso8601(now) + delaySeconds * 1000L)
            return ExecutionResolution(
                execute_at = executeAt,
                scheduled_for = executeAt,
                trigger_event_id = context.event.id
            )
        }

        if (campaign.trigger.type == TriggerType.SCHEDULED) {
            val scheduledConfig = campaign.trigger.scheduled
            if (scheduledConfig == null || parseIso8601OrNull(scheduledConfig.execute_at) == null) {
                return ExecutionResolution(
                    reason = "Scheduled trigger requires a valid execute_at datetime"
                )
            }

            val executeAtEpoch = parseIso8601OrNull(scheduledConfig.execute_at) ?: return ExecutionResolution(
                reason = "Scheduled trigger requires a valid execute_at datetime"
            )
            val nowEpoch = parseIso8601(now)
            if (executeAtEpoch <= nowEpoch) {
                return ExecutionResolution(
                    reason = "Scheduled execute_at '${scheduledConfig.execute_at}' is already in the past"
                )
            }

            return ExecutionResolution(
                execute_at = scheduledConfig.execute_at,
                scheduled_for = scheduledConfig.execute_at
            )
        }

        val recurringConfig = campaign.trigger.recurring
        if (recurringConfig == null) {
            return ExecutionResolution(reason = "Recurring trigger requires recurring configuration")
        }

        val nextExecuteAt = computeNextRecurringExecuteAt(
            recurring = recurringConfig,
            now = now,
            lastScheduledAt = campaignState?.recurring_last_scheduled_at,
            recurringAnchorAt = campaignState?.recurring_anchor_at
        )

        if (nextExecuteAt == null) {
            return ExecutionResolution(reason = "Recurring schedule has no upcoming execution window")
        }

        return ExecutionResolution(
            execute_at = nextExecuteAt,
            scheduled_for = nextExecuteAt
        )
    }

    private fun computeNextRecurringExecuteAt(
        recurring: RecurringTriggerConfig,
        now: String,
        lastScheduledAt: String?,
        recurringAnchorAt: String?
    ): String? {
        val nowEpoch = parseIso8601OrNull(now) ?: return null
        val nowDate = Date(nowEpoch)

        val startDate = when {
            parseIso8601OrNull(recurring.start_at) != null -> Date(parseIso8601OrNull(recurring.start_at)!!)
            parseIso8601OrNull(recurringAnchorAt) != null -> Date(parseIso8601OrNull(recurringAnchorAt)!!)
            else -> computeDefaultRecurringAnchorDate(recurring, nowDate)
        }

        val endEpoch = if (recurring.end_at.isNullOrBlank()) {
            Long.MAX_VALUE
        } else {
            parseIso8601OrNull(recurring.end_at) ?: return null
        }

        val fromDate = if (parseIso8601OrNull(lastScheduledAt) != null) {
            Date(parseIso8601OrNull(lastScheduledAt)!! + 60_000L)
        } else {
            nowDate
        }

        val interval = maxOf(1, recurring.rule.interval)
        val nextOccurrence = findNextOccurrence(recurring, startDate, fromDate, interval) ?: return null
        if (nextOccurrence.time > endEpoch) return null

        return toIso8601(nextOccurrence.time)
    }

    private fun computeDefaultRecurringAnchorDate(recurring: RecurringTriggerConfig, nowDate: Date): Date {
        val anchorCalendar = Calendar.getInstance().apply {
            time = nowDate
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        if (recurring.rule.type.value == "hourly") {
            anchorCalendar.set(Calendar.MINUTE, 0)
            return anchorCalendar.time
        }

        if (recurring.rule.type.value == "daily") {
            val hour = recurring.rule.time_of_day?.hour ?: anchorCalendar.get(Calendar.HOUR_OF_DAY)
            val minute = recurring.rule.time_of_day?.minute ?: anchorCalendar.get(Calendar.MINUTE)
            anchorCalendar.set(Calendar.HOUR_OF_DAY, hour)
            anchorCalendar.set(Calendar.MINUTE, minute)
            return anchorCalendar.time
        }

        val hour = recurring.rule.time_of_day?.hour ?: anchorCalendar.get(Calendar.HOUR_OF_DAY)
        val minute = recurring.rule.time_of_day?.minute ?: anchorCalendar.get(Calendar.MINUTE)
        val weekStartDate = startOfWeek(anchorCalendar.time)
        return withTime(weekStartDate, hour, minute)
    }

    private fun findNextOccurrence(
        recurring: RecurringTriggerConfig,
        startDate: Date,
        fromDate: Date,
        interval: Int
    ): Date? {
        val recurrenceRule = recurring.rule

        if (recurrenceRule.type.value == "hourly") {
            val baseMilliseconds = startDate.time
            val fromMilliseconds = maxOf(fromDate.time, baseMilliseconds)
            val intervalMilliseconds = interval * 60L * 60L * 1000L
            val steps = if (fromMilliseconds <= baseMilliseconds) {
                0L
            } else {
                kotlin.math.ceil((fromMilliseconds - baseMilliseconds).toDouble() / intervalMilliseconds.toDouble()).toLong()
            }
            return Date(baseMilliseconds + steps * intervalMilliseconds)
        }

        if (recurrenceRule.type.value == "daily") {
            val hour = recurrenceRule.time_of_day?.hour ?: Calendar.getInstance().apply { time = startDate }.get(Calendar.HOUR_OF_DAY)
            val minute = recurrenceRule.time_of_day?.minute ?: Calendar.getInstance().apply { time = startDate }.get(Calendar.MINUTE)
            var candidate = withTime(startDate, hour, minute)
            if (candidate.before(fromDate)) {
                val dayMilliseconds = 24L * 60L * 60L * 1000L
                val deltaDays = ((fromDate.time - candidate.time) / dayMilliseconds).toInt()
                val steps = deltaDays / interval
                candidate = Date(candidate.time + steps * interval * dayMilliseconds)
                while (candidate.before(fromDate)) {
                    candidate = Date(candidate.time + interval * dayMilliseconds)
                }
            }
            return candidate
        }

        if (recurrenceRule.type.value == "weekly") {
            val daysOfWeek = recurrenceRule.weekly_rule?.days_of_week ?: emptyList()
            if (daysOfWeek.isEmpty()) return null

            val allowedDays = daysOfWeek
                .map(DayOfWeek::index)
                .distinct()
                .sorted()
            val startCalendar = Calendar.getInstance().apply { time = startDate }
            val hour = recurrenceRule.time_of_day?.hour ?: startCalendar.get(Calendar.HOUR_OF_DAY)
            val minute = recurrenceRule.time_of_day?.minute ?: startCalendar.get(Calendar.MINUTE)

            val weekMilliseconds = 7L * 24L * 60L * 60L * 1000L
            val anchorWeekStartMilliseconds = startOfWeek(startDate).time
            val fromWeekStartMilliseconds = startOfWeek(fromDate).time
            val rawWeekDiff = kotlin.math.floor(
                (fromWeekStartMilliseconds - anchorWeekStartMilliseconds).toDouble() / weekMilliseconds.toDouble()
            ).toInt()
            val baselineWeekDiff = maxOf(0, rawWeekDiff)
            val remainder = baselineWeekDiff % interval
            var alignedWeekDiff = if (remainder == 0) {
                baselineWeekDiff
            } else {
                baselineWeekDiff + (interval - remainder)
            }

            repeat(2) {
                val weekStartDate = Date(anchorWeekStartMilliseconds + alignedWeekDiff * weekMilliseconds)
                var earliestCandidate: Date? = null

                for (dayIndex in allowedDays) {
                    val candidateCalendar = Calendar.getInstance().apply {
                        time = weekStartDate
                        add(Calendar.DAY_OF_MONTH, dayIndex)
                        set(Calendar.HOUR_OF_DAY, hour)
                        set(Calendar.MINUTE, minute)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }
                    val candidate = candidateCalendar.time

                    if (candidate.before(startDate) || candidate.before(fromDate)) continue
                    if (earliestCandidate == null || candidate.before(earliestCandidate)) {
                        earliestCandidate = candidate
                    }
                }

                if (earliestCandidate != null) {
                    return earliestCandidate
                }

                alignedWeekDiff += interval
            }

            return null
        }

        return null
    }

    private fun hasPendingForCampaignAt(
        snapshot: CampaignStateSnapshot,
        campaignId: String,
        executeAt: String
    ): Boolean {
        return snapshot.queued_messages.any { queuedMessage ->
            queuedMessage.campaign_id == campaignId && queuedMessage.execute_at == executeAt
        }
    }

    private fun hasFuturePendingForCampaign(
        snapshot: CampaignStateSnapshot,
        campaignId: String,
        now: String
    ): Boolean {
        val nowEpoch = parseIso8601OrNull(now)
        for (pendingMessage in snapshot.queued_messages) {
            if (pendingMessage.campaign_id != campaignId) continue

            val executeAtEpoch = parseIso8601OrNull(pendingMessage.execute_at)
            if (executeAtEpoch == null) return true
            if (nowEpoch != null && executeAtEpoch >= nowEpoch) return true
        }
        return false
    }

    private fun getCampaignState(
        snapshot: CampaignStateSnapshot,
        campaignId: String
    ): CampaignStateRecord? {
        return snapshot.campaign_states.firstOrNull { row -> row.campaign_id == campaignId }
    }
}
