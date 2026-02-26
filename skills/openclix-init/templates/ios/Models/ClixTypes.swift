import Foundation

// MARK: - JSON Value

public enum JsonValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JsonValue])
    case object([String: JsonValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }
        if let intValue = try? container.decode(Int.self) {
            self = .number(Double(intValue))
            return
        }
        if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
            return
        }
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        if let arrayValue = try? container.decode([JsonValue].self) {
            self = .array(arrayValue)
            return
        }
        if let objectValue = try? container.decode([String: JsonValue].self) {
            self = .object(objectValue)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode JsonValue"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Config (from JSON, snake_case)

public struct Config: Codable, Equatable {
    public let schema_version: String
    public let config_version: String
    public let settings: Settings?
    public let campaigns: [String: Campaign]

    public init(
        schema_version: String,
        config_version: String,
        settings: Settings? = nil,
        campaigns: [String: Campaign]
    ) {
        self.schema_version = schema_version
        self.config_version = config_version
        self.settings = settings
        self.campaigns = campaigns
    }
}

public struct Settings: Codable, Equatable {
    public let frequency_cap: FrequencyCap?
    public let do_not_disturb: DoNotDisturb?

    public init(
        frequency_cap: FrequencyCap? = nil,
        do_not_disturb: DoNotDisturb? = nil
    ) {
        self.frequency_cap = frequency_cap
        self.do_not_disturb = do_not_disturb
    }
}

public struct FrequencyCap: Codable, Equatable {
    public let max_count: Int
    public let window_seconds: Int

    public init(max_count: Int, window_seconds: Int) {
        self.max_count = max_count
        self.window_seconds = window_seconds
    }
}

public struct DoNotDisturb: Codable, Equatable {
    public let start_hour: Int
    public let end_hour: Int

    public init(start_hour: Int, end_hour: Int) {
        self.start_hour = start_hour
        self.end_hour = end_hour
    }
}

public enum CampaignStatus: String, Codable, Equatable {
    case running
    case paused
}

public struct Campaign: Codable, Equatable {
    public let name: String
    public let type: String
    public let description: String
    public let status: CampaignStatus
    public let trigger: CampaignTrigger
    public let message: Message

    public init(
        name: String,
        type: String,
        description: String,
        status: CampaignStatus,
        trigger: CampaignTrigger,
        message: Message
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.status = status
        self.trigger = trigger
        self.message = message
    }
}

public enum TriggerType: String, Codable, Equatable {
    case event
    case scheduled
    case recurring
}

public struct CampaignTrigger: Codable, Equatable {
    public let type: TriggerType
    public let event: EventTriggerConfig?
    public let scheduled: ScheduledTriggerConfig?
    public let recurring: RecurringTriggerConfig?

    public init(
        type: TriggerType,
        event: EventTriggerConfig? = nil,
        scheduled: ScheduledTriggerConfig? = nil,
        recurring: RecurringTriggerConfig? = nil
    ) {
        self.type = type
        self.event = event
        self.scheduled = scheduled
        self.recurring = recurring
    }
}

public struct EventTriggerConfig: Codable, Equatable {
    public let trigger_event: EventConditionGroup
    public let delay_seconds: Int?
    public let cancel_event: EventConditionGroup?

    public init(
        trigger_event: EventConditionGroup,
        delay_seconds: Int? = nil,
        cancel_event: EventConditionGroup? = nil
    ) {
        self.trigger_event = trigger_event
        self.delay_seconds = delay_seconds
        self.cancel_event = cancel_event
    }
}

public struct ScheduledTriggerConfig: Codable, Equatable {
    public let execute_at: String

    public init(execute_at: String) {
        self.execute_at = execute_at
    }
}

public enum RecurrenceType: String, Codable, Equatable {
    case hourly
    case daily
    case weekly
}

public enum DayOfWeek: String, Codable, Equatable {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
}

public struct TimeOfDay: Codable, Equatable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

public struct WeeklyRule: Codable, Equatable {
    public let days_of_week: [DayOfWeek]

    public init(days_of_week: [DayOfWeek]) {
        self.days_of_week = days_of_week
    }
}

public struct RecurrenceRule: Codable, Equatable {
    public let type: RecurrenceType
    public let interval: Int
    public let weekly_rule: WeeklyRule?
    public let time_of_day: TimeOfDay?

    public init(
        type: RecurrenceType,
        interval: Int,
        weekly_rule: WeeklyRule? = nil,
        time_of_day: TimeOfDay? = nil
    ) {
        self.type = type
        self.interval = interval
        self.weekly_rule = weekly_rule
        self.time_of_day = time_of_day
    }
}

public struct RecurringTriggerConfig: Codable, Equatable {
    public let start_at: String?
    public let end_at: String?
    public let rule: RecurrenceRule

    public init(start_at: String? = nil, end_at: String? = nil, rule: RecurrenceRule) {
        self.start_at = start_at
        self.end_at = end_at
        self.rule = rule
    }
}

public struct EventConditionGroup: Codable, Equatable {
    public let connector: ConditionConnector
    public let conditions: [EventCondition]

    public init(connector: ConditionConnector, conditions: [EventCondition]) {
        self.connector = connector
        self.conditions = conditions
    }
}

public enum ConditionConnector: String, Codable, Equatable {
    case and
    case or
}

public enum EventConditionField: String, Codable, Equatable {
    case name
    case property
}

public struct EventCondition: Codable, Equatable {
    public let field: EventConditionField
    public let property_name: String?
    public let `operator`: EventConditionOperator
    public let values: [String]

    public init(
        field: EventConditionField,
        property_name: String? = nil,
        operator: EventConditionOperator,
        values: [String]
    ) {
        self.field = field
        self.property_name = property_name
        self.operator = `operator`
        self.values = values
    }
}

public enum EventConditionOperator: String, Codable, Equatable {
    case equal
    case not_equal
    case greater_than
    case greater_than_or_equal
    case less_than
    case less_than_or_equal
    case contains
    case not_contains
    case starts_with
    case ends_with
    case matches
    case exists
    case not_exists
    case `in`
    case not_in
}

public enum ChannelType: String, Codable, Equatable {
    case app_push
}

public struct Message: Codable, Equatable {
    public let channel_type: ChannelType
    public let content: MessageContent

    public init(channel_type: ChannelType, content: MessageContent) {
        self.channel_type = channel_type
        self.content = content
    }
}

public struct MessageContent: Codable, Equatable {
    public let title: String
    public let body: String
    public let image_url: String?
    public let landing_url: String?

    public init(
        title: String,
        body: String,
        image_url: String? = nil,
        landing_url: String? = nil
    ) {
        self.title = title
        self.body = body
        self.image_url = image_url
        self.landing_url = landing_url
    }
}

// MARK: - Queued Message

public enum QueuedMessageStatus: String, Codable, Equatable {
    case scheduled
    case delivered
    case cancelled
}

public enum SkipReason: String, Codable, Equatable {
    case campaign_not_running
    case campaign_frequency_cap_exceeded
    case campaign_do_not_disturb_blocked
    case trigger_event_not_matched
    case trigger_cancel_event_matched
}

public struct QueuedMessage: Codable, Equatable {
    public let id: String
    public let campaign_id: String
    public let channel_type: ChannelType
    public let status: QueuedMessageStatus
    public let content: QueuedMessageContent
    public let trigger_event_id: String?
    public let skip_reason: SkipReason?
    public let execute_at: String
    public let created_at: String

    public init(
        id: String,
        campaign_id: String,
        channel_type: ChannelType,
        status: QueuedMessageStatus,
        content: QueuedMessageContent,
        trigger_event_id: String? = nil,
        skip_reason: SkipReason? = nil,
        execute_at: String,
        created_at: String
    ) {
        self.id = id
        self.campaign_id = campaign_id
        self.channel_type = channel_type
        self.status = status
        self.content = content
        self.trigger_event_id = trigger_event_id
        self.skip_reason = skip_reason
        self.execute_at = execute_at
        self.created_at = created_at
    }
}

public struct QueuedMessageContent: Codable, Equatable {
    public let title: String
    public let body: String
    public let image_url: String?
    public let landing_url: String?

    public init(
        title: String,
        body: String,
        image_url: String? = nil,
        landing_url: String? = nil
    ) {
        self.title = title
        self.body = body
        self.image_url = image_url
        self.landing_url = landing_url
    }
}

// MARK: - Event

public enum EventSourceType: String, Codable, Equatable {
    case app
    case system
}

public struct Event: Codable, Equatable {
    public let id: String
    public let name: String
    public let source_type: EventSourceType
    public let properties: [String: JsonValue]?
    public let created_at: String

    public init(
        id: String,
        name: String,
        source_type: EventSourceType,
        properties: [String: JsonValue]? = nil,
        created_at: String
    ) {
        self.id = id
        self.name = name
        self.source_type = source_type
        self.properties = properties
        self.created_at = created_at
    }
}

// MARK: - Runtime Types

public enum ClixLogLevel: String, Codable, Equatable {
    case debug
    case info
    case warn
    case error
    case none
}

public enum EvaluationTrigger: String, Codable, Equatable {
    case app_boot
    case app_foreground
    case event_tracked
    case config_replaced
}

public struct TriggerContext: Equatable {
    public let event: Event?
    public let trigger: EvaluationTrigger
    public let now: String?

    public init(event: Event? = nil, trigger: EvaluationTrigger, now: String? = nil) {
        self.event = event
        self.trigger = trigger
        self.now = now
    }
}

public enum DecisionResult: String, Codable, Equatable {
    case applied
    case skipped
}

public struct DecisionTrace: Codable, Equatable {
    public let campaign_id: String
    public let action: String
    public let result: DecisionResult
    public let skip_reason: SkipReason?
    public let reason: String

    public init(
        campaign_id: String,
        action: String,
        result: DecisionResult,
        skip_reason: SkipReason? = nil,
        reason: String
    ) {
        self.campaign_id = campaign_id
        self.action = action
        self.result = result
        self.skip_reason = skip_reason
        self.reason = reason
    }
}

public struct TriggerResult: Equatable {
    public let evaluated_at: String
    public let trigger: String
    public let traces: [DecisionTrace]
    public let queued_messages: [QueuedMessage]

    public init(
        evaluated_at: String,
        trigger: String,
        traces: [DecisionTrace],
        queued_messages: [QueuedMessage]
    ) {
        self.evaluated_at = evaluated_at
        self.trigger = trigger
        self.traces = traces
        self.queued_messages = queued_messages
    }
}

public struct CampaignStateSnapshot: Codable, Equatable {
    public var campaign_states: [CampaignStateRecord]
    public var queued_messages: [CampaignQueuedMessage]
    public var trigger_history: [CampaignTriggerHistory]
    public var updated_at: String

    public init(
        campaign_states: [CampaignStateRecord] = [],
        queued_messages: [CampaignQueuedMessage] = [],
        trigger_history: [CampaignTriggerHistory] = [],
        updated_at: String
    ) {
        self.campaign_states = campaign_states
        self.queued_messages = queued_messages
        self.trigger_history = trigger_history
        self.updated_at = updated_at
    }
}

public struct CampaignStateRecord: Codable, Equatable {
    public var campaign_id: String
    public var triggered: Bool
    public var delivery_count: Int
    public var last_triggered_at: String?
    public var recurring_anchor_at: String?
    public var recurring_last_scheduled_at: String?

    public init(
        campaign_id: String,
        triggered: Bool,
        delivery_count: Int,
        last_triggered_at: String? = nil,
        recurring_anchor_at: String? = nil,
        recurring_last_scheduled_at: String? = nil
    ) {
        self.campaign_id = campaign_id
        self.triggered = triggered
        self.delivery_count = delivery_count
        self.last_triggered_at = last_triggered_at
        self.recurring_anchor_at = recurring_anchor_at
        self.recurring_last_scheduled_at = recurring_last_scheduled_at
    }
}

public struct CampaignQueuedMessage: Codable, Equatable {
    public let message_id: String
    public let campaign_id: String
    public let execute_at: String
    public let trigger_type: TriggerType
    public let trigger_event_id: String?
    public let created_at: String

    public init(
        message_id: String,
        campaign_id: String,
        execute_at: String,
        trigger_type: TriggerType,
        trigger_event_id: String? = nil,
        created_at: String
    ) {
        self.message_id = message_id
        self.campaign_id = campaign_id
        self.execute_at = execute_at
        self.trigger_type = trigger_type
        self.trigger_event_id = trigger_event_id
        self.created_at = created_at
    }
}

public struct CampaignTriggerHistory: Codable, Equatable {
    public let campaign_id: String?
    public let triggered_at: String

    public init(campaign_id: String? = nil, triggered_at: String) {
        self.campaign_id = campaign_id
        self.triggered_at = triggered_at
    }
}

// MARK: - SDK Configuration

public struct ClixConfig {
    public let endpoint: String
    public var projectId: String?
    public var apiKey: String?
    public var logLevel: ClixLogLevel
    public var extraHeaders: [String: String]?
    public var sessionTimeoutMs: Int?

    public init(
        endpoint: String,
        projectId: String? = nil,
        apiKey: String? = nil,
        logLevel: ClixLogLevel = .warn,
        extraHeaders: [String: String]? = nil,
        sessionTimeoutMs: Int? = nil
    ) {
        self.endpoint = endpoint
        self.projectId = projectId
        self.apiKey = apiKey
        self.logLevel = logLevel
        self.extraHeaders = extraHeaders
        self.sessionTimeoutMs = sessionTimeoutMs
    }
}

// MARK: - Dependency Protocols

public protocol ClixClock {
    func now() -> String
}

public protocol ClixLifecycleStateReader {
    func getAppState() -> String
    func setAppState(_ newState: String)
}

public protocol ClixLogger {
    func debug(_ message: String, _ args: Any...)
    func info(_ message: String, _ args: Any...)
    func warn(_ message: String, _ args: Any...)
    func error(_ message: String, _ args: Any...)
    func setLogLevel(_ level: ClixLogLevel)
}

public protocol ClixMessageScheduler {
    func schedule(_ record: QueuedMessage) async throws
    func cancel(_ id: String) async throws
    func listPending() async throws -> [QueuedMessage]
}

public protocol ClixCampaignStateRepository {
    func loadSnapshot(now: String) async throws -> CampaignStateSnapshot
    func saveSnapshot(_ snapshot: CampaignStateSnapshot) async throws
    func clearCampaignState() async throws
}
