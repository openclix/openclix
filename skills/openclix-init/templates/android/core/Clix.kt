package ai.openclix.core

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import ai.openclix.engine.TriggerService
import ai.openclix.engine.TriggerServiceDependencies
import ai.openclix.models.CampaignStateRepository
import ai.openclix.models.ClixClock
import ai.openclix.models.ClixConfig
import ai.openclix.models.ClixLifecycleStateReader
import ai.openclix.models.ClixLocalMessageScheduler
import ai.openclix.models.ClixLogLevel
import ai.openclix.models.ClixLogger
import ai.openclix.models.Event
import ai.openclix.models.EventSourceType
import ai.openclix.models.TriggerContext
import ai.openclix.models.TriggerResult
import ai.openclix.services.loadConfig
import ai.openclix.services.validateConfig
import java.util.UUID

private const val DEFAULT_CONFIG_TIMEOUT_MILLISECONDS = 10_000

object Clix {

    private var config: ClixConfig? = null
    private var triggerService: TriggerService? = null

    @Volatile
    private var initialized: Boolean = false

    private var campaignStateRepository: CampaignStateRepository? = null
    private var messageScheduler: ClixLocalMessageScheduler? = null
    private var clock: ClixClock? = null
    private var lifecycleStateReader: MutableLifecycleStateReader? = null
    private var logger: DefaultLogger? = null

    @JvmStatic
    suspend fun initialize(
        config: ClixConfig,
        campaignStateRepository: CampaignStateRepository,
        messageScheduler: ClixLocalMessageScheduler,
        clock: ClixClock? = null,
        logger: ClixLogger? = null
    ) {
        if (initialized) {
            throw IllegalStateException(
                "Clix is already initialized. Call Clix.reset() before re-initializing."
            )
        }

        this.config = config
        this.campaignStateRepository = campaignStateRepository
        this.messageScheduler = messageScheduler
        this.clock = clock ?: DefaultClock()

        val defaultLogger = if (logger != null) {
            DefaultLogger(config.logLevel).also { createdLogger ->
                createdLogger.delegate = logger
            }
        } else {
            DefaultLogger(config.logLevel)
        }
        this.logger = defaultLogger

        val defaultLifecycleStateReader = MutableLifecycleStateReader()
        lifecycleStateReader = defaultLifecycleStateReader

        triggerService = TriggerService(createTriggerServiceDependencies())

        defaultLogger.info("Initializing OpenClix SDK...")

        val endpoint = config.endpoint
        val isRemoteEndpoint = endpoint.startsWith("http://") || endpoint.startsWith("https://")

        if (isRemoteEndpoint) {
            try {
                val requestHeaders = mutableMapOf<String, String>()
                config.extraHeaders?.let { requestHeaders.putAll(it) }
                config.projectId?.let { requestHeaders["x-openclix-project-id"] = it }
                config.apiKey?.let { requestHeaders["x-openclix-api-key"] = it }

                val loadedConfig = loadConfig(
                    endpoint = endpoint,
                    extraHeaders = if (requestHeaders.isNotEmpty()) requestHeaders else null,
                    timeoutMs = config.sessionTimeoutMs ?: DEFAULT_CONFIG_TIMEOUT_MILLISECONDS
                )

                if (loadedConfig != null) {
                    val validationResult = validateConfig(loadedConfig)

                    if (validationResult.valid) {
                        for (warning in validationResult.warnings) {
                            defaultLogger.warn("Config validation warning [${warning.code}]: ${warning.message}")
                        }

                        triggerService?.replaceConfig(loadedConfig)

                        try {
                            evaluate("app_boot")
                        } catch (evaluationError: Exception) {
                            defaultLogger.warn(
                                "Initial app_boot evaluation failed:",
                                evaluationError.message ?: evaluationError.toString()
                            )
                        }

                        defaultLogger.info(
                            "Config loaded successfully (version: ${loadedConfig.config_version}, campaigns: ${loadedConfig.campaigns.size})"
                        )
                    } else {
                        for (error in validationResult.errors) {
                            defaultLogger.error("Config validation error [${error.code}]: ${error.message}")
                        }
                        defaultLogger.warn("Config validation failed. SDK initialized without campaign config.")
                    }
                }
            } catch (loadError: Exception) {
                defaultLogger.warn(
                    "Failed to load config from endpoint. SDK initialized without campaign config. " +
                            "Use ClixCampaignManager.replaceConfig() to set config manually.",
                    loadError.message ?: loadError.toString()
                )
            }
        } else {
            defaultLogger.info(
                "Non-HTTP endpoint provided. Use ClixCampaignManager.replaceConfig() to set campaign config."
            )
        }

        initialized = true
        defaultLogger.info("OpenClix SDK initialized successfully.")
    }

