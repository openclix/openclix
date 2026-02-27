import type {
  Config,
  TriggerContext,
  TriggerResult,
  CampaignStateSnapshot,
  DecisionTrace,
  QueuedMessage,
  Event,
  CampaignStateRepositoryPort,
  MessageScheduler,
  Clock,
  Logger,
  JsonValue,
} from '../domain/ClixTypes';
import {
  EventConditionProcessor,
  ScheduleCalculator,
  generateUUID,
} from '../domain/CampaignUtils';
import { CampaignProcessor } from '../domain/CampaignProcessor';
import { CampaignStateService } from '../domain/CampaignStateService';

export interface TriggerServiceDependencies {
  campaignStateRepository: CampaignStateRepositoryPort;
  messageScheduler: MessageScheduler;
  clock: Clock;
  logger: Logger;
  recordEvent?: (event: Event) => Promise<void>;
  campaignStateService?: CampaignStateService;
}

const MAXIMUM_TRIGGER_HISTORY_SIZE = 5000;

export class TriggerService {
  private config: Config | null = null;
  private triggerQueue: Promise<void> = Promise.resolve();

  private readonly eventConditionProcessor: EventConditionProcessor;
  private readonly scheduleCalculator: ScheduleCalculator;
  private readonly campaignProcessor: CampaignProcessor;
  private readonly campaignStateService: CampaignStateService;
  private readonly dependencies: TriggerServiceDependencies;

  constructor(dependencies: TriggerServiceDependencies) {
    this.dependencies = dependencies;
    this.eventConditionProcessor = new EventConditionProcessor();
    this.scheduleCalculator = new ScheduleCalculator();
    this.campaignProcessor = new CampaignProcessor();
    this.campaignStateService =
      dependencies.campaignStateService ?? new CampaignStateService();
  }

  replaceConfig(config: Config): void {
    this.config = config;
    this.dependencies.logger.info(
      `[TriggerService] Config replaced (version: ${config.config_version}, campaigns: ${Object.keys(config.campaigns).length})`,
    );
  }

  getConfig(): Config | null {
    return this.config;
  }

  trigger(triggerContext: TriggerContext): Promise<TriggerResult> {
    const executionPromise = this.triggerQueue.then(() =>
      this.evaluateTrigger(triggerContext),
    );
    this.triggerQueue = executionPromise.then(
      () => undefined,
      () => undefined,
    );
    return executionPromise;
  }

  private async evaluateTrigger(triggerContext: TriggerContext): Promise<TriggerResult> {
    const { campaignStateRepository, messageScheduler, clock, logger } = this.dependencies;

    if (!this.config) {
      logger.debug('[TriggerService] No config loaded, returning empty report');
      const now = triggerContext.now ?? clock.now();
      return {
        evaluated_at: now,
        trigger: triggerContext.trigger,
        traces: [],
        queued_messages: [],
      };
    }

    const now = triggerContext.now ?? clock.now();
    const snapshot = await campaignStateRepository.loadSnapshot(now);

    const traces: DecisionTrace[] = [];
    const queuedMessages: QueuedMessage[] = [];

    if (triggerContext.trigger !== 'event_tracked') {
      await this.reconcileQueuedMessages(snapshot, logger);
    }

    if (triggerContext.trigger === 'event_tracked' && triggerContext.event) {
      const cancellationTraces = await this.cancelQueuedMessages(
        triggerContext.event,
        snapshot,
        now,
        logger,
      );
      traces.push(...cancellationTraces);
    }

    logger.debug(
      `[TriggerService] Processing ${Object.keys(this.config.campaigns).length} campaigns`,
    );

    for (const [campaignId, campaign] of Object.entries(this.config.campaigns)) {
      try {
        const decision = this.campaignProcessor.process(
          campaignId,
          campaign,
          triggerContext,
          snapshot,
          {
            eventConditionProcessor: this.eventConditionProcessor,
            scheduleCalculator: this.scheduleCalculator,
            logger,
            settings: this.config.settings,
          },
        );

        traces.push(decision.trace);
        logger.debug(
          `[TriggerService] Campaign ${campaignId} decision: action=${decision.action}, result=${decision.trace.result}, reason=${decision.trace.reason}`,
        );

        if (decision.action !== 'trigger' || !decision.queued_message) {
          continue;
        }

        const queuedMessage = decision.queued_message;
        try {
          await messageScheduler.schedule(queuedMessage);
        } catch (scheduleError) {
          await this.emitSystemEvent(
            'clix.message.failed',
            {
              campaign_id: campaignId,
              queued_message_id: queuedMessage.id,
              channel_type: queuedMessage.channel_type,
              failure_reason:
                scheduleError instanceof Error
                  ? scheduleError.message
                  : String(scheduleError),
            },
            now,
          );
          logger.error(
            `[TriggerService] Error scheduling message for campaign ${campaignId}:`,
            scheduleError,
          );
          continue;
        }

        this.campaignStateService.applyQueuedMessage({
          snapshot,
          campaign_id: campaignId,
          trigger_type: campaign.trigger.type,
          queued_message: queuedMessage,
          now,
          scheduled_for: decision.scheduled_for,
          max_trigger_history: MAXIMUM_TRIGGER_HISTORY_SIZE,
        });
        await this.emitSystemEvent(
          'clix.message.scheduled',
          {
            campaign_id: campaignId,
            queued_message_id: queuedMessage.id,
            channel_type: queuedMessage.channel_type,
            execute_at: queuedMessage.execute_at,
          },
          now,
        );

        queuedMessages.push(queuedMessage);
      } catch (error) {
        logger.error(`[TriggerService] Error processing campaign ${campaignId}:`, error);
      }
    }

    snapshot.updated_at = now;
    try {
      await campaignStateRepository.saveSnapshot(snapshot);
    } catch (error) {
      logger.error(
        '[TriggerService] Failed to persist campaign state snapshot:',
        error instanceof Error ? error.message : String(error),
      );
    }

    const triggerResult: TriggerResult = {
      evaluated_at: now,
      trigger: triggerContext.trigger,
      traces,
      queued_messages: queuedMessages,
    };

    logger.debug(
      `[TriggerService] Trigger complete: ${traces.length} traces, ${queuedMessages.length} messages queued`,
    );

    return triggerResult;
  }

