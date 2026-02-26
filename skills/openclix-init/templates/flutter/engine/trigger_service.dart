import '../models/clix_types.dart';
import 'campaign_processor.dart';
import 'campaign_state_service.dart';
import 'event_condition_processor.dart';
import 'schedule_calculator.dart';

class TriggerServiceDependencies {
  final CampaignStateRepositoryPort campaignStateRepository;
  final ClixLocalMessageScheduler messageScheduler;
  final ClixClock clock;
  final ClixLogger logger;
  final CampaignStateService? campaignStateService;

  TriggerServiceDependencies({
    required this.campaignStateRepository,
    required this.messageScheduler,
    required this.clock,
    required this.logger,
    this.campaignStateService,
  });
}

const int maximumTriggerHistorySize = 5000;

class TriggerService {
  Config? config;
  Future<void> triggerQueue = Future.value();

  final EventConditionProcessor eventConditionProcessor;
  final ScheduleCalculator scheduleCalculator;
  final CampaignProcessor campaignProcessor;
  final CampaignStateService campaignStateService;
  final TriggerServiceDependencies dependencies;

  TriggerService(this.dependencies)
    : eventConditionProcessor = EventConditionProcessor(),
      scheduleCalculator = ScheduleCalculator(),
      campaignProcessor = CampaignProcessor(),
      campaignStateService =
          dependencies.campaignStateService ?? CampaignStateService();

  void replaceConfig(Config config) {
    this.config = config;
    dependencies.logger.info(
      '[TriggerService] Config replaced '
      '(version: ${config.configVersion}, campaigns: ${config.campaigns.length})',
    );
  }

  Config? getConfig() => config;

  Future<TriggerResult> trigger(TriggerContext triggerContext) {
    final executionPromise = triggerQueue.then(
      (_) => evaluateTrigger(triggerContext),
    );

    triggerQueue = executionPromise.then((_) {}, onError: (_, __) {});

    return executionPromise;
  }

  Future<TriggerResult> evaluateTrigger(TriggerContext triggerContext) async {
    final campaignStateRepository = dependencies.campaignStateRepository;
    final messageScheduler = dependencies.messageScheduler;
    final clock = dependencies.clock;
    final logger = dependencies.logger;

    if (config == null) {
      logger.debug('[TriggerService] No config loaded, returning empty report');
      final now = triggerContext.now ?? clock.now();
      return TriggerResult(
        evaluatedAt: now,
        trigger: triggerContext.trigger,
        traces: const [],
        queuedMessages: const [],
      );
    }

    final now = triggerContext.now ?? clock.now();
    final snapshot = await campaignStateRepository.loadSnapshot(now);

    final traces = <DecisionTrace>[];
    final queuedMessages = <QueuedMessage>[];

    if (triggerContext.trigger != 'event_tracked') {
      await reconcileQueuedMessages(snapshot, logger);
    }

    if (triggerContext.trigger == 'event_tracked' &&
        triggerContext.event != null) {
      final cancellationTraces = await cancelQueuedMessages(
        triggerContext.event!,
        snapshot,
        logger,
      );
      traces.addAll(cancellationTraces);
    }

    logger.debug(
      '[TriggerService] Processing ${config!.campaigns.length} campaigns',
    );

    for (final campaignEntry in config!.campaigns.entries) {
      final campaignId = campaignEntry.key;
      final campaign = campaignEntry.value;

      try {
        final decision = campaignProcessor.process(
          campaignId,
          campaign,
          triggerContext,
          snapshot,
          CampaignProcessorDependencies(
            eventConditionProcessor: eventConditionProcessor,
            scheduleCalculator: scheduleCalculator,
            logger: logger,
            settings: config!.settings,
          ),
        );

        traces.add(decision.trace);
        logger.debug(
          '[TriggerService] Campaign $campaignId decision: '
          'action=${decision.action}, result=${decision.trace.result}, reason=${decision.trace.reason}',
        );

        if (decision.action != 'trigger' || decision.queuedMessage == null) {
          continue;
        }

        final queuedMessage = decision.queuedMessage!;
        try {
          await messageScheduler.schedule(queuedMessage);
        } catch (scheduleError) {
          logger.error(
            '[TriggerService] Error scheduling message for campaign $campaignId:',
            scheduleError,
          );
          continue;
        }

        campaignStateService.applyQueuedMessage(
          ApplyQueuedMessageParams(
            snapshot: snapshot,
            campaignId: campaignId,
            triggerType: campaign.trigger.type,
            queuedMessage: queuedMessage,
            now: now,
            scheduledFor: decision.scheduledFor,
            maxTriggerHistory: maximumTriggerHistorySize,
          ),
        );

        queuedMessages.add(queuedMessage);
      } catch (error) {
        logger.error(
          '[TriggerService] Error processing campaign $campaignId:',
          error,
        );
      }
    }

    snapshot.updatedAt = now;
    try {
      await campaignStateRepository.saveSnapshot(snapshot);
    } catch (error) {
      logger.error(
        '[TriggerService] Failed to persist campaign state snapshot:',
        error,
      );
    }

    final triggerResult = TriggerResult(
      evaluatedAt: now,
      trigger: triggerContext.trigger,
      traces: traces,
      queuedMessages: queuedMessages,
    );

    logger.debug(
      '[TriggerService] Trigger complete: ${traces.length} traces, '
      '${queuedMessages.length} messages queued',
    );

    return triggerResult;
  }