    @JvmStatic
    suspend fun trackEvent(name: String, properties: Map<String, Any?>? = null) {
        assertInitialized()

        val event = Event(
            id = UUID.randomUUID().toString(),
            name = name,
            source_type = EventSourceType.APP,
            properties = properties,
            created_at = clock!!.now()
        )

        logger?.debug("Event tracked (not persisted): $name")

        try {
            evaluate("event_tracked", event)
        } catch (evaluationError: Exception) {
            logger?.warn(
                "Evaluation after event '$name' failed:",
                evaluationError.message ?: evaluationError.toString()
            )
        }
    }

    @JvmStatic
    suspend fun reset() {
        val activeLogger = logger

        campaignStateRepository?.let { repository ->
            try {
                repository.clearCampaignState()
            } catch (error: Exception) {
                activeLogger?.warn(
                    "Failed to clear campaign state during reset:",
                    error.message ?: error.toString()
                )
            }
        }

        messageScheduler?.let { scheduler ->
            try {
                val pendingMessages = scheduler.listPending()
                for (pendingMessage in pendingMessages) {
                    scheduler.cancel(pendingMessage.id)
                }
            } catch (error: Exception) {
                activeLogger?.warn(
                    "Failed to clear scheduled messages during reset:",
                    error.message ?: error.toString()
                )
            }
        }

        config = null
        triggerService = null
        initialized = false
        campaignStateRepository = null
        messageScheduler = null
        clock = null
        lifecycleStateReader = null
        logger = null

        activeLogger?.info("OpenClix SDK reset complete.")
    }

    @JvmStatic
    fun setLogLevel(level: ClixLogLevel) {
        logger?.level = level
    }

    @JvmStatic
    fun handleAppForeground() {
        if (!initialized) return

        lifecycleStateReader?.setState("foreground")
        logger?.debug("App entered foreground")

        @Suppress("OPT_IN_USAGE")
        GlobalScope.launch(Dispatchers.Default) {
            try {
                evaluate("app_foreground")
            } catch (evaluationError: Exception) {
                logger?.warn(
                    "app_foreground evaluation failed:",
                    evaluationError.message ?: evaluationError.toString()
                )
            }
        }
    }

    internal fun getTriggerServiceInternal(): TriggerService? = triggerService

    internal fun getClockInternal(): ClixClock? = clock

    internal fun getLoggerInternal(): ClixLogger? = logger

    internal fun getCampaignStateRepositoryInternal(): CampaignStateRepository? = campaignStateRepository

    internal fun getMessageSchedulerInternal(): ClixLocalMessageScheduler? = messageScheduler

    internal fun isInitializedInternal(): Boolean = initialized

    private fun assertInitialized() {
        if (!initialized) {
            throw IllegalStateException(
                "Clix is not initialized. Call Clix.initialize() before using the SDK."
            )
        }
    }

    private fun createTriggerServiceDependencies(): TriggerServiceDependencies {
        return TriggerServiceDependencies(
            campaignStateRepository = campaignStateRepository!!,
            scheduler = messageScheduler!!,
            clock = clock!!,
            logger = logger!!
        )
    }

    internal suspend fun evaluate(
        trigger: String,
        event: Event? = null
    ): TriggerResult? {
        val activeTriggerService = triggerService ?: return null
        return activeTriggerService.trigger(
            TriggerContext(
                trigger = trigger,
                event = event,
                now = clock?.now()
            )
        )
    }
}

private class DefaultClock : ClixClock {
    override fun now(): String {
        val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return formatter.format(java.util.Date())
    }
}

internal class MutableLifecycleStateReader : ClixLifecycleStateReader {
    @Volatile
    private var appState: String = "foreground"

    override fun getAppState(): String = appState

    fun setState(nextState: String) {
        appState = nextState
    }
}

internal class DefaultLogger(
    @Volatile var level: ClixLogLevel
) : ClixLogger {
    var delegate: ClixLogger? = null

    private val logTag = "OpenClix"

    override fun debug(msg: String, vararg args: Any?) {
        if (level.priority <= ClixLogLevel.DEBUG.priority) {
            delegate?.debug(msg, *args) ?: android.util.Log.d(logTag, formatMessage(msg, args))
        }
    }

    override fun info(msg: String, vararg args: Any?) {
        if (level.priority <= ClixLogLevel.INFO.priority) {
            delegate?.info(msg, *args) ?: android.util.Log.i(logTag, formatMessage(msg, args))
        }
    }

    override fun warn(msg: String, vararg args: Any?) {
        if (level.priority <= ClixLogLevel.WARN.priority) {
            delegate?.warn(msg, *args) ?: android.util.Log.w(logTag, formatMessage(msg, args))
        }
    }

    override fun error(msg: String, vararg args: Any?) {
        if (level.priority <= ClixLogLevel.ERROR.priority) {
            delegate?.error(msg, *args) ?: android.util.Log.e(logTag, formatMessage(msg, args))
        }
    }

    private fun formatMessage(message: String, args: Array<out Any?>): String {
        return if (args.isEmpty()) message else "$message ${args.joinToString(" ")}"
    }
}
