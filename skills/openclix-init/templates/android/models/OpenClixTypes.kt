package ai.openclix.models

import org.json.JSONArray
import org.json.JSONObject

// ---------------------------------------------------------------------------
// Config (from JSON) — mirrors openclix.schema.json (snake_case)
// ---------------------------------------------------------------------------

data class Config(
    val schema_version: String,
    val config_version: String,
    val settings: Settings? = null,
    val campaigns: Map<String, Campaign>
) {
    companion object {
        fun fromJson(json: JSONObject): Config {
            val campaignsJson = json.getJSONObject("campaigns")
            val campaigns = mutableMapOf<String, Campaign>()
            for (campaignId in campaignsJson.keys()) {
                campaigns[campaignId] = Campaign.fromJson(campaignsJson.getJSONObject(campaignId))
            }
            return Config(
                schema_version = json.getString("schema_version"),
                config_version = json.getString("config_version"),
                settings = if (json.has("settings") && !json.isNull("settings")) {
                    Settings.fromJson(json.getJSONObject("settings"))
                } else {
                    null
                },
                campaigns = campaigns
            )
        }
    }
}

data class Settings(
    val frequency_cap: FrequencyCap? = null,
    val do_not_disturb: DoNotDisturb? = null
) {
    companion object {
        fun fromJson(json: JSONObject): Settings = Settings(
            frequency_cap = if (json.has("frequency_cap") && !json.isNull("frequency_cap")) {
                FrequencyCap.fromJson(json.getJSONObject("frequency_cap"))
            } else {
                null
            },
            do_not_disturb = if (json.has("do_not_disturb") && !json.isNull("do_not_disturb")) {
                DoNotDisturb.fromJson(json.getJSONObject("do_not_disturb"))
            } else {
                null
            }
        )
    }
}

data class FrequencyCap(
    val max_count: Int,
    val window_seconds: Int
) {
    companion object {
        fun fromJson(json: JSONObject): FrequencyCap = FrequencyCap(
            max_count = json.getInt("max_count"),
            window_seconds = json.getInt("window_seconds")
        )
    }
}

data class DoNotDisturb(
    val start_hour: Int,
    val end_hour: Int
) {
    companion object {
        fun fromJson(json: JSONObject): DoNotDisturb = DoNotDisturb(
            start_hour = json.getInt("start_hour"),
            end_hour = json.getInt("end_hour")
        )
    }
}

enum class CampaignStatus(val value: String) {
    RUNNING("running"),
    PAUSED("paused");

    companion object {
        fun fromValue(value: String): CampaignStatus =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown CampaignStatus: $value")
    }
}

data class Campaign(
    val name: String,
    val type: String,
    val description: String,
    val status: CampaignStatus,
    val trigger: CampaignTrigger,
    val message: Message
) {
    companion object {
        fun fromJson(json: JSONObject): Campaign = Campaign(
            name = json.getString("name"),
            type = json.getString("type"),
            description = json.optString("description", ""),
            status = CampaignStatus.fromValue(json.getString("status")),
            trigger = CampaignTrigger.fromJson(json.getJSONObject("trigger")),
            message = Message.fromJson(json.getJSONObject("message"))
        )
    }
}

enum class TriggerType(val value: String) {
    EVENT("event"),
    SCHEDULED("scheduled"),
    RECURRING("recurring");

    companion object {
        fun fromValue(value: String): TriggerType =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown TriggerType: $value")
    }
}

data class CampaignTrigger(
    val type: TriggerType,
    val event: EventTriggerConfig? = null,
    val scheduled: ScheduledTriggerConfig? = null,
    val recurring: RecurringTriggerConfig? = null
) {
    companion object {
        fun fromJson(json: JSONObject): CampaignTrigger = CampaignTrigger(
            type = TriggerType.fromValue(json.getString("type")),
            event = if (json.has("event") && !json.isNull("event")) {
                EventTriggerConfig.fromJson(json.getJSONObject("event"))
            } else {
                null
            },
            scheduled = if (json.has("scheduled") && !json.isNull("scheduled")) {
                ScheduledTriggerConfig.fromJson(json.getJSONObject("scheduled"))
            } else {
                null
            },
            recurring = if (json.has("recurring") && !json.isNull("recurring")) {
                RecurringTriggerConfig.fromJson(json.getJSONObject("recurring"))
            } else {
                null
            }
        )
    }
}

