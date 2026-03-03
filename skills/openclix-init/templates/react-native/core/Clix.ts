import type {
  OpenClixConfig,
  Config,
  Event,
  OpenClixLogLevel,
  TriggerContext,
  TriggerResult,
  MessageScheduler,
  CampaignStateRepositoryPort,
  Clock,
  LifecycleStateReader,
  Logger,
  JsonValue,
  SystemEventName,
} from '../domain/OpenClixTypes';
import { TriggerService } from '../engine/TriggerService';
import type { TriggerServiceDependencies } from '../engine/TriggerService';
import { loadConfig } from '../infrastructure/ConfigLoader';
import { validateConfig } from '../infrastructure/ConfigValidator';
import { generateUUID } from '../domain/CampaignUtils';
import { ReactNativeLifecycleStateReader } from '../infrastructure/ReactNativeLifecycleStateReader';

export interface OpenClixDependencies {
  messageScheduler: MessageScheduler;
  campaignStateRepository: CampaignStateRepositoryPort;
  clock?: Clock;
  lifecycleStateReader?: LifecycleStateReader;
  logger?: Logger;
}

function isRemoteEndpoint(endpoint: string): boolean {
  return endpoint.startsWith('http://') || endpoint.startsWith('https://');
}

export class ReactNativeClock implements Clock {
  now(): string {
    return new Date().toISOString();
  }
}

class BasicLifecycleStateReader implements LifecycleStateReader {
  private currentAppState: 'foreground' | 'background' = 'foreground';

  getAppState(): 'foreground' | 'background' {
    return this.currentAppState;
  }

  setAppState(state: 'foreground' | 'background'): void {
    this.currentAppState = state;
  }
}

const LOG_LEVEL_ORDER: Record<OpenClixLogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
  none: 4,
};

const MAXIMUM_EVENT_LOG_SIZE = 5000;

export class ReactNativeLogger implements Logger {
  private logLevel: OpenClixLogLevel;

  constructor(initialLogLevel: OpenClixLogLevel = 'warn') {
    this.logLevel = initialLogLevel;
  }

  setLogLevel(level: OpenClixLogLevel): void {
    this.logLevel = level;
  }

  debug(message: string, ...args: unknown[]): void {
    if (this.shouldLog('debug')) console.debug(`[OpenClix] ${message}`, ...args);
  }

  info(message: string, ...args: unknown[]): void {
    if (this.shouldLog('info')) console.info(`[OpenClix] ${message}`, ...args);
  }

  warn(message: string, ...args: unknown[]): void {
    if (this.shouldLog('warn')) console.warn(`[OpenClix] ${message}`, ...args);
  }

  error(message: string, ...args: unknown[]): void {
    if (this.shouldLog('error')) console.error(`[OpenClix] ${message}`, ...args);
  }

  private shouldLog(targetLevel: OpenClixLogLevel): boolean {
    return LOG_LEVEL_ORDER[targetLevel] >= LOG_LEVEL_ORDER[this.logLevel];
  }
}

export class OpenClix {
  private static config: OpenClixConfig | null = null;
  private static triggerService: TriggerService | null = null;
  private static initialized = false;
  private static campaignStateRepository: CampaignStateRepositoryPort | null = null;
  private static messageScheduler: MessageScheduler | null = null;
  private static clock: Clock | null = null;
  private static lifecycleStateReader: LifecycleStateReader | null = null;
  private static logger: Logger | null = null;
  private static dependencies: OpenClixDependencies | null = null;

  private constructor() {}