  private async reconcileQueuedMessages(
    snapshot: CampaignStateSnapshot,
    logger: Logger,
  ): Promise<void> {
    let pendingMessagesFromScheduler: QueuedMessage[] = [];
    try {
      pendingMessagesFromScheduler = await this.dependencies.messageScheduler.listPending();
    } catch (error) {
      logger.warn(
        '[TriggerService] Failed to reconcile pending scheduler records:',
        error instanceof Error ? error.message : String(error),
      );
      return;
    }

    this.campaignStateService.reconcileQueuedMessages({
      snapshot,
      scheduler_pending_messages: pendingMessagesFromScheduler,
      resolve_trigger_type: (campaignId) =>
        this.config?.campaigns[campaignId]?.trigger.type,
    });
  }

  private async cancelQueuedMessages(
    event: Event,
    snapshot: CampaignStateSnapshot,
    now: string,
    logger: Logger,
  ): Promise<DecisionTrace[]> {
    const traces: DecisionTrace[] = [];
    const pendingMessages = [...snapshot.queued_messages];
    if (!this.config || pendingMessages.length === 0) return traces;

    for (const pendingMessage of pendingMessages) {
      const campaign = this.config.campaigns[pendingMessage.campaign_id];
      if (!campaign) {
        this.campaignStateService.removeQueuedMessage(snapshot, pendingMessage.message_id);
        continue;
      }
      if (campaign.trigger.type !== 'event') continue;

      const cancelEvent = campaign.trigger.event?.cancel_event;
      if (!cancelEvent) continue;

      const isMatched = this.eventConditionProcessor.process(cancelEvent, event);
      if (!isMatched) continue;
      if (!this.isWithinCancellationWindow(event, pendingMessage, now)) continue;

      try {
        await this.dependencies.messageScheduler.cancel(pendingMessage.message_id);
        this.campaignStateService.removeQueuedMessage(snapshot, pendingMessage.message_id);
        this.campaignStateService.markCampaignUntriggered(
          snapshot,
          pendingMessage.campaign_id,
        );
        traces.push({
          campaign_id: pendingMessage.campaign_id,
          action: 'cancel_message',
          result: 'applied',
          skip_reason: 'trigger_cancel_event_matched',
          reason:
            `Cancelled queued message ${pendingMessage.message_id} for campaign ${pendingMessage.campaign_id} ` +
            `because event '${event.name}' matched cancel_event`,
        });
        await this.emitSystemEvent(
          'clix.message.cancelled',
          {
            campaign_id: pendingMessage.campaign_id,
            queued_message_id: pendingMessage.message_id,
            skip_reason: 'trigger_cancel_event_matched',
          },
          event.created_at,
        );
        logger.debug(
          `[TriggerService] Cancelled queued message ${pendingMessage.message_id} for campaign ${pendingMessage.campaign_id}`,
        );
      } catch (error) {
        await this.emitSystemEvent(
          'clix.message.failed',
          {
            campaign_id: pendingMessage.campaign_id,
            queued_message_id: pendingMessage.message_id,
            channel_type: 'app_push',
            failure_reason:
              error instanceof Error ? error.message : String(error),
          },
          event.created_at,
        );
        logger.warn(
          `[TriggerService] Failed to cancel queued message ${pendingMessage.message_id}:`,
          error instanceof Error ? error.message : String(error),
        );
      }
    }

    return traces;
  }

  private isWithinCancellationWindow(
    event: Event,
    pendingMessage: CampaignStateSnapshot['queued_messages'][number],
    now: string,
  ): boolean {
    const cancellationAtMs = this.parseTimestamp(event.created_at) ?? this.parseTimestamp(now);
    const windowStartMs = this.parseTimestamp(pendingMessage.created_at);
    const windowEndMs = this.parseTimestamp(pendingMessage.execute_at);
    if (
      cancellationAtMs === null ||
      windowStartMs === null ||
      windowEndMs === null
    ) {
      return false;
    }

    return cancellationAtMs >= windowStartMs && cancellationAtMs <= windowEndMs;
  }

  private parseTimestamp(value: string | undefined): number | null {
    if (!value) return null;
    const timestamp = new Date(value).getTime();
    return Number.isNaN(timestamp) ? null : timestamp;
  }

  private async emitSystemEvent(
    name: string,
    properties: Record<string, JsonValue | undefined>,
    created_at: string,
  ): Promise<void> {
    if (!this.dependencies.recordEvent) return;

    const normalizedProperties: Record<string, JsonValue> = {};
    for (const [key, value] of Object.entries(properties)) {
      if (value !== undefined) {
        normalizedProperties[key] = value;
      }
    }

    try {
      await this.dependencies.recordEvent({
        id: generateUUID(),
        name,
        source_type: 'system',
        properties: normalizedProperties,
        created_at,
      });
    } catch (error) {
      this.dependencies.logger.warn(
        `[TriggerService] Failed to persist system event '${name}':`,
        error instanceof Error ? error.message : String(error),
      );
    }
  }
}