data class EventTriggerConfig(
    val trigger_event: EventConditionGroup,
    val delay_seconds: Int? = null,
    val cancel_event: EventConditionGroup? = null
) {
    companion object {
        fun fromJson(json: JSONObject): EventTriggerConfig = EventTriggerConfig(
            trigger_event = EventConditionGroup.fromJson(json.getJSONObject("trigger_event")),
            delay_seconds = if (json.has("delay_seconds") && !json.isNull("delay_seconds")) {
                json.getInt("delay_seconds")
            } else {
                null
            },
            cancel_event = if (json.has("cancel_event") && !json.isNull("cancel_event")) {
                EventConditionGroup.fromJson(json.getJSONObject("cancel_event"))
            } else {
                null
            }
        )
    }
}

data class ScheduledTriggerConfig(
    val execute_at: String
) {
    companion object {
        fun fromJson(json: JSONObject): ScheduledTriggerConfig = ScheduledTriggerConfig(
            execute_at = json.getString("execute_at")
        )
    }
}

enum class RecurrenceType(val value: String) {
    HOURLY("hourly"),
    DAILY("daily"),
    WEEKLY("weekly");

    companion object {
        fun fromValue(value: String): RecurrenceType =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown RecurrenceType: $value")
    }
}

enum class DayOfWeek(val value: String, val index: Int) {
    SUNDAY("sunday", 0),
    MONDAY("monday", 1),
    TUESDAY("tuesday", 2),
    WEDNESDAY("wednesday", 3),
    THURSDAY("thursday", 4),
    FRIDAY("friday", 5),
    SATURDAY("saturday", 6);

    companion object {
        fun fromValue(value: String): DayOfWeek =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown DayOfWeek: $value")
    }
}

data class TimeOfDay(
    val hour: Int,
    val minute: Int
) {
    companion object {
        fun fromJson(json: JSONObject): TimeOfDay = TimeOfDay(
            hour = json.getInt("hour"),
            minute = json.getInt("minute")
        )
    }
}

data class WeeklyRule(
    val days_of_week: List<DayOfWeek>
) {
    companion object {
        fun fromJson(json: JSONObject): WeeklyRule {
            val daysJson = json.optJSONArray("days_of_week") ?: JSONArray()
            val daysOfWeek = mutableListOf<DayOfWeek>()
            for (index in 0 until daysJson.length()) {
                daysOfWeek.add(DayOfWeek.fromValue(daysJson.getString(index)))
            }
            return WeeklyRule(days_of_week = daysOfWeek)
        }
    }
}

data class RecurrenceRule(
    val type: RecurrenceType,
    val interval: Int,
    val weekly_rule: WeeklyRule? = null,
    val time_of_day: TimeOfDay? = null
) {
    companion object {
        fun fromJson(json: JSONObject): RecurrenceRule = RecurrenceRule(
            type = RecurrenceType.fromValue(json.getString("type")),
            interval = json.getInt("interval"),
            weekly_rule = if (json.has("weekly_rule") && !json.isNull("weekly_rule")) {
                WeeklyRule.fromJson(json.getJSONObject("weekly_rule"))
            } else {
                null
            },
            time_of_day = if (json.has("time_of_day") && !json.isNull("time_of_day")) {
                TimeOfDay.fromJson(json.getJSONObject("time_of_day"))
            } else {
                null
            }
        )
    }
}

data class RecurringTriggerConfig(
    val start_at: String? = null,
    val end_at: String? = null,
    val rule: RecurrenceRule
) {
    companion object {
        fun fromJson(json: JSONObject): RecurringTriggerConfig = RecurringTriggerConfig(
            start_at = if (json.has("start_at") && !json.isNull("start_at")) {
                json.getString("start_at")
            } else {
                null
            },
            end_at = if (json.has("end_at") && !json.isNull("end_at")) {
                json.getString("end_at")
            } else {
                null
            },
            rule = RecurrenceRule.fromJson(json.getJSONObject("rule"))
        )
    }
}

