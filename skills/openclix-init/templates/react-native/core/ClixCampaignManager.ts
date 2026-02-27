import { Clix } from './Clix';
import type {
  Config,
  TriggerContext,
  TriggerResult,
  CampaignStateSnapshot,
  QueuedMessage,
  Event,
} from '../domain/ClixTypes';
import { validateConfig } from '../infrastructure/ConfigValidator';
import { createDefaultCampaignStateSnapshot } from '../infrastructure/CampaignStateRepository';

function createDefaultSnapshot(): CampaignStateSnapshot {
  return createDefaultCampaignStateSnapshot(new Date().toISOString());
}

function assertInitialized(): void {
  if (!Clix.isInitializedInternal()) {
    throw new Error(
      'Clix is not initialized. Call Clix.initialize() before using ClixCampaignManager.',
    );
  }
}

export class ClixCampaignManager {
  private constructor() {}

  static async replaceConfig(config: Config): Promise<TriggerResult | null> {
    assertInitialized();

    const logger = Clix.getLoggerInternal();
    const triggerService = Clix.getTriggerServiceInternal();

    if (!triggerService) {
      logger?.error('Cannot replace config: trigger service is not available.');
      return null;
    }

    const validationResult = validateConfig(config);
    if (!validationResult.valid) {
      for (const error of validationResult.errors) {
        logger?.error(`Config validation error [${error.code}]: ${error.message}`);
      }
      logger?.warn('Config replacement rejected due to validation errors.');
      return null;
    }

    for (const warning of validationResult.warnings) {
      logger?.warn(`Config validation warning [${warning.code}]: ${warning.message}`);
    }

    triggerService.replaceConfig(config);
    logger?.info(
      `Config replaced (version: ${config.config_version}, campaigns: ${Object.keys(config.campaigns).length})`,
    );

    const triggerContext: TriggerContext = {
      trigger: 'config_replaced',
      now: Clix.getClockInternal()?.now(),
    };

    try {
      return await triggerService.trigger(triggerContext);
    } catch (error) {
      logger?.error(
        'Evaluation after config replacement failed:',
        error instanceof Error ? error.message : String(error),
      );
      return null;
    }
  }

  static getConfig(): Config | null {
    assertInitialized();
    return Clix.getTriggerServiceInternal()?.getConfig() ?? null;
  }

  static async getSnapshot(): Promise<CampaignStateSnapshot> {
    assertInitialized();

    const campaignStateRepository = Clix.getCampaignStateRepositoryInternal();
    if (!campaignStateRepository) return createDefaultSnapshot();

    try {
      return await campaignStateRepository.loadSnapshot(new Date().toISOString());
    } catch (error) {
      Clix.getLoggerInternal()?.warn(
        'Failed to load campaign state snapshot:',
        error instanceof Error ? error.message : String(error),
      );
      return createDefaultSnapshot();
    }
  }

  static async getScheduledMessages(
    filter?: {
      campaign_id?: string;
      status?: string;
    },
  ): Promise<QueuedMessage[]> {
    assertInitialized();

    const messageScheduler = Clix.getMessageSchedulerInternal();
    if (!messageScheduler) return [];

    let pendingMessages: QueuedMessage[];
    try {
      pendingMessages = await messageScheduler.listPending();
    } catch (error) {
      Clix.getLoggerInternal()?.error(
        'Failed to list pending messages:',
        error instanceof Error ? error.message : String(error),
      );
      return [];
    }

    if (!filter) return pendingMessages;

    return pendingMessages.filter((queuedMessage) => {
      if (filter.campaign_id && queuedMessage.campaign_id !== filter.campaign_id) {
        return false;
      }
      if (filter.status && queuedMessage.status !== filter.status) {
        return false;
      }
      return true;
    });
  }

  static async getEventLog(limit?: number): Promise<Event[]> {
    assertInitialized();

    const campaignStateRepository = Clix.getCampaignStateRepositoryInternal();
    if (!campaignStateRepository?.loadEvents) return [];

    try {
      return await campaignStateRepository.loadEvents(limit);
    } catch (error) {
      Clix.getLoggerInternal()?.error(
        'Failed to load event log:',
        error instanceof Error ? error.message : String(error),
      );
      return [];
    }
  }
}
