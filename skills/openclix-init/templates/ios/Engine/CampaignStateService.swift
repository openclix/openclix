import Foundation

public struct ApplyQueuedMessageParameters {
    public let snapshot: CampaignStateSnapshot
    public let campaign_id: String
    public let trigger_type: TriggerType
    public let queued_message: QueuedMessage
    public let now: String
    public let scheduled_for: String?
    public let max_trigger_history: Int

    public init(
        snapshot: CampaignStateSnapshot,
        campaign_id: String,
        trigger_type: TriggerType,
        queued_message: QueuedMessage,
        now: String,
        scheduled_for: String? = nil,
        max_trigger_history: Int
    ) {
        self.snapshot = snapshot
        self.campaign_id = campaign_id
        self.trigger_type = trigger_type
        self.queued_message = queued_message
        self.now = now
        self.scheduled_for = scheduled_for
        self.max_trigger_history = max_trigger_history
    }
}

public struct ReconcileQueuedMessagesParameters {
    public let snapshot: CampaignStateSnapshot
    public let scheduler_pending_messages: [QueuedMessage]
    public let resolve_trigger_type: (String) -> TriggerType?

    public init(
        snapshot: CampaignStateSnapshot,
        scheduler_pending_messages: [QueuedMessage],
        resolve_trigger_type: @escaping (String) -> TriggerType?
    ) {
        self.snapshot = snapshot
        self.scheduler_pending_messages = scheduler_pending_messages
        self.resolve_trigger_type = resolve_trigger_type
    }
}

public final class CampaignStateService {

    public init() {}

    public func applyQueuedMessage(_ parameters: ApplyQueuedMessageParameters) -> CampaignStateSnapshot {
        var snapshot = parameters.snapshot

        var campaignState = getCampaignState(snapshot, campaignId: parameters.campaign_id)
            ?? CampaignStateRecord(
                campaign_id: parameters.campaign_id,
                triggered: false,
                delivery_count: 0
            )

        if parameters.trigger_type != .recurring {
            campaignState.triggered = true
        } else {
            campaignState.triggered = false
            campaignState.recurring_anchor_at = campaignState.recurring_anchor_at
                ?? (parameters.scheduled_for ?? parameters.queued_message.execute_at)
            campaignState.recurring_last_scheduled_at =
                parameters.scheduled_for ?? parameters.queued_message.execute_at
        }

        campaignState.delivery_count += 1
        campaignState.last_triggered_at = parameters.now
        upsertCampaignState(&snapshot, state: campaignState)

        appendTriggerHistory(
            &snapshot,
            campaignId: parameters.campaign_id,
            triggeredAt: parameters.now,
            maximumEntries: parameters.max_trigger_history
        )

        upsertQueuedMessage(
            &snapshot,
            queuedMessage: CampaignQueuedMessage(
                message_id: parameters.queued_message.id,
                campaign_id: parameters.queued_message.campaign_id,
                execute_at: parameters.queued_message.execute_at,
                trigger_type: parameters.trigger_type,
                trigger_event_id: parameters.queued_message.trigger_event_id,
                created_at: parameters.queued_message.created_at
            )
        )

        return snapshot
    }

    public func reconcileQueuedMessages(
        _ parameters: ReconcileQueuedMessagesParameters
    ) -> CampaignStateSnapshot {
        var snapshot = parameters.snapshot
        var liveMessageIds: Set<String> = []

        for pendingMessage in parameters.scheduler_pending_messages {
            liveMessageIds.insert(pendingMessage.id)

            let existing = getQueuedMessage(snapshot, messageId: pendingMessage.id)
            let inferredTriggerType =
                parameters.resolve_trigger_type(pendingMessage.campaign_id) ?? .event

            upsertQueuedMessage(
                &snapshot,
                queuedMessage: CampaignQueuedMessage(
                    message_id: pendingMessage.id,
                    campaign_id: pendingMessage.campaign_id,
                    execute_at: pendingMessage.execute_at,
                    trigger_type: existing?.trigger_type ?? inferredTriggerType,
                    trigger_event_id: existing?.trigger_event_id ?? pendingMessage.trigger_event_id,
                    created_at: existing?.created_at ?? pendingMessage.created_at
                )
            )
        }

        snapshot.queued_messages = snapshot.queued_messages.filter {
            liveMessageIds.contains($0.message_id)
        }

        return snapshot
    }

    public func removeQueuedMessage(
        _ snapshot: CampaignStateSnapshot,
        message_id: String
    ) -> CampaignStateSnapshot {
        var updatedSnapshot = snapshot
        updatedSnapshot.queued_messages.removeAll { $0.message_id == message_id }
        return updatedSnapshot
    }

    public func markCampaignUntriggered(
        _ snapshot: CampaignStateSnapshot,
        campaign_id: String
    ) -> CampaignStateSnapshot {
        var updatedSnapshot = snapshot
        guard var campaignState = getCampaignState(updatedSnapshot, campaignId: campaign_id) else {
            return updatedSnapshot
        }

        campaignState.triggered = false
        upsertCampaignState(&updatedSnapshot, state: campaignState)
        return updatedSnapshot
    }

    private func getCampaignState(
        _ snapshot: CampaignStateSnapshot,
        campaignId: String
    ) -> CampaignStateRecord? {
        return snapshot.campaign_states.first { $0.campaign_id == campaignId }
    }

    private func upsertCampaignState(
        _ snapshot: inout CampaignStateSnapshot,
        state: CampaignStateRecord
    ) {
        if let index = snapshot.campaign_states.firstIndex(where: { $0.campaign_id == state.campaign_id }) {
            snapshot.campaign_states[index] = state
            return
        }
        snapshot.campaign_states.append(state)
    }

    private func getQueuedMessage(
        _ snapshot: CampaignStateSnapshot,
        messageId: String
    ) -> CampaignQueuedMessage? {
        return snapshot.queued_messages.first { $0.message_id == messageId }
    }

    private func upsertQueuedMessage(
        _ snapshot: inout CampaignStateSnapshot,
        queuedMessage: CampaignQueuedMessage
    ) {
        if let index = snapshot.queued_messages.firstIndex(where: { $0.message_id == queuedMessage.message_id }) {
            snapshot.queued_messages[index] = queuedMessage
            return
        }
        snapshot.queued_messages.append(queuedMessage)
    }

    private func appendTriggerHistory(
        _ snapshot: inout CampaignStateSnapshot,
        campaignId: String,
        triggeredAt: String,
        maximumEntries: Int
    ) {
        snapshot.trigger_history.append(
            CampaignTriggerHistory(campaign_id: campaignId, triggered_at: triggeredAt)
        )

        if snapshot.trigger_history.count > maximumEntries {
            snapshot.trigger_history.removeFirst(snapshot.trigger_history.count - maximumEntries)
        }
    }
}