data class EventConditionGroup(
    val connector: String,
    val conditions: List<EventCondition>
) {
    companion object {
        fun fromJson(json: JSONObject): EventConditionGroup {
            val conditionsJson = json.getJSONArray("conditions")
            val conditions = mutableListOf<EventCondition>()
            for (index in 0 until conditionsJson.length()) {
                conditions.add(EventCondition.fromJson(conditionsJson.getJSONObject(index)))
            }
            return EventConditionGroup(
                connector = json.getString("connector"),
                conditions = conditions
            )
        }
    }
}

data class EventCondition(
    val field: String,
    val property_name: String? = null,
    val operator: EventConditionOperator,
    val values: List<String>
) {
    companion object {
        fun fromJson(json: JSONObject): EventCondition {
            val valuesJson = json.getJSONArray("values")
            val values = mutableListOf<String>()
            for (index in 0 until valuesJson.length()) {
                values.add(valuesJson.getString(index))
            }
            return EventCondition(
                field = json.getString("field"),
                property_name = if (json.has("property_name") && !json.isNull("property_name")) {
                    json.getString("property_name")
                } else {
                    null
                },
                operator = EventConditionOperator.fromValue(json.getString("operator")),
                values = values
            )
        }
    }
}

enum class EventConditionOperator(val value: String) {
    EQUAL("equal"),
    NOT_EQUAL("not_equal"),
    GREATER_THAN("greater_than"),
    GREATER_THAN_OR_EQUAL("greater_than_or_equal"),
    LESS_THAN("less_than"),
    LESS_THAN_OR_EQUAL("less_than_or_equal"),
    CONTAINS("contains"),
    NOT_CONTAINS("not_contains"),
    STARTS_WITH("starts_with"),
    ENDS_WITH("ends_with"),
    MATCHES("matches"),
    EXISTS("exists"),
    NOT_EXISTS("not_exists"),
    IN("in"),
    NOT_IN("not_in");

    companion object {
        fun fromValue(value: String): EventConditionOperator =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown EventConditionOperator: $value")
    }
}

enum class ChannelType(val value: String) {
    APP_PUSH("app_push");

    companion object {
        fun fromValue(value: String): ChannelType =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown ChannelType: $value")
    }
}

data class Message(
    val channel_type: ChannelType,
    val content: MessageContent
) {
    companion object {
        fun fromJson(json: JSONObject): Message = Message(
            channel_type = ChannelType.fromValue(json.getString("channel_type")),
            content = MessageContent.fromJson(json.getJSONObject("content"))
        )
    }
}

data class MessageContent(
    val title: String,
    val body: String,
    val image_url: String? = null,
    val landing_url: String? = null
) {
    companion object {
        fun fromJson(json: JSONObject): MessageContent = MessageContent(
            title = json.getString("title"),
            body = json.getString("body"),
            image_url = if (json.has("image_url") && !json.isNull("image_url")) {
                json.getString("image_url")
            } else {
                null
            },
            landing_url = if (json.has("landing_url") && !json.isNull("landing_url")) {
                json.getString("landing_url")
            } else {
                null
            }
        )
    }
}

// ---------------------------------------------------------------------------
// Queued Message (device-local delivery queue)
// ---------------------------------------------------------------------------

enum class QueuedMessageStatus(val value: String) {
    SCHEDULED("scheduled"),
    DELIVERED("delivered"),
    CANCELLED("cancelled");

    companion object {
        fun fromValue(value: String): QueuedMessageStatus =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown QueuedMessageStatus: $value")
    }
}

enum class SkipReason(val value: String) {
    CAMPAIGN_NOT_RUNNING("campaign_not_running"),
    CAMPAIGN_FREQUENCY_CAP_EXCEEDED("campaign_frequency_cap_exceeded"),
    CAMPAIGN_DO_NOT_DISTURB_BLOCKED("campaign_do_not_disturb_blocked"),
    TRIGGER_EVENT_NOT_MATCHED("trigger_event_not_matched"),
    TRIGGER_CANCEL_EVENT_MATCHED("trigger_cancel_event_matched");

