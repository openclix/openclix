import '../engine/trigger_service.dart';
import '../models/clix_types.dart';
import '../services/config_loader.dart';
import '../services/config_validator.dart';
import '../services/utils.dart';

class ClixDependencies {
  final ClixLocalMessageScheduler messageScheduler;
  final CampaignStateRepositoryPort campaignStateRepository;
  final ClixClock? clock;
  final ClixLifecycleStateReader? lifecycleStateReader;
  final ClixLogger? logger;

  const ClixDependencies({
    required this.messageScheduler,
    required this.campaignStateRepository,
    this.clock,
    this.lifecycleStateReader,
    this.logger,
  });
}

class DefaultClock implements ClixClock {
  @override
  String now() => DateTime.now().toUtc().toIso8601String();
}

class DefaultLifecycleStateReader implements ClixLifecycleStateReader {
  String currentAppState = 'foreground';

  @override
  String getAppState() => currentAppState;

  @override
  void setAppState(String state) {
    currentAppState = state;
  }

  @override
  void dispose() {}
}

class DefaultLogger implements ClixLogger {
  ClixLogLevel logLevel;

  static const Map<ClixLogLevel, int> logLevelOrder = {
    ClixLogLevel.debug: 0,
    ClixLogLevel.info: 1,
    ClixLogLevel.warn: 2,
    ClixLogLevel.error: 3,
    ClixLogLevel.none: 4,
  };

  DefaultLogger(this.logLevel);

  @override
  void setLogLevel(ClixLogLevel level) {
    logLevel = level;
  }

  @override
  void debug(String message, [Object? argument]) {
    if (shouldLog(ClixLogLevel.debug)) {
      print(
        '[OpenClix] DEBUG: $message${argument != null ? ' $argument' : ''}',
      );
    }
  }

  @override
  void info(String message, [Object? argument]) {
    if (shouldLog(ClixLogLevel.info)) {
      print('[OpenClix] INFO: $message${argument != null ? ' $argument' : ''}');
    }
  }

  @override
  void warn(String message, [Object? argument]) {
    if (shouldLog(ClixLogLevel.warn)) {
      print('[OpenClix] WARN: $message${argument != null ? ' $argument' : ''}');
    }
  }

  @override
  void error(String message, [Object? argument]) {
    if (shouldLog(ClixLogLevel.error)) {
      print(
        '[OpenClix] ERROR: $message${argument != null ? ' $argument' : ''}',
      );
    }
  }

  bool shouldLog(ClixLogLevel targetLevel) {
    return logLevelOrder[targetLevel]! >= logLevelOrder[logLevel]!;
  }
}

bool isRemoteEndpoint(String endpoint) {
  return endpoint.startsWith('http://') || endpoint.startsWith('https://');
}

class Clix {
  static ClixConfig? config;
  static TriggerService? triggerService;
  static bool initialized = false;
  static CampaignStateRepositoryPort? campaignStateRepository;
  static ClixLocalMessageScheduler? messageScheduler;
  static ClixClock? clock;
  static ClixLifecycleStateReader? lifecycleStateReader;
  static ClixLogger? logger;
  static ClixDependencies? dependencies;

  Clix._();

  static Future<void> initialize(
    ClixConfig config,
    ClixDependencies dependencies,
  ) async {
    if (initialized) {
      throw StateError(
        'Clix is already initialized. Call Clix.reset() before re-initializing.',
      );
    }

    Clix.config = config;
    Clix.dependencies = dependencies;
    messageScheduler = dependencies.messageScheduler;
    campaignStateRepository = dependencies.campaignStateRepository;
    clock = dependencies.clock ?? DefaultClock();
    lifecycleStateReader =
        dependencies.lifecycleStateReader ?? DefaultLifecycleStateReader();
    logger = dependencies.logger ?? DefaultLogger(config.logLevel);
    logger?.setLogLevel(config.logLevel);

    triggerService = TriggerService(createTriggerServiceDependencies());

    logger?.info('Initializing OpenClix SDK...');

    if (isRemoteEndpoint(config.endpoint)) {
      try {
        final requestHeaders = <String, String>{
          ...(config.extraHeaders ?? const <String, String>{}),
        };

        if (config.projectId != null && config.projectId!.isNotEmpty) {
          requestHeaders['x-openclix-project-id'] = config.projectId!;
        }

        if (config.apiKey != null && config.apiKey!.isNotEmpty) {
          requestHeaders['x-openclix-api-key'] = config.apiKey!;
        }

        final loadedConfig = await loadConfig(
          config.endpoint,
          options: ConfigLoaderOptions(
            headers: requestHeaders,
            timeoutMs: config.sessionTimeoutMs,
          ),
        );

        final validationResult = validateConfig(loadedConfig);

        if (validationResult.valid) {
          for (final warning in validationResult.warnings) {
            logger?.warn(
              'Config validation warning [${warning.code}]: ${warning.message}',
            );
          }

          triggerService?.replaceConfig(loadedConfig);

          try {
            await evaluateInternal('app_boot');
          } catch (evaluationError) {
            logger?.warn(
              'Initial app_boot evaluation failed:',
              evaluationError,
            );
          }

          logger?.info(
            'Config loaded successfully '
            '(version: ${loadedConfig.configVersion}, '
            'campaigns: ${loadedConfig.campaigns.length})',
          );
        } else {
          for (final error in validationResult.errors) {
            logger?.error(
              'Config validation error [${error.code}]: ${error.message}',
            );
          }
          logger?.warn(
            'Config validation failed. SDK initialized without campaign config.',
          );
        }
      } catch (loadError) {
        logger?.warn(
          'Failed to load config from endpoint. SDK initialized without campaign config. '
          'Use ClixCampaignManager.replaceConfig() to set config manually.',
          loadError,
        );
      }
    } else {
      logger?.info(
        'Non-HTTP endpoint provided. '
        'Use ClixCampaignManager.replaceConfig() to set campaign config.',
      );
    }

    initialized = true;
    logger?.info('OpenClix SDK initialized successfully.');
  }