  static async initialize(
    config: OpenClixConfig,
    dependencies: OpenClixDependencies,
  ): Promise<void> {
    if (OpenClix.initialized) {
      throw new Error(
        'OpenClix is already initialized. Call OpenClix.reset() before re-initializing.',
      );
    }

    OpenClix.config = config;
    OpenClix.dependencies = dependencies;
    OpenClix.clock = dependencies.clock ?? new ReactNativeClock();
    OpenClix.lifecycleStateReader =
      dependencies.lifecycleStateReader ??
      (typeof globalThis === 'object' && 'navigator' in globalThis
        ? new ReactNativeLifecycleStateReader()
        : new BasicLifecycleStateReader());
    OpenClix.logger = dependencies.logger ?? new ReactNativeLogger(config.logLevel ?? 'warn');
    OpenClix.logger.setLogLevel?.(config.logLevel ?? 'warn');
    OpenClix.campaignStateRepository = dependencies.campaignStateRepository;
    OpenClix.messageScheduler = dependencies.messageScheduler;
    OpenClix.triggerService = new TriggerService(OpenClix.createTriggerServiceDependencies());

    const logger = OpenClix.logger;
    logger?.info('Initializing OpenClix SDK...');

    if (isRemoteEndpoint(config.endpoint)) {
      try {
        const requestHeaders: Record<string, string> = {
          ...(config.extraHeaders ?? {}),
        };
        if (config.projectId) {
          requestHeaders['x-openclix-project-id'] = config.projectId;
        }
        if (config.apiKey) {
          requestHeaders['x-openclix-api-key'] = config.apiKey;
        }

        const loadedConfig = await loadConfig(config.endpoint, {
          headers: requestHeaders,
          timeoutMs: config.sessionTimeoutMs,
        });
        const validationResult = validateConfig(loadedConfig);

        if (validationResult.valid) {
          for (const warning of validationResult.warnings) {
            logger?.warn(`Config validation warning [${warning.code}]: ${warning.message}`);
          }

          OpenClix.triggerService.replaceConfig(loadedConfig);
          try {
            await OpenClix.evaluate('app_boot');
          } catch (evaluationError) {
            logger?.warn(
              'Initial app_boot evaluation failed:',
              evaluationError instanceof Error
                ? evaluationError.message
                : String(evaluationError),
            );
          }

          logger?.info(
            `Config loaded successfully (version: ${loadedConfig.config_version}, campaigns: ${Object.keys(loadedConfig.campaigns).length})`,
          );
        } else {
          for (const error of validationResult.errors) {
            logger?.error(`Config validation error [${error.code}]: ${error.message}`);
          }
          logger?.warn('Config validation failed. SDK initialized without campaign config.');
        }
      } catch (loadError) {
        logger?.warn(
          'Failed to load config from endpoint. SDK initialized without campaign config. ' +
            'Use OpenClixCampaignManager.replaceConfig() to set config manually.',
          loadError instanceof Error ? loadError.message : String(loadError),
        );
      }
    } else {
      logger?.info(
        'Non-HTTP endpoint provided. Use OpenClixCampaignManager.replaceConfig() to set campaign config.',
      );
    }

    OpenClix.initialized = true;
    logger?.info('OpenClix SDK initialized successfully.');
  }

  static async trackEvent(
    name: string,
    properties?: Record<string, JsonValue>,
  ): Promise<void> {
    OpenClix.assertInitialized();

    const event: Event = {
      id: generateUUID(),
      name,
      source_type: 'app',
      properties,
      created_at: OpenClix.clock!.now(),
    };

    await OpenClix.persistEvent(event);
    OpenClix.logger?.debug(`Event tracked: ${name}`);

    try {
      await OpenClix.evaluate('event_tracked', event);
    } catch (evaluationError) {
      OpenClix.logger?.warn(
        `Evaluation after event '${name}' failed:`,
        evaluationError instanceof Error
          ? evaluationError.message
          : String(evaluationError),
      );
    }
  }

  static async trackSystemEvent(
    name: SystemEventName,
    properties?: Record<string, JsonValue>,
  ): Promise<void> {
    OpenClix.assertInitialized();

    const event: Event = {
      id: generateUUID(),
      name,
      source_type: 'system',
      properties,
      created_at: OpenClix.clock!.now(),
    };

    await OpenClix.persistEvent(event);
  }

  static async handleNotificationDelivered(
    payload: Record<string, unknown>,
  ): Promise<void> {
    OpenClix.assertInitialized();

    await OpenClix.trackSystemEvent(
      'openclix.message.delivered',
      OpenClix.compactProperties({
        campaign_id: OpenClix.extractString(payload, 'campaignId', 'campaign_id'),
        queued_message_id: OpenClix.extractString(
          payload,
          'queuedMessageId',
          'queued_message_id',
        ),
        channel_type:
          OpenClix.extractString(payload, 'channelType', 'channel_type') ?? 'app_push',
      }),
    );
  }

  static async handleNotificationOpened(
    payload: Record<string, unknown>,
  ): Promise<string | undefined> {
    OpenClix.assertInitialized();

    const landingUrl = OpenClix.extractString(payload, 'landingUrl', 'landing_url');
    await OpenClix.trackSystemEvent(
      'openclix.message.opened',
      OpenClix.compactProperties({
        campaign_id: OpenClix.extractString(payload, 'campaignId', 'campaign_id'),
        queued_message_id: OpenClix.extractString(
          payload,
          'queuedMessageId',
          'queued_message_id',
        ),
        channel_type:
          OpenClix.extractString(payload, 'channelType', 'channel_type') ?? 'app_push',
        landing_url: landingUrl,
      }),
    );

    return landingUrl;
  }