    companion object {
        fun fromValue(value: String): SkipReason =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown SkipReason: $value")
    }
}

data class QueuedMessage(
    val id: String,
    val campaign_id: String,
    val channel_type: ChannelType,
    val status: QueuedMessageStatus,
    val content: QueuedMessageContent,
    val trigger_event_id: String? = null,
    val skip_reason: SkipReason? = null,
    val execute_at: String,
    val created_at: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("campaign_id", campaign_id)
        put("channel_type", channel_type.value)
        put("status", status.value)
        put("content", content.toJson())
        trigger_event_id?.let { put("trigger_event_id", it) }
        skip_reason?.let { put("skip_reason", it.value) }
        put("execute_at", execute_at)
        put("created_at", created_at)
    }

    companion object {
        fun fromJson(json: JSONObject): QueuedMessage = QueuedMessage(
            id = json.getString("id"),
            campaign_id = json.getString("campaign_id"),
            channel_type = ChannelType.fromValue(json.getString("channel_type")),
            status = QueuedMessageStatus.fromValue(json.getString("status")),
            content = QueuedMessageContent.fromJson(json.getJSONObject("content")),
            trigger_event_id = if (json.has("trigger_event_id") && !json.isNull("trigger_event_id")) {
                json.getString("trigger_event_id")
            } else {
                null
            },
            skip_reason = if (json.has("skip_reason") && !json.isNull("skip_reason")) {
                SkipReason.fromValue(json.getString("skip_reason"))
            } else {
                null
            },
            execute_at = json.getString("execute_at"),
            created_at = json.getString("created_at")
        )
    }
}

data class QueuedMessageContent(
    val title: String,
    val body: String,
    val image_url: String? = null,
    val landing_url: String? = null
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("title", title)
        put("body", body)
        image_url?.let { put("image_url", it) }
        landing_url?.let { put("landing_url", it) }
    }

    companion object {
        fun fromJson(json: JSONObject): QueuedMessageContent = QueuedMessageContent(
            title = json.getString("title"),
            body = json.getString("body"),
            image_url = if (json.has("image_url") && !json.isNull("image_url")) {
                json.getString("image_url")
            } else {
                null
            },
            landing_url = if (json.has("landing_url") && !json.isNull("landing_url")) {
                json.getString("landing_url")
            } else {
                null
            }
        )
    }
}

// ---------------------------------------------------------------------------
// Event (trigger input)
// ---------------------------------------------------------------------------

enum class EventSourceType(val value: String) {
    APP("app"),
    SYSTEM("system");

    companion object {
        fun fromValue(value: String): EventSourceType =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown EventSourceType: $value")
    }
}

enum class SystemEventName(val value: String) {
    MESSAGE_SCHEDULED("clix.message.scheduled"),
    MESSAGE_DELIVERED("clix.message.delivered"),
    MESSAGE_OPENED("clix.message.opened"),
    MESSAGE_CANCELLED("clix.message.cancelled"),
    MESSAGE_FAILED("clix.message.failed");

    companion object {
        fun fromValue(value: String): SystemEventName =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown SystemEventName: $value")
    }
}

data class Event(
    val id: String,
    val name: String,
    val source_type: EventSourceType,
    val properties: Map<String, Any?>? = null,
    val created_at: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("name", name)
        put("source_type", source_type.value)
        properties?.let { put("properties", JSONObject(it)) }
        put("created_at", created_at)
    }

    companion object {
        fun fromJson(json: JSONObject): Event = Event(
            id = json.getString("id"),
            name = json.getString("name"),
            source_type = EventSourceType.fromValue(json.getString("source_type")),
            properties = if (json.has("properties") && !json.isNull("properties")) {
                jsonObjectToMap(json.getJSONObject("properties"))
            } else {
                null
            },
            created_at = json.getString("created_at")
        )
    }
}

// ---------------------------------------------------------------------------
// SDK Campaign state types
// ---------------------------------------------------------------------------

enum class ClixLogLevel(val value: String, val priority: Int) {
    DEBUG("debug", 0),
    INFO("info", 1),
    WARN("warn", 2),
    ERROR("error", 3),
    NONE("none", 4);

