import Foundation

public struct TriggerServiceDependencies {
    public let campaignStateRepository: ClixCampaignStateRepository
    public let messageScheduler: ClixMessageScheduler
    public let clock: ClixClock
    public let logger: ClixLogger
    public let recordEvent: ((Event) async -> Void)?

    public init(
        campaignStateRepository: ClixCampaignStateRepository,
        messageScheduler: ClixMessageScheduler,
        clock: ClixClock,
        logger: ClixLogger,
        recordEvent: ((Event) async -> Void)? = nil
    ) {
        self.campaignStateRepository = campaignStateRepository
        self.messageScheduler = messageScheduler
        self.clock = clock
        self.logger = logger
        self.recordEvent = recordEvent
    }
}

private let maximumTriggerHistorySize = 5_000

public actor TriggerService {

    private var config: Config?

    private let eventConditionProcessor: EventConditionProcessor
    private let scheduleCalculator: ScheduleCalculator
    private let campaignProcessor: CampaignProcessor
    private let campaignStateService: CampaignStateService
    private let dependencies: TriggerServiceDependencies

    public init(
        dependencies: TriggerServiceDependencies,
        campaignStateService: CampaignStateService = CampaignStateService()
    ) {
        self.dependencies = dependencies
        self.eventConditionProcessor = EventConditionProcessor()
        self.scheduleCalculator = ScheduleCalculator()
        self.campaignProcessor = CampaignProcessor()
        self.campaignStateService = campaignStateService
    }

    public func replaceConfig(_ config: Config) {
        self.config = config
        dependencies.logger.info(
            "[TriggerService] Config replaced (version: \(config.config_version), campaigns: \(config.campaigns.count))"
        )
    }

    public func getConfig() -> Config? {
        return config
    }

    public func trigger(_ triggerContext: TriggerContext) async -> TriggerResult {
        guard let config = self.config else {
            dependencies.logger.debug("[TriggerService] No config loaded, returning empty report")
            let now = triggerContext.now ?? dependencies.clock.now()
            return TriggerResult(
                evaluated_at: now,
                trigger: triggerContext.trigger.rawValue,
                traces: [],
                queued_messages: []
            )
        }

        let now = triggerContext.now ?? dependencies.clock.now()

        var snapshot: CampaignStateSnapshot
        do {
            snapshot = try await dependencies.campaignStateRepository.loadSnapshot(now: now)
        } catch {
            dependencies.logger.warn(
                "[TriggerService] Failed to load campaign state snapshot:",
                error.localizedDescription
            )
            snapshot = createDefaultCampaignStateSnapshot(now: now)
        }

        var traces: [DecisionTrace] = []
        var queuedMessages: [QueuedMessage] = []

        if triggerContext.trigger != .event_tracked {
            snapshot = await reconcileQueuedMessages(snapshot: snapshot)
        }

        if triggerContext.trigger == .event_tracked,
           let event = triggerContext.event {
            let cancellationResult = await cancelQueuedMessages(
                event: event,
                snapshot: snapshot
            )
            snapshot = cancellationResult.snapshot
            traces.append(contentsOf: cancellationResult.traces)
        }

        dependencies.logger.debug(
            "[TriggerService] Processing \(config.campaigns.count) campaigns"
        )

        for (campaignId, campaign) in config.campaigns {
            let decision = campaignProcessor.process(
                campaignId: campaignId,
                campaign: campaign,
                context: triggerContext,
                snapshot: snapshot,
                dependencies: CampaignProcessorDependencies(
                    eventConditionProcessor: eventConditionProcessor,
                    scheduleCalculator: scheduleCalculator,
                    logger: dependencies.logger,
                    settings: config.settings
                )
            )

            traces.append(decision.trace)
            dependencies.logger.debug(
                "[TriggerService] Campaign \(campaignId) decision: action=\(decision.action), result=\(decision.trace.result.rawValue), reason=\(decision.trace.reason)"
            )

            guard decision.action == .trigger,
                  let queuedMessage = decision.queued_message else {
                continue
            }

            do {
                try await dependencies.messageScheduler.schedule(queuedMessage)
            } catch {
                await emitSystemEvent(
                    name: .clixMessageFailed,
                    properties: [
                        "campaign_id": .string(campaignId),
                        "queued_message_id": .string(queuedMessage.id),
                        "channel_type": .string(queuedMessage.channel_type.rawValue),
                        "failure_reason": .string(error.localizedDescription),
                    ],
                    createdAt: now
                )
                dependencies.logger.error(
                    "[TriggerService] Error scheduling message for campaign \(campaignId):",
                    error.localizedDescription
                )
                continue
            }

            snapshot = campaignStateService.applyQueuedMessage(
                ApplyQueuedMessageParameters(
                    snapshot: snapshot,
                    campaign_id: campaignId,
                    trigger_type: campaign.trigger.type,
                    queued_message: queuedMessage,
                    now: now,
                    scheduled_for: decision.scheduled_for,
                    max_trigger_history: maximumTriggerHistorySize
                )
            )

            await emitSystemEvent(
                name: .clixMessageScheduled,
                properties: [
                    "campaign_id": .string(campaignId),
                    "queued_message_id": .string(queuedMessage.id),
                    "channel_type": .string(queuedMessage.channel_type.rawValue),
                    "execute_at": .string(queuedMessage.execute_at),
                ],
                createdAt: now
            )

            queuedMessages.append(queuedMessage)
        }

        snapshot.updated_at = now

        do {
            try await dependencies.campaignStateRepository.saveSnapshot(snapshot)
        } catch {
            dependencies.logger.error(
                "[TriggerService] Failed to persist campaign state snapshot:",
                error.localizedDescription
            )
        }

        let triggerResult = TriggerResult(
            evaluated_at: now,
            trigger: triggerContext.trigger.rawValue,
            traces: traces,
            queued_messages: queuedMessages
        )

        dependencies.logger.debug(
            "[TriggerService] Trigger complete: \(traces.count) traces, \(queuedMessages.count) messages queued"
        )

        return triggerResult
    }

    private func reconcileQueuedMessages(
        snapshot: CampaignStateSnapshot
    ) async -> CampaignStateSnapshot {
        let pendingMessages: [QueuedMessage]

        do {
            pendingMessages = try await dependencies.messageScheduler.listPending()
        } catch {
            dependencies.logger.warn(
                "[TriggerService] Failed to reconcile pending scheduler records:",
                error.localizedDescription
            )
            return snapshot
        }

        return campaignStateService.reconcileQueuedMessages(
            ReconcileQueuedMessagesParameters(
                snapshot: snapshot,
                scheduler_pending_messages: pendingMessages,
                resolve_trigger_type: { campaignId in
                    self.config?.campaigns[campaignId]?.trigger.type
                }
            )
        )
    }

    private func cancelQueuedMessages(
        event: Event,
        snapshot: CampaignStateSnapshot
    ) async -> (snapshot: CampaignStateSnapshot, traces: [DecisionTrace]) {
        guard let config = self.config,
              !snapshot.queued_messages.isEmpty else {
            return (snapshot, [])
        }

        var updatedSnapshot = snapshot
        var traces: [DecisionTrace] = []

        for pendingMessage in snapshot.queued_messages {
            guard let campaign = config.campaigns[pendingMessage.campaign_id] else {
                updatedSnapshot = campaignStateService.removeQueuedMessage(
                    updatedSnapshot,
                    message_id: pendingMessage.message_id
                )
                continue
            }

            guard campaign.trigger.type == .event,
                  let cancelEvent = campaign.trigger.event?.cancel_event else {
                continue
            }

            let isMatched = eventConditionProcessor.process(
                group: cancelEvent,
                event: event
            )

            guard isMatched else { continue }
            guard isWithinCancellationWindow(event: event, pendingMessage: pendingMessage) else {
                continue
            }

            do {
                try await dependencies.messageScheduler.cancel(pendingMessage.message_id)
                updatedSnapshot = campaignStateService.removeQueuedMessage(
                    updatedSnapshot,
                    message_id: pendingMessage.message_id
                )
                updatedSnapshot = campaignStateService.markCampaignUntriggered(
                    updatedSnapshot,
                    campaign_id: pendingMessage.campaign_id
                )

                traces.append(
                    DecisionTrace(
                        campaign_id: pendingMessage.campaign_id,
                        action: "cancel_message",
                        result: .applied,
                        skip_reason: .trigger_cancel_event_matched,
                        reason:
                            "Cancelled queued message \(pendingMessage.message_id) for campaign \(pendingMessage.campaign_id) "
                            + "because event '\(event.name)' matched cancel_event"
                    )
                )

                await emitSystemEvent(
                    name: .clixMessageCancelled,
                    properties: [
                        "campaign_id": .string(pendingMessage.campaign_id),
                        "queued_message_id": .string(pendingMessage.message_id),
                        "skip_reason": .string(SkipReason.trigger_cancel_event_matched.rawValue),
                    ],
                    createdAt: event.created_at
                )

                dependencies.logger.debug(
                    "[TriggerService] Cancelled queued message \(pendingMessage.message_id) for campaign \(pendingMessage.campaign_id)"
                )
            } catch {
                await emitSystemEvent(
                    name: .clixMessageFailed,
                    properties: [
                        "campaign_id": .string(pendingMessage.campaign_id),
                        "queued_message_id": .string(pendingMessage.message_id),
                        "channel_type": .string(campaign.message.channel_type.rawValue),
                        "failure_reason": .string(error.localizedDescription),
                    ],
                    createdAt: event.created_at
                )

                dependencies.logger.warn(
                    "[TriggerService] Failed to cancel queued message \(pendingMessage.message_id):",
                    error.localizedDescription
                )
            }
        }

        return (updatedSnapshot, traces)
    }

    private func isWithinCancellationWindow(
        event: Event,
        pendingMessage: CampaignQueuedMessage
    ) -> Bool {
        guard let cancellationTimestamp = parseTimestamp(event.created_at),
              let windowStartTimestamp = parseTimestamp(pendingMessage.created_at),
              let windowEndTimestamp = parseTimestamp(pendingMessage.execute_at) else {
            return false
        }

        return cancellationTimestamp >= windowStartTimestamp
            && cancellationTimestamp <= windowEndTimestamp
    }

    private func parseTimestamp(_ value: String?) -> TimeInterval? {
        guard let value, !value.isEmpty else { return nil }

        let internetFormatter = ISO8601DateFormatter()
        internetFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsedDate = internetFormatter.date(from: value) {
            return parsedDate.timeIntervalSince1970
        }

        let fallbackFormatter = ISO8601DateFormatter()
        return fallbackFormatter.date(from: value)?.timeIntervalSince1970
    }

    private func emitSystemEvent(
        name: SystemEventName,
        properties: [String: JsonValue?],
        createdAt: String
    ) async {
        guard let recordEvent = dependencies.recordEvent else { return }

        var normalizedProperties: [String: JsonValue] = [:]
        for (key, value) in properties {
            if let value {
                normalizedProperties[key] = value
            }
        }

        await recordEvent(
            Event(
                id: generateUUID(),
                name: name.rawValue,
                source_type: .system,
                properties: normalizedProperties,
                created_at: createdAt
            )
        )
    }
}
