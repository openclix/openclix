import '../engine/trigger_service.dart';
import '../infrastructure/flutter_device_locale_provider.dart';
import '../models/openclix_types.dart';
import '../services/config_loader.dart';
import '../services/config_validator.dart';
import '../services/language_resolver.dart';
import '../services/utils.dart';

class OpenClixDependencies {
  final OpenClixLocalMessageScheduler messageScheduler;
  final CampaignStateRepositoryPort campaignStateRepository;
  final OpenClixClock? clock;
  final OpenClixLifecycleStateReader? lifecycleStateReader;
  final OpenClixLogger? logger;

  const OpenClixDependencies({
    required this.messageScheduler,
    required this.campaignStateRepository,
    this.clock,
    this.lifecycleStateReader,
    this.logger,
  });
}

class DefaultClock implements OpenClixClock {
  @override
  String now() => DateTime.now().toUtc().toIso8601String();
}

class DefaultLifecycleStateReader implements OpenClixLifecycleStateReader {
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

class DefaultLogger implements OpenClixLogger {
  OpenClixLogLevel logLevel;

  static const Map<OpenClixLogLevel, int> logLevelOrder = {
    OpenClixLogLevel.debug: 0,
    OpenClixLogLevel.info: 1,
    OpenClixLogLevel.warn: 2,
    OpenClixLogLevel.error: 3,
    OpenClixLogLevel.none: 4,
  };

  DefaultLogger(this.logLevel);

  @override
  void setLogLevel(OpenClixLogLevel level) {
    logLevel = level;
  }

  @override
  void debug(String message, [Object? argument]) {
    if (shouldLog(OpenClixLogLevel.debug)) {
      print(
        '[OpenClix] DEBUG: $message${argument != null ? ' $argument' : ''}',
      );
    }
  }

  @override
  void info(String message, [Object? argument]) {
    if (shouldLog(OpenClixLogLevel.info)) {
      print('[OpenClix] INFO: $message${argument != null ? ' $argument' : ''}');
    }
  }

  @override
  void warn(String message, [Object? argument]) {
    if (shouldLog(OpenClixLogLevel.warn)) {
      print('[OpenClix] WARN: $message${argument != null ? ' $argument' : ''}');
    }
  }

  @override
  void error(String message, [Object? argument]) {
    if (shouldLog(OpenClixLogLevel.error)) {
      print(
        '[OpenClix] ERROR: $message${argument != null ? ' $argument' : ''}',
      );
    }
  }

  bool shouldLog(OpenClixLogLevel targetLevel) {
    return logLevelOrder[targetLevel]! >= logLevelOrder[logLevel]!;
  }
}

bool isRemoteEndpoint(String endpoint) {
  return endpoint.startsWith('http://') || endpoint.startsWith('https://');
}

const int maximumEventLogSize = 5000;

class OpenClix {
  static OpenClixConfig? config;
  static TriggerService? triggerService;
  static bool initialized = false;
  static CampaignStateRepositoryPort? campaignStateRepository;
  static OpenClixLocalMessageScheduler? messageScheduler;
  static OpenClixClock? clock;
  static OpenClixLifecycleStateReader? lifecycleStateReader;
  static OpenClixLogger? logger;
  static OpenClixDependencies? dependencies;
  static LanguageResolver? _languageResolver;

  OpenClix._();