  static async reset(): Promise<void> {
    const logger = OpenClix.logger;

    if (OpenClix.campaignStateRepository) {
      try {
        await OpenClix.campaignStateRepository.clearCampaignState();
      } catch (error) {
        logger?.warn(
          'Failed to clear campaign state during reset:',
          error instanceof Error ? error.message : String(error),
        );
      }

      if (OpenClix.campaignStateRepository.clearEvents) {
        try {
          await OpenClix.campaignStateRepository.clearEvents();
        } catch (error) {
          logger?.warn(
            'Failed to clear event log during reset:',
            error instanceof Error ? error.message : String(error),
          );
        }
      }
    }

    if (OpenClix.messageScheduler) {
      try {
        const pendingMessages = await OpenClix.messageScheduler.listPending();
        await Promise.all(
          pendingMessages.map((message) => OpenClix.messageScheduler!.cancel(message.id)),
        );
      } catch (error) {
        logger?.warn(
          'Failed to clear scheduled messages during reset:',
          error instanceof Error ? error.message : String(error),
        );
      }
    }

    try {
      OpenClix.lifecycleStateReader?.dispose?.();
    } catch (error) {
      logger?.warn(
        'Failed to dispose lifecycle state reader during reset:',
        error instanceof Error ? error.message : String(error),
      );
    }

    OpenClix.config = null;
    OpenClix.triggerService = null;
    OpenClix.initialized = false;
    OpenClix.campaignStateRepository = null;
    OpenClix.messageScheduler = null;
    OpenClix.clock = null;
    OpenClix.lifecycleStateReader = null;
    OpenClix.logger = null;
    OpenClix.dependencies = null;

    logger?.info('OpenClix SDK reset complete.');
  }

  static setLogLevel(level: OpenClixLogLevel): void {
    OpenClix.logger?.setLogLevel?.(level);
  }

  static handleAppForeground(): void {
    if (!OpenClix.initialized) return;

    OpenClix.lifecycleStateReader?.setAppState?.('foreground');
    OpenClix.logger?.debug('App entered foreground');

    OpenClix.evaluate('app_foreground').catch((error) => {
      OpenClix.logger?.warn(
        'app_foreground evaluation failed:',
        error instanceof Error ? error.message : String(error),
      );
    });
  }

  static getTriggerServiceInternal(): TriggerService | null {
    return OpenClix.triggerService;
  }

  static getClockInternal(): Clock | null {
    return OpenClix.clock;
  }

  static getLoggerInternal(): Logger | null {
    return OpenClix.logger;
  }

  static getCampaignStateRepositoryInternal(): CampaignStateRepositoryPort | null {
    return OpenClix.campaignStateRepository;
  }

  static getMessageSchedulerInternal(): MessageScheduler | null {
    return OpenClix.messageScheduler;
  }

  static isInitializedInternal(): boolean {
    return OpenClix.initialized;
  }

  private static assertInitialized(): void {
    if (!OpenClix.initialized) {
      throw new Error(
        'OpenClix is not initialized. Call OpenClix.initialize() before using the SDK.',
      );
    }
  }

  private static createTriggerServiceDependencies(): TriggerServiceDependencies {
    return {
      campaignStateRepository: OpenClix.campaignStateRepository!,
      messageScheduler: OpenClix.messageScheduler!,
      clock: OpenClix.clock!,
      logger: OpenClix.logger!,
      recordEvent: async (event: Event) => {
        await OpenClix.persistEvent(event);
      },
    };
  }

  private static async persistEvent(event: Event): Promise<void> {
    if (!OpenClix.campaignStateRepository?.appendEvents) {
      OpenClix.logger?.debug(
        `Event store is not available; skipping persistence for event '${event.name}'.`,
      );
      return;
    }

    try {
      await OpenClix.campaignStateRepository.appendEvents([event], MAXIMUM_EVENT_LOG_SIZE);
    } catch (error) {
      OpenClix.logger?.warn(
        `Failed to persist event '${event.name}':`,
        error instanceof Error ? error.message : String(error),
      );
    }
  }

  private static extractString(
    source: Record<string, unknown>,
    ...keys: string[]
  ): string | undefined {
    for (const key of keys) {
      const value = source[key];
      if (typeof value === 'string' && value.length > 0) {
        return value;
      }
    }
    return undefined;
  }

  private static compactProperties(
    values: Record<string, JsonValue | undefined>,
  ): Record<string, JsonValue> {
    const compacted: Record<string, JsonValue> = {};
    for (const [key, value] of Object.entries(values)) {
      if (value !== undefined) {
        compacted[key] = value;
      }
    }
    return compacted;
  }

  private static async evaluate(
    trigger: TriggerContext['trigger'],
    event?: Event,
  ): Promise<TriggerResult | null> {
    if (!OpenClix.triggerService) return null;

    return OpenClix.triggerService.trigger({
      trigger,
      event,
      now: OpenClix.clock?.now(),
    });
  }
}
