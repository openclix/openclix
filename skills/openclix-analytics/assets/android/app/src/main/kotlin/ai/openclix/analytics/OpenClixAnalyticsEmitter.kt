package ai.openclix.analytics

enum class OpenClixSourceType {
    APP,
    SYSTEM,
}

enum class OpenClixAnalysisPeriod {
    PRE,
    POST,
}

data class OpenClixAnalyticsEvent(
    val name: String,
    val sourceType: OpenClixSourceType,
    val properties: Map<String, Any?> = emptyMap(),
)

class OpenClixAnalyticsEmitter(
    private val platform: String,
    private val analysisPeriod: OpenClixAnalysisPeriod,
    private val campaignActive: Boolean,
    private val sink: (eventName: String, properties: Map<String, Any?>) -> Unit,
    private val eventNameTransform: ((canonicalName: String) -> String)? = null,
) {
    fun emit(event: OpenClixAnalyticsEvent) {
        val merged = event.properties.toMutableMap()
        merged["openclix_source"] = "openclix"
        merged["openclix_event_name"] = event.name
        merged["openclix_source_type"] = event.sourceType.name.lowercase()
        merged["openclix_platform"] = platform
        merged["openclix_campaign_id"] = event.properties["campaign_id"] as? String
        merged["openclix_queued_message_id"] = event.properties["queued_message_id"] as? String
        merged["openclix_channel_type"] = event.properties["channel_type"] as? String
        merged["openclix_analysis_period"] = analysisPeriod.name.lowercase()
        merged["openclix_campaign_active"] = if (campaignActive) "true" else "false"

        val outboundName = eventNameTransform?.invoke(event.name) ?: event.name
        sink(outboundName, merged)
    }
}

fun normalizeFirebaseEventName(name: String): String {
    val normalized = buildString {
        for (ch in name.lowercase()) {
            append(if (ch.isLetterOrDigit() || ch == '_') ch else '_')
        }
    }

    val withPrefix = if (normalized.firstOrNull()?.isLetter() == true) {
        normalized
    } else {
        "oc_$normalized"
    }

    return withPrefix.take(40)
}