  static Future<void> initialize(
    OpenClixConfig config,
    OpenClixDependencies dependencies,
  ) async {
    if (initialized) {
      throw StateError(
        'OpenClix is already initialized. Call OpenClix.reset() before re-initializing.',
      );
    }

    OpenClix.config = config;
    OpenClix.dependencies = dependencies;
    messageScheduler = dependencies.messageScheduler;
    campaignStateRepository = dependencies.campaignStateRepository;
    clock = dependencies.clock ?? DefaultClock();
    lifecycleStateReader =
        dependencies.lifecycleStateReader ?? DefaultLifecycleStateReader();
    logger = dependencies.logger ?? DefaultLogger(config.logLevel);
    logger?.setLogLevel(config.logLevel);

    _languageResolver = LanguageResolver(
      sdkDefaultLanguage: config.defaultLanguage,
      deviceLocaleProvider: FlutterDeviceLocaleProvider(),
    );

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
          'Use OpenClixCampaignManager.replaceConfig() to set config manually.',
          loadError,
        );
      }
    } else {
      logger?.info(
        'Non-HTTP endpoint provided. '
        'Use OpenClixCampaignManager.replaceConfig() to set campaign config.',
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

    await persistEvent(event);
    logger?.debug('Event tracked: $name');

    try {
      await evaluateInternal('event_tracked', event);
    } catch (evaluationError) {
      logger?.warn("Evaluation after event '$name' failed:", evaluationError);
    }
  }

  static Future<void> trackSystemEvent(
    SystemEventName name, [
    Map<String, JsonValue>? properties,
  ]) async {
    assertInitialized();

    final event = Event(
      id: generateUUID(),
      name: name.value,
      sourceType: EventSourceType.system,
      properties: properties,
      createdAt: clock!.now(),
    );

    await persistEvent(event);
  }

  static Future<void> handleNotificationDelivered(
    Map<String, Object?> payload,
  ) async {
    assertInitialized();

    await trackSystemEvent(
      SystemEventName.messageDelivered,
      compactProperties({
        'campaign_id': extractString(payload, const [
          'campaignId',
          'campaign_id',
        ]),
        'queued_message_id': extractString(payload, const [
          'queuedMessageId',
          'queued_message_id',
        ]),
        'channel_type':
            extractString(payload, const ['channelType', 'channel_type']) ??
            ChannelType.appPush.value,
      }),
    );
  }

  static Future<String?> handleNotificationOpened(
    Map<String, Object?> payload,
  ) async {
    assertInitialized();

    final landingUrl = extractString(payload, const [
      'landingUrl',
      'landing_url',
    ]);

    await trackSystemEvent(
      SystemEventName.messageOpened,
      compactProperties({
        'campaign_id': extractString(payload, const [
          'campaignId',
          'campaign_id',
        ]),
        'queued_message_id': extractString(payload, const [
          'queuedMessageId',
          'queued_message_id',
        ]),
        'channel_type':
            extractString(payload, const ['channelType', 'channel_type']) ??
            ChannelType.appPush.value,
        'landing_url': landingUrl,
      }),
    );

    return landingUrl;
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

      try {
        await campaignStateRepository!.clearEvents();
      } catch (error) {
        loggerAtResetStart?.warn(
          'Failed to clear event log during reset:',
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
    _languageResolver = null;

    loggerAtResetStart?.info('OpenClix SDK reset complete.');
  }

  static void setLogLevel(OpenClixLogLevel level) {
    logger?.setLogLevel(level);
  }

  static void setLanguage(String languageCode) {
    assertInitialized();
    _languageResolver?.setLanguage(languageCode);
  }

  static String? getLanguage() {
    assertInitialized();
    return _languageResolver?.getLanguage();
  }

  static void clearLanguage() {
    assertInitialized();
    _languageResolver?.clearLanguage();
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

  static OpenClixClock? getClockInternal() => clock;

  static OpenClixLogger? getLoggerInternal() => logger;

  static CampaignStateRepositoryPort? getCampaignStateRepositoryInternal() {
    return campaignStateRepository;
  }

  static OpenClixLocalMessageScheduler? getMessageSchedulerInternal() {
    return messageScheduler;
  }

  static bool isInitializedInternal() => initialized;

  static void assertInitialized() {
    if (!initialized) {
      throw StateError(
        'OpenClix is not initialized. Call OpenClix.initialize() before using the SDK.',
      );
    }
  }

  static TriggerServiceDependencies createTriggerServiceDependencies() {
    return TriggerServiceDependencies(
      campaignStateRepository: campaignStateRepository!,
      messageScheduler: messageScheduler!,
      clock: clock!,
      logger: logger!,
      recordEvent: (event) async {
        await persistEvent(event);
      },
      languageResolver: _languageResolver,
    );
  }

  static Future<void> persistEvent(Event event) async {
    if (campaignStateRepository == null) {
      logger?.debug(
        "Event store is not available; skipping persistence for event '${event.name}'.",
      );
      return;
    }

    try {
      await campaignStateRepository!.appendEvents([event], maximumEventLogSize);
    } catch (error) {
      logger?.warn("Failed to persist event '${event.name}':", error);
    }
  }

  static String? extractString(Map<String, Object?> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static Map<String, JsonValue> compactProperties(
    Map<String, JsonValue?> values,
  ) {
    final compacted = <String, JsonValue>{};
    values.forEach((key, value) {
      if (value != null) {
        compacted[key] = value;
      }
    });
    return compacted;
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
