import type {
  ClixConfig,
  Config,
  Event,
  ClixLogLevel,
  TriggerContext,
  TriggerResult,
  MessageScheduler,
  CampaignStateRepositoryPort,
  Clock,
  LifecycleStateReader,
  Logger,
  JsonValue,
} from '../domain/ClixTypes';
import { TriggerService } from '../engine/TriggerService';
import type { TriggerServiceDependencies } from '../engine/TriggerService';
import { loadConfig } from '../infrastructure/ConfigLoader';
import { validateConfig } from '../infrastructure/ConfigValidator';
import { generateUUID } from '../domain/CampaignUtils';
import { ReactNativeLifecycleStateReader } from '../infrastructure/ReactNativeLifecycleStateReader';

export interface ClixDependencies {
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

const LOG_LEVEL_ORDER: Record<ClixLogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
  none: 4,
};

export class ReactNativeLogger implements Logger {
  private logLevel: ClixLogLevel;

  constructor(initialLogLevel: ClixLogLevel = 'warn') {
    this.logLevel = initialLogLevel;
  }

  setLogLevel(level: ClixLogLevel): void {
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

  private shouldLog(targetLevel: ClixLogLevel): boolean {
    return LOG_LEVEL_ORDER[targetLevel] >= LOG_LEVEL_ORDER[this.logLevel];
  }
}

export class Clix {
  private static config: ClixConfig | null = null;
  private static triggerService: TriggerService | null = null;
  private static initialized = false;
  private static campaignStateRepository: CampaignStateRepositoryPort | null = null;
  private static messageScheduler: MessageScheduler | null = null;
  private static clock: Clock | null = null;
  private static lifecycleStateReader: LifecycleStateReader | null = null;
  private static logger: Logger | null = null;
  private static dependencies: ClixDependencies | null = null;

  private constructor() {}

  static async initialize(
    config: ClixConfig,
    dependencies: ClixDependencies,
  ): Promise<void> {
    if (Clix.initialized) {
      throw new Error(
        'Clix is already initialized. Call Clix.reset() before re-initializing.',
      );
    }

    Clix.config = config;
    Clix.dependencies = dependencies;
    Clix.clock = dependencies.clock ?? new ReactNativeClock();
    Clix.lifecycleStateReader =
      dependencies.lifecycleStateReader ??
      (typeof globalThis === 'object' && 'navigator' in globalThis
        ? new ReactNativeLifecycleStateReader()
        : new BasicLifecycleStateReader());
    Clix.logger = dependencies.logger ?? new ReactNativeLogger(config.logLevel ?? 'warn');
    Clix.logger.setLogLevel?.(config.logLevel ?? 'warn');
    Clix.campaignStateRepository = dependencies.campaignStateRepository;
    Clix.messageScheduler = dependencies.messageScheduler;
    Clix.triggerService = new TriggerService(Clix.createTriggerServiceDependencies());

    const logger = Clix.logger;
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

          Clix.triggerService.replaceConfig(loadedConfig);
          try {
            await Clix.evaluate('app_boot');
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
            'Use ClixCampaignManager.replaceConfig() to set config manually.',
          loadError instanceof Error ? loadError.message : String(loadError),
        );
      }
    } else {
      logger?.info(
        'Non-HTTP endpoint provided. Use ClixCampaignManager.replaceConfig() to set campaign config.',
      );
    }

    Clix.initialized = true;
    logger?.info('OpenClix SDK initialized successfully.');
  }

  static async trackEvent(
    name: string,
    properties?: Record<string, JsonValue>,
  ): Promise<void> {
    Clix.assertInitialized();

    const event: Event = {
      id: generateUUID(),
      name,
      source_type: 'app',
      properties,
      created_at: Clix.clock!.now(),
    };

    Clix.logger?.debug(`Event tracked (not persisted): ${name}`);

    try {
      await Clix.evaluate('event_tracked', event);
    } catch (evaluationError) {
      Clix.logger?.warn(
        `Evaluation after event '${name}' failed:`,
        evaluationError instanceof Error
          ? evaluationError.message
          : String(evaluationError),
      );
    }
  }

  static async reset(): Promise<void> {
    const logger = Clix.logger;

    if (Clix.campaignStateRepository) {
      try {
        await Clix.campaignStateRepository.clearCampaignState();
      } catch (error) {
        logger?.warn(
          'Failed to clear campaign state during reset:',
          error instanceof Error ? error.message : String(error),
        );
      }
    }

    if (Clix.messageScheduler) {
      try {
        const pendingMessages = await Clix.messageScheduler.listPending();
        await Promise.all(
          pendingMessages.map((message) => Clix.messageScheduler!.cancel(message.id)),
        );
      } catch (error) {
        logger?.warn(
          'Failed to clear scheduled messages during reset:',
          error instanceof Error ? error.message : String(error),
        );
      }
    }

    try {
      Clix.lifecycleStateReader?.dispose?.();
    } catch (error) {
      logger?.warn(
        'Failed to dispose lifecycle state reader during reset:',
        error instanceof Error ? error.message : String(error),
      );
    }

    Clix.config = null;
    Clix.triggerService = null;
    Clix.initialized = false;
    Clix.campaignStateRepository = null;
    Clix.messageScheduler = null;
    Clix.clock = null;
    Clix.lifecycleStateReader = null;
    Clix.logger = null;
    Clix.dependencies = null;

    logger?.info('OpenClix SDK reset complete.');
  }

  static setLogLevel(level: ClixLogLevel): void {
    Clix.logger?.setLogLevel?.(level);
  }

  static handleAppForeground(): void {
    if (!Clix.initialized) return;

    Clix.lifecycleStateReader?.setAppState?.('foreground');
    Clix.logger?.debug('App entered foreground');

    Clix.evaluate('app_foreground').catch((error) => {
      Clix.logger?.warn(
        'app_foreground evaluation failed:',
        error instanceof Error ? error.message : String(error),
      );
    });
  }

  static getTriggerServiceInternal(): TriggerService | null {
    return Clix.triggerService;
  }

  static getClockInternal(): Clock | null {
    return Clix.clock;
  }

  static getLoggerInternal(): Logger | null {
    return Clix.logger;
  }

  static getCampaignStateRepositoryInternal(): CampaignStateRepositoryPort | null {
    return Clix.campaignStateRepository;
  }

  static getMessageSchedulerInternal(): MessageScheduler | null {
    return Clix.messageScheduler;
  }

  static isInitializedInternal(): boolean {
    return Clix.initialized;
  }

  private static assertInitialized(): void {
    if (!Clix.initialized) {
      throw new Error(
        'Clix is not initialized. Call Clix.initialize() before using the SDK.',
      );
    }
  }

  private static createTriggerServiceDependencies(): TriggerServiceDependencies {
    return {
      campaignStateRepository: Clix.campaignStateRepository!,
      messageScheduler: Clix.messageScheduler!,
      clock: Clix.clock!,
      logger: Clix.logger!,
    };
  }

  private static async evaluate(
    trigger: TriggerContext['trigger'],
    event?: Event,
  ): Promise<TriggerResult | null> {
    if (!Clix.triggerService) return null;

    return Clix.triggerService.trigger({
      trigger,
      event,
      now: Clix.clock?.now(),
    });
  }
}
