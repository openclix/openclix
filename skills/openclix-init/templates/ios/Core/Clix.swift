import Foundation

private final class DefaultClock: ClixClock {
    func now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}

private final class DefaultLifecycleReader: ClixLifecycleStateReader {
    private var appState: String = "foreground"

    func getAppState() -> String { return appState }
    func setAppState(_ newState: String) { appState = newState }
}

private final class DefaultLogger: ClixLogger {
    private static let logLevelOrder: [ClixLogLevel: Int] = [
        .debug: 0,
        .info: 1,
        .warn: 2,
        .error: 3,
        .none: 4,
    ]

    private var level: ClixLogLevel

    init(level: ClixLogLevel) {
        self.level = level
    }

    func setLogLevel(_ level: ClixLogLevel) {
        self.level = level
    }

    func debug(_ message: String, _ args: Any...) {
        guard shouldLog(.debug) else { return }
        print("[OpenClix:DEBUG] \(message)", args.isEmpty ? "" : " \(args)")
    }

    func info(_ message: String, _ args: Any...) {
        guard shouldLog(.info) else { return }
        print("[OpenClix:INFO] \(message)", args.isEmpty ? "" : " \(args)")
    }

    func warn(_ message: String, _ args: Any...) {
        guard shouldLog(.warn) else { return }
        print("[OpenClix:WARN] \(message)", args.isEmpty ? "" : " \(args)")
    }

    func error(_ message: String, _ args: Any...) {
        guard shouldLog(.error) else { return }
        print("[OpenClix:ERROR] \(message)", args.isEmpty ? "" : " \(args)")
    }

    private func shouldLog(_ targetLevel: ClixLogLevel) -> Bool {
        let currentOrder = DefaultLogger.logLevelOrder[level] ?? 4
        let targetOrder = DefaultLogger.logLevelOrder[targetLevel] ?? 0
        return targetOrder >= currentOrder
    }
}

private func isRemoteEndpoint(_ endpoint: String) -> Bool {
    return endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://")
}

public final class Clix {

