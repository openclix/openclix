import Foundation

public struct ScheduledMessageFilter {
    public let campaign_id: String?
    public let status: String?

    public init(campaign_id: String? = nil, status: String? = nil) {
        self.campaign_id = campaign_id
        self.status = status
    }
}

private func currentIsoTime() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
}

public final class ClixCampaignManager {

    private init() {}

    public static func replaceConfig(_ config: Config) async -> TriggerResult? {
        let coordinator = Clix.coordinator

        guard await coordinator.isInitialized() else {
            assertionFailure(
                "Clix is not initialized. Call Clix.initialize() before using ClixCampaignManager."
            )
            return nil
        }

        guard let triggerService = await coordinator.getTriggerService() else {
            let logger = await coordinator.getLogger()
            logger?.error("Cannot replace config: trigger service is not available.")
            return nil
        }

        let logger = await coordinator.getLogger()
        let validationResult = validateConfig(config)

        if !validationResult.valid {
            for error in validationResult.errors {
                logger?.error("Config validation error [\(error.code)]: \(error.message)")
            }
            logger?.warn("Config replacement rejected due to validation errors.")
            return nil
        }

        for warning in validationResult.warnings {
            logger?.warn("Config validation warning [\(warning.code)]: \(warning.message)")
        }

        await triggerService.replaceConfig(config)

        logger?.info(
            "Config replaced (version: \(config.config_version), campaigns: \(config.campaigns.count))"
        )

        let clock = await coordinator.getClock()
        let context = TriggerContext(
            trigger: .config_replaced,
            now: clock?.now()
        )

        return await triggerService.trigger(context)
    }

    public static func getConfig() async -> Config? {
        let coordinator = Clix.coordinator

        guard await coordinator.isInitialized() else { return nil }
        guard let triggerService = await coordinator.getTriggerService() else { return nil }

        return await triggerService.getConfig()
    }

    public static func getSnapshot() async -> CampaignStateSnapshot {
        let coordinator = Clix.coordinator
        let now = currentIsoTime()

        guard await coordinator.isInitialized() else {
            return createDefaultCampaignStateSnapshot(now: now)
        }

        guard let campaignStateRepository = await coordinator.getCampaignStateRepository() else {
            return createDefaultCampaignStateSnapshot(now: now)
        }

        do {
            return try await campaignStateRepository.loadSnapshot(now: now)
        } catch {
            let logger = await coordinator.getLogger()
            logger?.warn("Failed to load campaign state snapshot: \(error.localizedDescription)")
            return createDefaultCampaignStateSnapshot(now: now)
        }
    }

    public static func getScheduledMessages(
        filter: ScheduledMessageFilter? = nil
    ) async -> [QueuedMessage] {
        let coordinator = Clix.coordinator

        guard await coordinator.isInitialized() else { return [] }
        guard let messageScheduler = await coordinator.getMessageScheduler() else { return [] }

        let pendingMessages: [QueuedMessage]
        do {
            pendingMessages = try await messageScheduler.listPending()
        } catch {
            let logger = await coordinator.getLogger()
            logger?.error("Failed to list pending messages: \(error.localizedDescription)")
            return []
        }

        guard let filter else { return pendingMessages }

        return pendingMessages.filter { pendingMessage in
            if let campaignId = filter.campaign_id,
               pendingMessage.campaign_id != campaignId {
                return false
            }
            if let status = filter.status,
               pendingMessage.status.rawValue != status {
                return false
            }
            return true
        }
    }
}
