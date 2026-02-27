package ai.openclix.store

import android.content.Context
import ai.openclix.models.CampaignQueuedMessage
import ai.openclix.models.CampaignStateRecord
import ai.openclix.models.CampaignStateRepository
import ai.openclix.models.CampaignStateSnapshot
import ai.openclix.models.CampaignTriggerHistory
import ai.openclix.models.Event
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

private const val CAMPAIGN_STATES_FILENAME = "campaign_states.json"
private const val QUEUED_MESSAGES_FILENAME = "queued_messages.json"
private const val TRIGGER_HISTORY_FILENAME = "trigger_history.json"
private const val EVENTS_FILENAME = "events.json"
private const val META_FILENAME = "campaign_state_meta.json"
private const val DEFAULT_MAX_EVENT_LOG_SIZE = 5_000

fun createDefaultCampaignStateSnapshot(now: String): CampaignStateSnapshot {
    return CampaignStateSnapshot(
        campaign_states = mutableListOf(),
        queued_messages = mutableListOf(),
        trigger_history = mutableListOf(),
        updated_at = now
    )
}

class FileCampaignStateRepository(
    context: Context
) : CampaignStateRepository {

    private val lock = Any()
    private val campaignStatesFile: File
    private val queuedMessagesFile: File
    private val triggerHistoryFile: File
    private val eventsFile: File
    private val metadataFile: File

    init {
        val openClixDirectory = File(context.filesDir, "openclix")
        if (!openClixDirectory.exists()) {
            openClixDirectory.mkdirs()
        }

        campaignStatesFile = File(openClixDirectory, CAMPAIGN_STATES_FILENAME)
        queuedMessagesFile = File(openClixDirectory, QUEUED_MESSAGES_FILENAME)
        triggerHistoryFile = File(openClixDirectory, TRIGGER_HISTORY_FILENAME)
        eventsFile = File(openClixDirectory, EVENTS_FILENAME)
        metadataFile = File(openClixDirectory, META_FILENAME)
    }

    override suspend fun loadSnapshot(now: String): CampaignStateSnapshot {
        synchronized(lock) {
            val campaignStates = loadCampaignStateRows()
            val queuedMessages = loadQueuedMessageRows()
            val triggerHistory = loadTriggerHistoryRows()
            val updatedAt = loadUpdatedAt() ?: now

            return CampaignStateSnapshot(
                campaign_states = campaignStates,
                queued_messages = queuedMessages,
                trigger_history = triggerHistory,
                updated_at = updatedAt
            )
        }
    }

    override suspend fun saveSnapshot(snapshot: CampaignStateSnapshot) {
        synchronized(lock) {
            val normalizedSnapshot = normalizeSnapshot(snapshot)

            saveRows(campaignStatesFile, normalizedSnapshot.campaign_states.map { row -> row.toJson() })
            saveRows(queuedMessagesFile, normalizedSnapshot.queued_messages.map { row -> row.toJson() })
            saveRows(triggerHistoryFile, normalizedSnapshot.trigger_history.map { row -> row.toJson() })
            saveUpdatedAt(normalizedSnapshot.updated_at)
        }
    }

    override suspend fun clearCampaignState() {
        synchronized(lock) {
            if (campaignStatesFile.exists()) campaignStatesFile.delete()
            if (queuedMessagesFile.exists()) queuedMessagesFile.delete()
            if (triggerHistoryFile.exists()) triggerHistoryFile.delete()
            if (eventsFile.exists()) eventsFile.delete()
            if (metadataFile.exists()) metadataFile.delete()
        }
    }

    override suspend fun appendEvents(events: List<Event>, maxEntries: Int) {
        if (events.isEmpty()) return

        synchronized(lock) {
            val existingEvents = loadEventRows()
            val mergedById = LinkedHashMap<String, Event>()

            for (event in existingEvents) {
                mergedById[event.id] = event
            }

            for (event in events) {
                if (event.id.isBlank() || event.name.isBlank() || event.created_at.isBlank()) {
                    continue
                }
                mergedById[event.id] = event
            }

            val merged = mergedById.values.sortedBy { event -> event.created_at }
            val cappedSize = if (maxEntries > 0) maxEntries else DEFAULT_MAX_EVENT_LOG_SIZE
            val trimmed = if (merged.size > cappedSize) {
                merged.takeLast(cappedSize)
            } else {
                merged
            }

            saveRows(eventsFile, trimmed.map { event -> event.toJson() })
        }
    }

    override suspend fun loadEvents(limit: Int?): List<Event> {
        synchronized(lock) {
            val events = loadEventRows().sortedBy { event -> event.created_at }
            if (limit == null) return events
            if (limit <= 0) return emptyList()
            if (events.size <= limit) return events

            return events.takeLast(limit)
        }
    }

    override suspend fun clearEvents() {
        synchronized(lock) {
            if (eventsFile.exists()) eventsFile.delete()
        }
    }

    private fun normalizeSnapshot(snapshot: CampaignStateSnapshot): CampaignStateSnapshot {
        return CampaignStateSnapshot(
            campaign_states = snapshot.campaign_states
                .filter { row -> row.campaign_id.isNotBlank() }
                .toMutableList(),
            queued_messages = snapshot.queued_messages
                .filter { row ->
                    row.message_id.isNotBlank() &&
                            row.campaign_id.isNotBlank() &&
                            row.execute_at.isNotBlank()
                }
                .toMutableList(),
            trigger_history = snapshot.trigger_history
                .filter { row -> row.triggered_at.isNotBlank() }
                .toMutableList(),
            updated_at = if (snapshot.updated_at.isNotBlank()) snapshot.updated_at else nowIso8601()
        )
    }

    private fun loadCampaignStateRows(): MutableList<CampaignStateRecord> {
        val rows = mutableListOf<CampaignStateRecord>()
        for (jsonObject in loadRows(campaignStatesFile)) {
            try {
                val row = CampaignStateRecord.fromJson(jsonObject)
                if (row.campaign_id.isNotBlank()) {
                    rows.add(row)
                }
            } catch (_: Exception) {
                continue
            }
        }
        return rows
    }

    private fun loadQueuedMessageRows(): MutableList<CampaignQueuedMessage> {
        val rows = mutableListOf<CampaignQueuedMessage>()
        for (jsonObject in loadRows(queuedMessagesFile)) {
            try {
                val row = CampaignQueuedMessage.fromJson(jsonObject)
                if (row.message_id.isNotBlank() && row.campaign_id.isNotBlank() && row.execute_at.isNotBlank()) {
                    rows.add(row)
                }
            } catch (_: Exception) {
                continue
            }
        }
        return rows
    }

    private fun loadTriggerHistoryRows(): MutableList<CampaignTriggerHistory> {
        val rows = mutableListOf<CampaignTriggerHistory>()
        for (jsonObject in loadRows(triggerHistoryFile)) {
            try {
                val row = CampaignTriggerHistory.fromJson(jsonObject)
                if (row.triggered_at.isNotBlank()) {
                    rows.add(row)
                }
            } catch (_: Exception) {
                continue
            }
        }
        return rows
    }

    private fun loadEventRows(): MutableList<Event> {
        val rows = mutableListOf<Event>()
        for (jsonObject in loadRows(eventsFile)) {
            try {
                val row = Event.fromJson(jsonObject)
                if (row.id.isBlank() || row.name.isBlank() || row.created_at.isBlank()) {
                    continue
                }
                rows.add(row)
            } catch (_: Exception) {
                continue
            }
        }
        return rows
    }

    private fun loadRows(file: File): List<JSONObject> {
        if (!file.exists()) return emptyList()

        return try {
            val content = file.readText(Charsets.UTF_8)
            val jsonArray = JSONArray(content)
            val rows = mutableListOf<JSONObject>()
            for (index in 0 until jsonArray.length()) {
                val entry = jsonArray.opt(index)
                if (entry is JSONObject) {
                    rows.add(entry)
                }
            }
            rows
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun saveRows(file: File, rows: List<JSONObject>) {
        val jsonArray = JSONArray()
        for (row in rows) {
            jsonArray.put(row)
        }

        val temporaryFile = File(file.parentFile, "${file.name}.tmp")
        temporaryFile.writeText(jsonArray.toString(), Charsets.UTF_8)
        temporaryFile.renameTo(file)
    }

    private fun loadUpdatedAt(): String? {
        if (!metadataFile.exists()) return null

        return try {
            val content = metadataFile.readText(Charsets.UTF_8)
            val jsonObject = JSONObject(content)
            jsonObject.optString("updated_at", "").ifBlank { null }
        } catch (_: Exception) {
            null
        }
    }

    private fun saveUpdatedAt(updatedAt: String) {
        val jsonObject = JSONObject().apply {
            put("updated_at", updatedAt)
        }
        val temporaryFile = File(metadataFile.parentFile, "${metadataFile.name}.tmp")
        temporaryFile.writeText(jsonObject.toString(), Charsets.UTF_8)
        temporaryFile.renameTo(metadataFile)
    }

    private fun nowIso8601(): String {
        val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return formatter.format(java.util.Date())
    }
}
