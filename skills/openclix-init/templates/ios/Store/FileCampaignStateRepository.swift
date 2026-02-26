import Foundation

public func createDefaultCampaignStateSnapshot(now: String) -> CampaignStateSnapshot {
    return CampaignStateSnapshot(
        campaign_states: [],
        queued_messages: [],
        trigger_history: [],
        updated_at: now
    )
}

private struct CampaignStateMetaRow: Codable {
    let updated_at: String
}

public actor FileCampaignStateRepository: ClixCampaignStateRepository {

    private let campaignStatesURL: URL
    private let queuedMessagesURL: URL
    private let triggerHistoryURL: URL
    private let metaURL: URL

    public init() {
        let appSupportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let openClixDirectory = appSupportDirectory.appendingPathComponent(
            "openclix",
            isDirectory: true
        )

        try? FileManager.default.createDirectory(
            at: openClixDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        self.campaignStatesURL = openClixDirectory.appendingPathComponent("campaign_states.json")
        self.queuedMessagesURL = openClixDirectory.appendingPathComponent("queued_messages.json")
        self.triggerHistoryURL = openClixDirectory.appendingPathComponent("trigger_history.json")
        self.metaURL = openClixDirectory.appendingPathComponent("campaign_state_meta.json")
    }

    public func loadSnapshot(now: String) async throws -> CampaignStateSnapshot {
        let campaignStates: [CampaignStateRecord] = loadRows(
            at: campaignStatesURL,
            fallback: []
        )
        let queuedMessages: [CampaignQueuedMessage] = loadRows(
            at: queuedMessagesURL,
            fallback: []
        )
        let triggerHistory: [CampaignTriggerHistory] = loadRows(
            at: triggerHistoryURL,
            fallback: []
        )
        let updatedAt = loadUpdatedAt() ?? now

        return CampaignStateSnapshot(
            campaign_states: campaignStates,
            queued_messages: queuedMessages,
            trigger_history: triggerHistory,
            updated_at: updatedAt
        )
    }

    public func saveSnapshot(_ snapshot: CampaignStateSnapshot) async throws {
        try saveRows(snapshot.campaign_states, to: campaignStatesURL)
        try saveRows(snapshot.queued_messages, to: queuedMessagesURL)
        try saveRows(snapshot.trigger_history, to: triggerHistoryURL)
        try saveUpdatedAt(snapshot.updated_at)
    }

    public func clearCampaignState() async throws {
        try? FileManager.default.removeItem(at: campaignStatesURL)
        try? FileManager.default.removeItem(at: queuedMessagesURL)
        try? FileManager.default.removeItem(at: triggerHistoryURL)
        try? FileManager.default.removeItem(at: metaURL)
    }

    private func loadRows<Row: Decodable>(at url: URL, fallback: [Row]) -> [Row] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return fallback
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Row].self, from: data)
        } catch {
            return fallback
        }
    }

    private func saveRows<Row: Encodable>(_ rows: [Row], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(rows)
        try data.write(to: url, options: .atomic)
    }

    private func loadUpdatedAt() -> String? {
        guard FileManager.default.fileExists(atPath: metaURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: metaURL)
            let row = try JSONDecoder().decode(CampaignStateMetaRow.self, from: data)
            return row.updated_at.isEmpty ? nil : row.updated_at
        } catch {
            return nil
        }
    }

    private func saveUpdatedAt(_ updatedAt: String) throws {
        let row = CampaignStateMetaRow(updated_at: updatedAt)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(row)
        try data.write(to: metaURL, options: .atomic)
    }
}
