import Foundation

private final class DefaultClock: OpenClixClock, Sendable {
    func now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}

private final class DefaultLifecycleReader: OpenClixLifecycleStateReader, @unchecked Sendable {
    private let lock = NSLock()
    private var appState: String = "foreground"

    func getAppState() -> String {
        lock.lock()
        let state = appState
        lock.unlock()
        return state
    }

    func setAppState(_ newState: String) {
        lock.lock()
        appState = newState
        lock.unlock()
    }
}

private final class DefaultLogger: OpenClixLogger, @unchecked Sendable {
    private static let logLevelOrder: [OpenClixLogLevel: Int] = [
        .debug: 0,
        .info: 1,
        .warn: 2,
        .error: 3,
        .none: 4,
    ]

    private let lock = NSLock()
    private var level: OpenClixLogLevel

    init(level: OpenClixLogLevel) {
        self.level = level
    }

    func setLogLevel(_ level: OpenClixLogLevel) {
        lock.lock()
        defer { lock.unlock() }
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

    private func shouldLog(_ targetLevel: OpenClixLogLevel) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let currentLevel = level
        let currentOrder = DefaultLogger.logLevelOrder[currentLevel] ?? 4
        let targetOrder = DefaultLogger.logLevelOrder[targetLevel] ?? 0
        return targetOrder >= currentOrder
    }
}

private func isRemoteEndpoint(_ endpoint: String) -> Bool {
    return endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://")
}

private let maximumEventLogSize = 5_000

public final class OpenClix {

