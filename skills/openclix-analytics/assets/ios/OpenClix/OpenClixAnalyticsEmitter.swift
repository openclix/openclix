import Foundation

public enum OpenClixSourceType: String {
    case app
    case system
}

public enum OpenClixAnalysisPeriod: String {
    case pre
    case post
}

public struct OpenClixAnalyticsEvent {
    public let name: String
    public let sourceType: OpenClixSourceType
    public let properties: [String: Any]

    public init(name: String, sourceType: OpenClixSourceType, properties: [String: Any] = [:]) {
        self.name = name
        self.sourceType = sourceType
        self.properties = properties
    }
}

public final class OpenClixAnalyticsEmitter {
    public typealias Sink = (_ eventName: String, _ properties: [String: Any]) -> Void
    public typealias NameTransform = (_ canonicalName: String) -> String

    private let platform: String
    private let analysisPeriod: OpenClixAnalysisPeriod
    private let campaignActive: Bool
    private let sink: Sink
    private let nameTransform: NameTransform?

    public init(
        platform: String,
        analysisPeriod: OpenClixAnalysisPeriod,
        campaignActive: Bool,
        sink: @escaping Sink,
        nameTransform: NameTransform? = nil
    ) {
        self.platform = platform
        self.analysisPeriod = analysisPeriod
        self.campaignActive = campaignActive
        self.sink = sink
        self.nameTransform = nameTransform
    }

    public func emit(_ event: OpenClixAnalyticsEvent) {
        var merged = event.properties
        merged["openclix_source"] = "openclix"
        merged["openclix_event_name"] = event.name
        merged["openclix_source_type"] = event.sourceType.rawValue
        merged["openclix_platform"] = platform
        merged["openclix_campaign_id"] = stringOrNil(event.properties["campaign_id"])
        merged["openclix_queued_message_id"] = stringOrNil(event.properties["queued_message_id"])
        merged["openclix_channel_type"] = stringOrNil(event.properties["channel_type"])
        merged["openclix_analysis_period"] = analysisPeriod.rawValue
        merged["openclix_campaign_active"] = campaignActive ? "true" : "false"

        let outboundName = nameTransform?(event.name) ?? event.name
        sink(outboundName, merged)
    }

    private func stringOrNil(_ value: Any?) -> String? {
        return value as? String
    }
}

public func normalizeFirebaseEventName(_ name: String) -> String {
    let lowered = name.lowercased()
    let normalized = lowered.replacingOccurrences(
        of: "[^a-z0-9_]",
        with: "_",
        options: .regularExpression
    )
    let prefixed = normalized.range(of: "^[a-z]", options: .regularExpression) == nil
        ? "oc_\(normalized)"
        : normalized
    return String(prefixed.prefix(40))
}
