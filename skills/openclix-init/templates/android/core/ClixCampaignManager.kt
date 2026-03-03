package ai.openclix.core

import ai.openclix.models.CampaignStateSnapshot
import ai.openclix.models.Config
import ai.openclix.models.Event
import ai.openclix.models.QueuedMessage
import ai.openclix.models.TriggerContext
import ai.openclix.models.TriggerResult
import ai.openclix.services.validateConfig
import ai.openclix.store.createDefaultCampaignStateSnapshot

private fun createDefaultSnapshot(): CampaignStateSnapshot {
    return createDefaultCampaignStateSnapshot(
        java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.format(java.util.Date())
    )
}

private fun assertInitialized() {
    if (!OpenClix.isInitializedInternal()) {
        throw IllegalStateException(
            "OpenClix is not initialized. Call OpenClix.initialize() before using OpenClixCampaignManager."
        )
    }
}

object OpenClixCampaignManager {

    @JvmStatic
    suspend fun replaceConfig(config: Config): TriggerResult? {
        assertInitialized()

        val logger = OpenClix.getLoggerInternal()
        val triggerService = OpenClix.getTriggerServiceInternal()

        if (triggerService == null) {
            logger?.error("Cannot replace config: trigger service is not available.")
            return null
        }

        val validationResult = validateConfig(config)
        if (!validationResult.valid) {
            for (error in validationResult.errors) {
                logger?.error("Config validation error [${error.code}]: ${error.message}")
            }
            logger?.warn("Config replacement rejected due to validation errors.")
            return null
        }

        for (warning in validationResult.warnings) {
            logger?.warn("Config validation warning [${warning.code}]: ${warning.message}")
        }

        triggerService.replaceConfig(config)
        logger?.info("Config replaced (version: ${config.config_version}, campaigns: ${config.campaigns.size})")

        val triggerContext = TriggerContext(
            trigger = "config_replaced",
            now = OpenClix.getClockInternal()?.now()
        )

        return try {
            triggerService.trigger(triggerContext)
        } catch (error: Exception) {
            logger?.error(
                "Evaluation after config replacement failed:",
                error.message ?: error.toString()
            )
            null
        }
    }

    @JvmStatic
    fun getConfig(): Config? {
        assertInitialized()
        return OpenClix.getTriggerServiceInternal()?.getConfig()
    }

    @JvmStatic
    suspend fun getSnapshot(): CampaignStateSnapshot {
        assertInitialized()

        val repository = OpenClix.getCampaignStateRepositoryInternal() ?: return createDefaultSnapshot()

        return try {
            repository.loadSnapshot(
                java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
                    timeZone = java.util.TimeZone.getTimeZone("UTC")
                }.format(java.util.Date())
            )
        } catch (error: Exception) {
            OpenClix.getLoggerInternal()?.warn(
                "Failed to load campaign state snapshot:",
                error.message ?: error.toString()
            )
            createDefaultSnapshot()
        }
    }

    @JvmStatic
    suspend fun getScheduledMessages(
        campaignId: String? = null,
        status: String? = null
    ): List<QueuedMessage> {
        assertInitialized()

        val scheduler = OpenClix.getMessageSchedulerInternal() ?: return emptyList()

        val pendingMessages = try {
            scheduler.listPending()
        } catch (error: Exception) {
            OpenClix.getLoggerInternal()?.error(
                "Failed to list pending messages:",
                error.message ?: error.toString()
            )
            return emptyList()
        }

        return pendingMessages.filter { queuedMessage ->
            val campaignMatches = campaignId == null || queuedMessage.campaign_id == campaignId
            val statusMatches = status == null || queuedMessage.status.value == status
            campaignMatches && statusMatches
        }
    }

    @JvmStatic
    suspend fun getEventLog(limit: Int? = null): List<Event> {
        assertInitialized()

        val repository = OpenClix.getCampaignStateRepositoryInternal() ?: return emptyList()

        return try {
            repository.loadEvents(limit)
        } catch (error: Exception) {
            OpenClix.getLoggerInternal()?.error(
                "Failed to load event log:",
                error.message ?: error.toString()
            )
            emptyList()
        }
    }
}