    actor Coordinator {
        private var config: OpenClixConfig?
        private var triggerService: TriggerService?
        private var initialized = false

        private var campaignStateRepository: OpenClixCampaignStateRepository?
        private var messageScheduler: OpenClixMessageScheduler?
        private var clock: OpenClixClock?
        private var lifecycleReader: DefaultLifecycleReader?
        private var logger: DefaultLogger?
        private var languageResolver: LanguageResolver?

        func initialize(config: OpenClixConfig) async {
            guard !initialized else {
                logger?.warn("OpenClix is already initialized. Call OpenClix.reset() before re-initializing.")
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

            let languageResolver = LanguageResolver(
                sdkDefaultLanguage: config.defaultLanguage,
                deviceLocaleProvider: IOSDeviceLocaleProvider()
            )
            self.languageResolver = languageResolver

            logger.info("Initializing OpenClix SDK...")

            let triggerService = TriggerService(
                dependencies: TriggerServiceDependencies(
                    campaignStateRepository: campaignStateRepository,
                    messageScheduler: messageScheduler,
                    clock: clock,
                    logger: logger,
                    languageResolver: languageResolver
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
                        + "Use OpenClixCampaignManager.replaceConfig() to set config manually. "
                        + "Error: \(error.localizedDescription)"
                    )
                }
            } else {
                logger.info(
                    "Non-HTTP endpoint provided. Use OpenClixCampaignManager.replaceConfig() to set campaign config."
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

            await persistEvent(event)
            logger?.debug("Event tracked: \(name)")

            let context = TriggerContext(
                event: event,
                trigger: .event_tracked,
                now: clock.now()
            )
            _ = await triggerService.trigger(context)
        }

        func trackSystemEvent(_ name: SystemEventName, properties: [String: JsonValue]?) async {
            assertInitialized()

            guard let clock = clock else { return }

            let event = Event(
                id: generateUUID(),
                name: name.rawValue,
                source_type: .system,
                properties: properties,
                created_at: clock.now()
            )

            await persistEvent(event)
        }

        func handleNotificationDelivered(payload: [String: Any]) async {
            assertInitialized()

            let campaignId = extractString(from: payload, keys: "campaignId", "campaign_id")
            let queuedMessageId = extractString(
                from: payload,
                keys: "queuedMessageId",
                "queued_message_id"
            )
            let channelType = extractString(from: payload, keys: "channelType", "channel_type")
                ?? ChannelType.app_push.rawValue

            await trackSystemEvent(
                .openClixMessageDelivered,
                properties: compactProperties(
                    [
                        "campaign_id": campaignId.map { JsonValue.string($0) },
                        "queued_message_id": queuedMessageId.map { JsonValue.string($0) },
                        "channel_type": .string(channelType),
                    ]
                )
            )
        }

        func handleNotificationOpened(payload: [String: Any]) async -> String? {
            assertInitialized()

            let campaignId = extractString(from: payload, keys: "campaignId", "campaign_id")
            let queuedMessageId = extractString(
                from: payload,
                keys: "queuedMessageId",
                "queued_message_id"
            )
            let channelType = extractString(from: payload, keys: "channelType", "channel_type")
                ?? ChannelType.app_push.rawValue
            let landingUrl = extractString(from: payload, keys: "landingUrl", "landing_url")

            await trackSystemEvent(
                .openClixMessageOpened,
                properties: compactProperties(
                    [
                        "campaign_id": campaignId.map { JsonValue.string($0) },
                        "queued_message_id": queuedMessageId.map { JsonValue.string($0) },
                        "channel_type": .string(channelType),
                        "landing_url": landingUrl.map { JsonValue.string($0) },
                    ]
                )
            )

            return landingUrl
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

                do {
                    try await campaignStateRepository.clearEvents()
                } catch {
                    previousLogger?.warn(
                        "Failed to clear event log during reset: \(error.localizedDescription)"
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
            languageResolver = nil

            previousLogger?.info("OpenClix SDK reset complete.")
        }

        func setLogLevel(_ level: OpenClixLogLevel) async {
            logger?.setLogLevel(level)
            await triggerService?.setLogLevel(level)
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

        func setLanguage(_ languageCode: String) {
            languageResolver?.setLanguage(languageCode)
        }

        func getLanguage() -> String? {
            return languageResolver?.getLanguage()
        }

        func clearLanguage() {
            languageResolver?.clearLanguage()
        }

        func getTriggerService() -> TriggerService? { return triggerService }
        func getClock() -> OpenClixClock? { return clock }
        func getLogger() -> OpenClixLogger? { return logger }
        func getCampaignStateRepository() -> OpenClixCampaignStateRepository? {
            return campaignStateRepository
        }
        func getMessageScheduler() -> OpenClixMessageScheduler? { return messageScheduler }
        func isInitialized() -> Bool { return initialized }

        private func persistEvent(_ event: Event) async {
            guard let campaignStateRepository = campaignStateRepository else {
                logger?.debug(
                    "Event store is not available; skipping persistence for event '\(event.name)'."
                )
                return
            }

            do {
                try await campaignStateRepository.appendEvents(
                    [event],
                    maxEntries: maximumEventLogSize
                )
            } catch {
                logger?.warn(
                    "Failed to persist event '\(event.name)': \(error.localizedDescription)"
                )
            }
        }

        private func extractString(from source: [String: Any], keys: String...) -> String? {
            for key in keys {
                guard let value = source[key] as? String else { continue }
                if !value.isEmpty {
                    return value
                }
            }
            return nil
        }

        private func compactProperties(
            _ values: [String: JsonValue?]
        ) -> [String: JsonValue] {
            var compacted: [String: JsonValue] = [:]
            for (key, value) in values {
                if let value {
                    compacted[key] = value
                }
            }
            return compacted
        }

        private func assertInitialized() {
            precondition(
                initialized,
                "OpenClix is not initialized. Call OpenClix.initialize() before using the SDK."
            )
        }
    }

    static let coordinator = Coordinator()

    private init() {}

    public static func initialize(config: OpenClixConfig) async {
        await coordinator.initialize(config: config)
    }

    public static func trackEvent(
        _ name: String,
        properties: [String: JsonValue]? = nil
    ) async {
        await coordinator.trackEvent(name, properties: properties)
    }

    public static func trackSystemEvent(
        name: SystemEventName,
        properties: [String: JsonValue]? = nil
    ) async {
        await coordinator.trackSystemEvent(name, properties: properties)
    }

    public static func handleNotificationDelivered(payload: [String: Any]) async {
        await coordinator.handleNotificationDelivered(payload: payload)
    }

    public static func handleNotificationOpened(payload: [String: Any]) async -> String? {
        return await coordinator.handleNotificationOpened(payload: payload)
    }

    public static func reset() async {
        await coordinator.reset()
    }

    public static func setLogLevel(_ level: OpenClixLogLevel) {
        Task {
            await coordinator.setLogLevel(level)
        }
    }

    public static func handleAppForeground() {
        Task {
            await coordinator.handleAppForeground()
        }
    }

    public static func setLanguage(_ languageCode: String) async {
        await coordinator.setLanguage(languageCode)
    }

    public static func getLanguage() async -> String? {
        return await coordinator.getLanguage()
    }

    public static func clearLanguage() async {
        await coordinator.clearLanguage()
    }
}