  static Future<void> trackEvent(
    String name, [
    Map<String, JsonValue>? properties,
  ]) async {
    assertInitialized();

    final event = Event(
      id: generateUUID(),
      name: name,
      sourceType: EventSourceType.app,
      properties: properties,
      createdAt: clock!.now(),
    );

    logger?.debug('Event tracked (not persisted): $name');

    try {
      await evaluateInternal('event_tracked', event);
    } catch (evaluationError) {
      logger?.warn("Evaluation after event '$name' failed:", evaluationError);
    }
  }

  static Future<void> reset() async {
    final loggerAtResetStart = logger;

    if (campaignStateRepository != null) {
      try {
        await campaignStateRepository!.clearCampaignState();
      } catch (error) {
        loggerAtResetStart?.warn(
          'Failed to clear campaign state during reset:',
          error,
        );
      }
    }

    if (messageScheduler != null) {
      try {
        final pendingMessages = await messageScheduler!.listPending();
        for (final pendingMessage in pendingMessages) {
          await messageScheduler!.cancel(pendingMessage.id);
        }
      } catch (error) {
        loggerAtResetStart?.warn(
          'Failed to clear scheduled messages during reset:',
          error,
        );
      }
    }

    try {
      lifecycleStateReader?.dispose();
    } catch (error) {
      loggerAtResetStart?.warn(
        'Failed to dispose lifecycle state reader during reset:',
        error,
      );
    }

    config = null;
    triggerService = null;
    initialized = false;
    campaignStateRepository = null;
    messageScheduler = null;
    clock = null;
    lifecycleStateReader = null;
    logger = null;
    dependencies = null;

    loggerAtResetStart?.info('OpenClix SDK reset complete.');
  }

  static void setLogLevel(ClixLogLevel level) {
    logger?.setLogLevel(level);
  }

  static void handleAppForeground() {
    if (!initialized) return;

    lifecycleStateReader?.setAppState('foreground');
    logger?.debug('App entered foreground');

    evaluateInternal('app_foreground').catchError((Object error) {
      logger?.warn('app_foreground evaluation failed:', error);
      return null;
    });
  }

  static TriggerService? getTriggerServiceInternal() => triggerService;

  static ClixClock? getClockInternal() => clock;

  static ClixLogger? getLoggerInternal() => logger;

  static CampaignStateRepositoryPort? getCampaignStateRepositoryInternal() {
    return campaignStateRepository;
  }

  static ClixLocalMessageScheduler? getMessageSchedulerInternal() {
    return messageScheduler;
  }

  static bool isInitializedInternal() => initialized;

  static void assertInitialized() {
    if (!initialized) {
      throw StateError(
        'Clix is not initialized. Call Clix.initialize() before using the SDK.',
      );
    }
  }

  static TriggerServiceDependencies createTriggerServiceDependencies() {
    return TriggerServiceDependencies(
      campaignStateRepository: campaignStateRepository!,
      messageScheduler: messageScheduler!,
      clock: clock!,
      logger: logger!,
    );
  }

  static Future<TriggerResult?> evaluateInternal(
    String trigger, [
    Event? event,
  ]) async {
    if (triggerService == null) {
      return null;
    }

    return triggerService!.trigger(
      TriggerContext(trigger: trigger, event: event, now: clock?.now()),
    );
  }
}