    companion object {
        fun fromValue(value: String): ClixLogLevel =
            entries.firstOrNull { it.value == value }
                ?: throw IllegalArgumentException("Unknown ClixLogLevel: $value")
    }
}

data class TriggerContext(
    val event: Event? = null,
    val trigger: String,
    val now: String? = null
)

data class DecisionTrace(
    val campaign_id: String,
    val action: String,
    val result: String,
    val skip_reason: SkipReason? = null,
    val reason: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("campaign_id", campaign_id)
        put("action", action)
        put("result", result)
        skip_reason?.let { put("skip_reason", it.value) }
        put("reason", reason)
    }

    companion object {
        fun fromJson(json: JSONObject): DecisionTrace = DecisionTrace(
            campaign_id = json.getString("campaign_id"),
            action = json.getString("action"),
            result = json.getString("result"),
            skip_reason = if (json.has("skip_reason") && !json.isNull("skip_reason")) {
                SkipReason.fromValue(json.getString("skip_reason"))
            } else {
                null
            },
            reason = json.getString("reason")
        )
    }
}

data class TriggerResult(
    val evaluated_at: String,
    val trigger: String,
    val traces: List<DecisionTrace>,
    val queued_messages: List<QueuedMessage>
)

data class CampaignStateSnapshot(
    val campaign_states: MutableList<CampaignStateRecord>,
    val queued_messages: MutableList<CampaignQueuedMessage>,
    val trigger_history: MutableList<CampaignTriggerHistory>,
    var updated_at: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("campaign_states", JSONArray().apply {
            campaign_states.forEach { put(it.toJson()) }
        })
        put("queued_messages", JSONArray().apply {
            queued_messages.forEach { put(it.toJson()) }
        })
        put("trigger_history", JSONArray().apply {
            trigger_history.forEach { put(it.toJson()) }
        })
        put("updated_at", updated_at)
    }

    companion object {
        fun fromJson(json: JSONObject): CampaignStateSnapshot {
            val campaignStates = mutableListOf<CampaignStateRecord>()
            val queuedMessages = mutableListOf<CampaignQueuedMessage>()
            val triggerHistory = mutableListOf<CampaignTriggerHistory>()

            val campaignStatesJson = json.optJSONArray("campaign_states") ?: JSONArray()
            for (index in 0 until campaignStatesJson.length()) {
                campaignStates.add(CampaignStateRecord.fromJson(campaignStatesJson.getJSONObject(index)))
            }

            val queuedMessagesJson = json.optJSONArray("queued_messages") ?: JSONArray()
            for (index in 0 until queuedMessagesJson.length()) {
                queuedMessages.add(CampaignQueuedMessage.fromJson(queuedMessagesJson.getJSONObject(index)))
            }

            val triggerHistoryJson = json.optJSONArray("trigger_history") ?: JSONArray()
            for (index in 0 until triggerHistoryJson.length()) {
                triggerHistory.add(CampaignTriggerHistory.fromJson(triggerHistoryJson.getJSONObject(index)))
            }

            return CampaignStateSnapshot(
                campaign_states = campaignStates,
                queued_messages = queuedMessages,
                trigger_history = triggerHistory,
                updated_at = json.optString("updated_at", currentUtcIsoString())
            )
        }
    }
}

data class CampaignStateRecord(
    val campaign_id: String,
    var triggered: Boolean,
    var delivery_count: Int,
    var last_triggered_at: String? = null,
    var recurring_anchor_at: String? = null,
    var recurring_last_scheduled_at: String? = null
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("campaign_id", campaign_id)
        put("triggered", triggered)
        put("delivery_count", delivery_count)
        last_triggered_at?.let { put("last_triggered_at", it) }
        recurring_anchor_at?.let { put("recurring_anchor_at", it) }
        recurring_last_scheduled_at?.let { put("recurring_last_scheduled_at", it) }
    }

    companion object {
        fun fromJson(json: JSONObject): CampaignStateRecord = CampaignStateRecord(
            campaign_id = json.getString("campaign_id"),
            triggered = json.optBoolean("triggered", false),
            delivery_count = json.optInt("delivery_count", 0),
            last_triggered_at = json.optString("last_triggered_at", "").ifBlank { null },
            recurring_anchor_at = json.optString("recurring_anchor_at", "").ifBlank { null },
            recurring_last_scheduled_at = json.optString("recurring_last_scheduled_at", "").ifBlank { null }
        )
    }
}

