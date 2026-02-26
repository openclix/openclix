import '../models/clix_types.dart';

class ApplyQueuedMessageParams {
  final CampaignStateSnapshot snapshot;
  final String campaignId;
  final TriggerType triggerType;
  final QueuedMessage queuedMessage;
  final String now;
  final String? scheduledFor;
  final int maxTriggerHistory;

  ApplyQueuedMessageParams({
    required this.snapshot,
    required this.campaignId,
    required this.triggerType,
    required this.queuedMessage,
    required this.now,
    this.scheduledFor,
    required this.maxTriggerHistory,
  });
}

class ReconcileQueuedMessagesParams {
  final CampaignStateSnapshot snapshot;
  final List<QueuedMessage> schedulerPendingMessages;
  final TriggerType? Function(String campaignId) resolveTriggerType;

  ReconcileQueuedMessagesParams({
    required this.snapshot,
    required this.schedulerPendingMessages,
    required this.resolveTriggerType,
  });
}

class CampaignStateService {
  void applyQueuedMessage(ApplyQueuedMessageParams params) {
    final snapshot = params.snapshot;
    final campaignState =
        getCampaignState(snapshot, params.campaignId) ??
        CampaignStateRecord(
          campaignId: params.campaignId,
          triggered: false,
          deliveryCount: 0,
        );

    if (params.triggerType != TriggerType.recurring) {
      campaignState.triggered = true;
    } else {
      campaignState.triggered = false;
      campaignState.recurringAnchorAt =
          campaignState.recurringAnchorAt ??
          (params.scheduledFor ?? params.queuedMessage.executeAt);
      campaignState.recurringLastScheduledAt =
          params.scheduledFor ?? params.queuedMessage.executeAt;
    }

    campaignState.deliveryCount += 1;
    campaignState.lastTriggeredAt = params.now;
    upsertCampaignState(snapshot, campaignState);

    appendTriggerHistory(
      snapshot,
      params.campaignId,
      params.now,
      params.maxTriggerHistory,
    );

    upsertQueuedMessage(
      snapshot,
      CampaignQueuedMessage(
        messageId: params.queuedMessage.id,
        campaignId: params.queuedMessage.campaignId,
        executeAt: params.queuedMessage.executeAt,
        triggerType: params.triggerType,
        triggerEventId: params.queuedMessage.triggerEventId,
        createdAt: params.queuedMessage.createdAt,
      ),
    );
  }

  void reconcileQueuedMessages(ReconcileQueuedMessagesParams params) {
    final liveMessageIds = <String>{};

    for (final pendingMessage in params.schedulerPendingMessages) {
      liveMessageIds.add(pendingMessage.id);

      final existingQueued = getQueuedMessage(
        params.snapshot,
        pendingMessage.id,
      );
      final inferredTriggerType =
          params.resolveTriggerType(pendingMessage.campaignId) ??
          TriggerType.event;

      upsertQueuedMessage(
        params.snapshot,
        CampaignQueuedMessage(
          messageId: pendingMessage.id,
          campaignId: pendingMessage.campaignId,
          executeAt: pendingMessage.executeAt,
          triggerType: existingQueued?.triggerType ?? inferredTriggerType,
          triggerEventId:
              existingQueued?.triggerEventId ?? pendingMessage.triggerEventId,
          createdAt: (existingQueued?.createdAt.isNotEmpty ?? false)
              ? existingQueued!.createdAt
              : pendingMessage.createdAt,
        ),
      );
    }

    params.snapshot.queuedMessages.removeWhere(
      (queuedMessage) => !liveMessageIds.contains(queuedMessage.messageId),
    );
  }

  void removeQueuedMessage(CampaignStateSnapshot snapshot, String messageId) {
    snapshot.queuedMessages.removeWhere(
      (queued) => queued.messageId == messageId,
    );
  }

  void markCampaignUntriggered(
    CampaignStateSnapshot snapshot,
    String campaignId,
  ) {
    final campaignState = getCampaignState(snapshot, campaignId);
    if (campaignState == null) return;
    campaignState.triggered = false;
    upsertCampaignState(snapshot, campaignState);
  }

  CampaignStateRecord? getCampaignState(
    CampaignStateSnapshot snapshot,
    String campaignId,
  ) {
    for (final state in snapshot.campaignStates) {
      if (state.campaignId == campaignId) {
        return state;
      }
    }
    return null;
  }

  void upsertCampaignState(
    CampaignStateSnapshot snapshot,
    CampaignStateRecord state,
  ) {
    for (var index = 0; index < snapshot.campaignStates.length; index += 1) {
      if (snapshot.campaignStates[index].campaignId == state.campaignId) {
        snapshot.campaignStates[index] = state;
        return;
      }
    }
    snapshot.campaignStates.add(state);
  }

  CampaignQueuedMessage? getQueuedMessage(
    CampaignStateSnapshot snapshot,
    String messageId,
  ) {
    for (final queuedMessage in snapshot.queuedMessages) {
      if (queuedMessage.messageId == messageId) {
        return queuedMessage;
      }
    }
    return null;
  }

  void upsertQueuedMessage(
    CampaignStateSnapshot snapshot,
    CampaignQueuedMessage queuedMessage,
  ) {
    for (var index = 0; index < snapshot.queuedMessages.length; index += 1) {
      if (snapshot.queuedMessages[index].messageId == queuedMessage.messageId) {
        snapshot.queuedMessages[index] = queuedMessage;
        return;
      }
    }
    snapshot.queuedMessages.add(queuedMessage);
  }

  void appendTriggerHistory(
    CampaignStateSnapshot snapshot,
    String campaignId,
    String triggeredAt,
    int maxTriggerHistory,
  ) {
    snapshot.triggerHistory.add(
      CampaignTriggerHistory(campaignId: campaignId, triggeredAt: triggeredAt),
    );

    if (snapshot.triggerHistory.length > maxTriggerHistory) {
      final extraCount = snapshot.triggerHistory.length - maxTriggerHistory;
      snapshot.triggerHistory.removeRange(0, extraCount);
    }
  }
}