    actor Coordinator {
        private var config: ClixConfig?
        private var triggerService: TriggerService?
        private var initialized = false

        private var campaignStateRepository: ClixCampaignStateRepository?
        private var messageScheduler: ClixMessageScheduler?
        private var clock: ClixClock?
        private var lifecycleReader: DefaultLifecycleReader?
        private var logger: DefaultLogger?

        func initialize(config: ClixConfig) async {
            guard !initialized else {
                logger?.warn("Clix is already initialized. Call Clix.reset() before re-initializing.")
                return
            }

            self.config = config

            let campaignStateRepository = FileCampaignStateRepository()
            let messageScheduler = LocalNotificationScheduler()
            let clock = DefaultClock()
            let lifecycleReader = DefaultLifecycleReader()
            let logger = DefaultLogger(level: config.logLevel)

            self.campaignStateRepository = campaignStateRepository
            self.messageScheduler = messageScheduler
            self.clock = clock
            self.lifecycleReader = lifecycleReader
            self.logger = logger

            logger.info("Initializing OpenClix SDK...")

            let triggerService = TriggerService(
                dependencies: TriggerServiceDependencies(
                    campaignStateRepository: campaignStateRepository,
                    messageScheduler: messageScheduler,
                    clock: clock,
                    logger: logger
                )
            )
            self.triggerService = triggerService

            if isRemoteEndpoint(config.endpoint) {
                do {
                    var requestHeaders = config.extraHeaders ?? [:]
                    if let projectId = config.projectId {
                        requestHeaders["x-openclix-project-id"] = projectId
                    }
                    if let apiKey = config.apiKey {
                        requestHeaders["x-openclix-api-key"] = apiKey
                    }

                    let timeoutSeconds = config.sessionTimeoutMs.map {
                        TimeInterval(Double($0) / 1000.0)
                    }

                    if let loadedConfig = try await ConfigLoader.load(
                        endpoint: config.endpoint,
                        timeoutSeconds: timeoutSeconds,
                        extraHeaders: requestHeaders
                    ) {
                        let validationResult = validateConfig(loadedConfig)

                        if validationResult.valid {
                            for warning in validationResult.warnings {
                                logger.warn(
                                    "Config validation warning [\(warning.code)]: \(warning.message)"
                                )
                            }

                            await triggerService.replaceConfig(loadedConfig)

                            let appBootContext = TriggerContext(
                                trigger: .app_boot,
                                now: clock.now()
                            )
                            _ = await triggerService.trigger(appBootContext)

                            logger.info(
                                "Config loaded successfully (version: \(loadedConfig.config_version), campaigns: \(loadedConfig.campaigns.count))"
                            )
                        } else {
                            for error in validationResult.errors {
                                logger.error(
                                    "Config validation error [\(error.code)]: \(error.message)"
                                )
                            }
                            logger.warn(
                                "Config validation failed. SDK initialized without campaign config."
                            )
                        }
                    }
                } catch {
                    logger.warn(
                        "Failed to load config from endpoint. SDK initialized without campaign config. "
                        + "Use ClixCampaignManager.replaceConfig() to set config manually. "
                        + "Error: \(error.localizedDescription)"
                    )
                }
            } else {
                logger.info(
                    "Non-HTTP endpoint provided. Use ClixCampaignManager.replaceConfig() to set campaign config."
                )
            }

            initialized = true
            logger.info("OpenClix SDK initialized successfully.")
        }

        func trackEvent(_ name: String, properties: [String: JsonValue]?) async {
            assertInitialized()

            guard let clock = clock,
                  let triggerService = triggerService else {
                return
            }

            let event = Event(
                id: generateUUID(),
                name: name,
                source_type: .app,
                properties: properties,
                created_at: clock.now()
            )

            logger?.debug("Event tracked (not persisted): \(name)")

            let context = TriggerContext(
                event: event,
                trigger: .event_tracked,
                now: clock.now()
            )
            _ = await triggerService.trigger(context)
        }

        func reset() async {
            let previousLogger = logger

            if let campaignStateRepository = campaignStateRepository {
                do {
                    try await campaignStateRepository.clearCampaignState()
                } catch {
                    previousLogger?.warn(
                        "Failed to clear campaign state during reset: \(error.localizedDescription)"
                    )
                }
            }

            if let messageScheduler = messageScheduler {
                do {
                    let pendingMessages = try await messageScheduler.listPending()
                    for pendingMessage in pendingMessages {
                        try await messageScheduler.cancel(pendingMessage.id)
                    }
                } catch {
                    previousLogger?.warn(
                        "Failed to clear scheduled messages during reset: \(error.localizedDescription)"
                    )
                }
            }

            config = nil
            triggerService = nil
            initialized = false
            campaignStateRepository = nil
            messageScheduler = nil
            clock = nil
            lifecycleReader = nil
            logger = nil

            previousLogger?.info("OpenClix SDK reset complete.")
        }

        func setLogLevel(_ level: ClixLogLevel) {
            logger?.setLogLevel(level)
        }

        func handleAppForeground() async {
            guard initialized else { return }

            lifecycleReader?.setAppState("foreground")
            logger?.debug("App entered foreground")

            if let triggerService = triggerService,
               let clock = clock {
                _ = await triggerService.trigger(
                    TriggerContext(
                        trigger: .app_foreground,
                        now: clock.now()
                    )
                )
            }
        }

        func getTriggerService() -> TriggerService? { return triggerService }
        func getClock() -> ClixClock? { return clock }
        func getLogger() -> ClixLogger? { return logger }
        func getCampaignStateRepository() -> ClixCampaignStateRepository? {
            return campaignStateRepository
        }
        func getMessageScheduler() -> ClixMessageScheduler? { return messageScheduler }
        func isInitialized() -> Bool { return initialized }

        private func assertInitialized() {
            precondition(
                initialized,
                "Clix is not initialized. Call Clix.initialize() before using the SDK."
            )
        }
    }

    static let coordinator = Coordinator()

    private init() {}

    public static func initialize(config: ClixConfig) async {
        await coordinator.initialize(config: config)
    }

    public static func trackEvent(
        _ name: String,
        properties: [String: JsonValue]? = nil
    ) async {
        await coordinator.trackEvent(name, properties: properties)
    }

    public static func reset() async {
        await coordinator.reset()
    }

    public static func setLogLevel(_ level: ClixLogLevel) {
        Task {
            await coordinator.setLogLevel(level)
        }
    }

    public static func handleAppForeground() {
        Task {
            await coordinator.handleAppForeground()
        }
    }
}