data class CampaignQueuedMessage(
    val message_id: String,
    val campaign_id: String,
    val execute_at: String,
    val trigger_type: TriggerType,
    val trigger_event_id: String? = null,
    val created_at: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("message_id", message_id)
        put("campaign_id", campaign_id)
        put("execute_at", execute_at)
        put("trigger_type", trigger_type.value)
        trigger_event_id?.let { put("trigger_event_id", it) }
        put("created_at", created_at)
    }

    companion object {
        fun fromJson(json: JSONObject): CampaignQueuedMessage {
            val triggerTypeValue = json.optString("trigger_type", TriggerType.EVENT.value)
            val triggerType = try {
                TriggerType.fromValue(triggerTypeValue)
            } catch (_: Exception) {
                TriggerType.EVENT
            }
            return CampaignQueuedMessage(
                message_id = json.getString("message_id"),
                campaign_id = json.getString("campaign_id"),
                execute_at = json.getString("execute_at"),
                trigger_type = triggerType,
                trigger_event_id = json.optString("trigger_event_id", "").ifBlank { null },
                created_at = json.optString("created_at", json.getString("execute_at"))
            )
        }
    }
}

data class CampaignTriggerHistory(
    val campaign_id: String? = null,
    val triggered_at: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        campaign_id?.let { put("campaign_id", it) }
        put("triggered_at", triggered_at)
    }

    companion object {
        fun fromJson(json: JSONObject): CampaignTriggerHistory = CampaignTriggerHistory(
            campaign_id = json.optString("campaign_id", "").ifBlank { null },
            triggered_at = json.getString("triggered_at")
        )
    }
}

// ---------------------------------------------------------------------------
// SDK configuration and dependency interfaces
// ---------------------------------------------------------------------------

data class ClixConfig(
    val endpoint: String,
    val projectId: String? = null,
    val apiKey: String? = null,
    val logLevel: ClixLogLevel = ClixLogLevel.WARN,
    val extraHeaders: Map<String, String>? = null,
    val sessionTimeoutMs: Int? = null
)

interface ClixClock {
    fun now(): String
}

interface ClixLifecycleStateReader {
    fun getAppState(): String
}

interface ClixLogger {
    fun debug(msg: String, vararg args: Any?)
    fun info(msg: String, vararg args: Any?)
    fun warn(msg: String, vararg args: Any?)
    fun error(msg: String, vararg args: Any?)
}

interface ClixLocalMessageScheduler {
    suspend fun schedule(record: QueuedMessage)
    suspend fun cancel(id: String)
    suspend fun listPending(): List<QueuedMessage>
}

interface CampaignStateRepository {
    suspend fun loadSnapshot(now: String): CampaignStateSnapshot
    suspend fun saveSnapshot(snapshot: CampaignStateSnapshot)
    suspend fun clearCampaignState()
    suspend fun appendEvents(events: List<Event>, maxEntries: Int = 5_000)
    suspend fun loadEvents(limit: Int? = null): List<Event>
    suspend fun clearEvents()
}

// ---------------------------------------------------------------------------
// JSON helpers
// ---------------------------------------------------------------------------

private fun jsonObjectToMap(json: JSONObject): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    for (key in json.keys()) {
        map[key] = jsonValueToKotlin(json.get(key))
    }
    return map
}

private fun jsonValueToKotlin(value: Any?): Any? {
    return when (value) {
        JSONObject.NULL -> null
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> {
            val list = mutableListOf<Any?>()
            for (index in 0 until value.length()) {
                list.add(jsonValueToKotlin(value.get(index)))
            }
            list
        }
        else -> value
    }
}

private fun currentUtcIsoString(): String {
    val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
    formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
    return formatter.format(java.util.Date())
}