  Future<void> reconcileQueuedMessages(
    CampaignStateSnapshot snapshot,
    ClixLogger logger,
  ) async {
    List<QueuedMessage> pendingMessagesFromScheduler = const [];

    try {
      pendingMessagesFromScheduler = await dependencies.messageScheduler
          .listPending();
    } catch (error) {
      logger.warn(
        '[TriggerService] Failed to reconcile pending scheduler records:',
        error,
      );
      return;
    }

    campaignStateService.reconcileQueuedMessages(
      ReconcileQueuedMessagesParams(
        snapshot: snapshot,
        schedulerPendingMessages: pendingMessagesFromScheduler,
        resolveTriggerType: (campaignId) =>
            config?.campaigns[campaignId]?.trigger.type,
      ),
    );
  }

  Future<List<DecisionTrace>> cancelQueuedMessages(
    Event event,
    CampaignStateSnapshot snapshot,
    ClixLogger logger,
  ) async {
    final traces = <DecisionTrace>[];
    final pendingMessages = List<CampaignQueuedMessage>.from(
      snapshot.queuedMessages,
    );

    if (config == null || pendingMessages.isEmpty) {
      return traces;
    }

    for (final pendingMessage in pendingMessages) {
      final campaign = config!.campaigns[pendingMessage.campaignId];

      if (campaign == null) {
        campaignStateService.removeQueuedMessage(
          snapshot,
          pendingMessage.messageId,
        );
        continue;
      }

      if (campaign.trigger.type != TriggerType.event) {
        continue;
      }

      final cancelEventConditionGroup = campaign.trigger.event?.cancelEvent;
      if (cancelEventConditionGroup == null) {
        continue;
      }

      final matched = eventConditionProcessor.process(
        cancelEventConditionGroup,
        event,
      );
      if (!matched) {
        continue;
      }

      try {
        await dependencies.messageScheduler.cancel(pendingMessage.messageId);
        campaignStateService.removeQueuedMessage(
          snapshot,
          pendingMessage.messageId,
        );
        campaignStateService.markCampaignUntriggered(
          snapshot,
          pendingMessage.campaignId,
        );

        traces.add(
          DecisionTrace(
            campaignId: pendingMessage.campaignId,
            action: 'cancel_message',
            result: 'applied',
            skipReason: SkipReason.triggerCancelEventMatched,
            reason:
                'Cancelled queued message ${pendingMessage.messageId} '
                'for campaign ${pendingMessage.campaignId} '
                "because event '${event.name}' matched cancel_event",
          ),
        );

        logger.debug(
          '[TriggerService] Cancelled queued message ${pendingMessage.messageId} '
          'for campaign ${pendingMessage.campaignId}',
        );
      } catch (error) {
        logger.warn(
          '[TriggerService] Failed to cancel queued message '
          '${pendingMessage.messageId}:',
          error,
        );
      }
    }

    return traces;
  }
}
