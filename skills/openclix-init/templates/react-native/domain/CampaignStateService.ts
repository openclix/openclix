import type {
  CampaignStateSnapshot,
  CampaignStateRecord,
  CampaignQueuedMessage,
  TriggerType,
  QueuedMessage,
} from './ClixTypes';

export interface ApplyQueuedMessageParams {
  snapshot: CampaignStateSnapshot;
  campaign_id: string;
  trigger_type: TriggerType;
  queued_message: QueuedMessage;
  now: string;
  scheduled_for?: string;
  max_trigger_history: number;
}

export interface ReconcileQueuedMessagesParams {
  snapshot: CampaignStateSnapshot;
  scheduler_pending_messages: QueuedMessage[];
  resolve_trigger_type: (campaign_id: string) => TriggerType | undefined;
}

export class CampaignStateService {
  applyQueuedMessage(params: ApplyQueuedMessageParams): void {
    const {
      snapshot,
      campaign_id,
      trigger_type,
      queued_message,
      now,
      scheduled_for,
      max_trigger_history,
    } = params;

    const campaignState = this.getCampaignState(snapshot, campaign_id) ?? {
      campaign_id,
      triggered: false,
      delivery_count: 0,
    };

    if (trigger_type !== 'recurring') {
      campaignState.triggered = true;
    } else {
      campaignState.triggered = false;
      campaignState.recurring_anchor_at =
        campaignState.recurring_anchor_at ?? (scheduled_for ?? queued_message.execute_at);
      campaignState.recurring_last_scheduled_at = scheduled_for ?? queued_message.execute_at;
    }

    campaignState.delivery_count += 1;
    campaignState.last_triggered_at = now;
    this.upsertCampaignState(snapshot, campaignState);

    this.appendTriggerHistory(snapshot, campaign_id, now, max_trigger_history);

    this.upsertQueuedMessage(snapshot, {
      message_id: queued_message.id,
      campaign_id: queued_message.campaign_id,
      execute_at: queued_message.execute_at,
      trigger_type,
      trigger_event_id: queued_message.trigger_event_id,
      created_at: queued_message.created_at,
    });
  }

  reconcileQueuedMessages(params: ReconcileQueuedMessagesParams): void {
    const { snapshot, scheduler_pending_messages, resolve_trigger_type } = params;

    const liveIds = new Set<string>();
    for (const pending of scheduler_pending_messages) {
      liveIds.add(pending.id);

      const existing = this.getQueuedMessage(snapshot, pending.id);
      const inferredTriggerType = resolve_trigger_type(pending.campaign_id) ?? 'event';

      this.upsertQueuedMessage(snapshot, {
        message_id: pending.id,
        campaign_id: pending.campaign_id,
        execute_at: pending.execute_at,
        trigger_type: existing?.trigger_type ?? inferredTriggerType,
        trigger_event_id: existing?.trigger_event_id ?? pending.trigger_event_id,
        created_at:
          existing?.created_at && existing.created_at.length > 0
            ? existing.created_at
            : pending.created_at,
      });
    }

    snapshot.queued_messages = snapshot.queued_messages.filter((queued) =>
      liveIds.has(queued.message_id),
    );
  }

  removeQueuedMessage(snapshot: CampaignStateSnapshot, message_id: string): void {
    const index = snapshot.queued_messages.findIndex((queued) => queued.message_id === message_id);
    if (index >= 0) {
      snapshot.queued_messages.splice(index, 1);
    }
  }

  markCampaignUntriggered(snapshot: CampaignStateSnapshot, campaign_id: string): void {
    const campaignState = this.getCampaignState(snapshot, campaign_id);
    if (!campaignState) return;
    campaignState.triggered = false;
    this.upsertCampaignState(snapshot, campaignState);
  }

  private getCampaignState(
    snapshot: CampaignStateSnapshot,
    campaign_id: string,
  ): CampaignStateRecord | undefined {
    return snapshot.campaign_states.find((state) => state.campaign_id === campaign_id);
  }

  private upsertCampaignState(
    snapshot: CampaignStateSnapshot,
    state: CampaignStateRecord,
  ): void {
    const index = snapshot.campaign_states.findIndex(
      (row) => row.campaign_id === state.campaign_id,
    );
    if (index >= 0) {
      snapshot.campaign_states[index] = state;
      return;
    }
    snapshot.campaign_states.push(state);
  }

  private getQueuedMessage(
    snapshot: CampaignStateSnapshot,
    message_id: string,
  ): CampaignQueuedMessage | undefined {
    return snapshot.queued_messages.find((queued) => queued.message_id === message_id);
  }

  private upsertQueuedMessage(
    snapshot: CampaignStateSnapshot,
    queued_message: CampaignQueuedMessage,
  ): void {
    const index = snapshot.queued_messages.findIndex(
      (row) => row.message_id === queued_message.message_id,
    );
    if (index >= 0) {
      snapshot.queued_messages[index] = queued_message;
      return;
    }
    snapshot.queued_messages.push(queued_message);
  }

  private appendTriggerHistory(
    snapshot: CampaignStateSnapshot,
    campaign_id: string,
    triggered_at: string,
    max_trigger_history: number,
  ): void {
    snapshot.trigger_history.push({ campaign_id, triggered_at });
    if (snapshot.trigger_history.length > max_trigger_history) {
      snapshot.trigger_history.splice(
        0,
        snapshot.trigger_history.length - max_trigger_history,
      );
    }
  }
}
