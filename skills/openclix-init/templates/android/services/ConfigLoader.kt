package ai.openclix.services

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import ai.openclix.models.Config
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

private const val DEFAULT_TIMEOUT_MS = 10_000

suspend fun loadConfig(
    endpoint: String,
    extraHeaders: Map<String, String>? = null,
    timeoutMs: Int = DEFAULT_TIMEOUT_MS
): Config? = withContext(Dispatchers.IO) {
    if (!endpoint.startsWith("http://") && !endpoint.startsWith("https://")) {
        throw IllegalArgumentException(
            "Local file paths are not supported by ConfigLoader on Android. " +
                    "Use replaceConfig() with a bundled config object instead. " +
                    "Received endpoint: \"$endpoint\""
        )
    }

    val url = URL(endpoint)
    val connection = url.openConnection() as HttpURLConnection

    try {
        connection.requestMethod = "GET"
        connection.connectTimeout = timeoutMs
        connection.readTimeout = timeoutMs
        connection.setRequestProperty("Accept", "application/json")

        extraHeaders?.forEach { (key, value) ->
            connection.setRequestProperty(key, value)
        }

        connection.connect()

        val responseCode = connection.responseCode

        if (responseCode < 200 || responseCode >= 300) {
            throw RuntimeException(
                "Config fetch returned HTTP $responseCode for endpoint: \"$endpoint\""
            )
        }

        val reader = BufferedReader(InputStreamReader(connection.inputStream, "UTF-8"))
        val responseBody = reader.use { it.readText() }

        val jsonObject: JSONObject
        try {
            jsonObject = JSONObject(responseBody)
        } catch (e: Exception) {
            throw RuntimeException(
                "Failed to parse config JSON from endpoint \"$endpoint\": ${e.message}",
                e
            )
        }

        val config: Config
        try {
            config = Config.fromJson(jsonObject)
        } catch (e: Exception) {
            throw RuntimeException(
                "Failed to decode config from endpoint \"$endpoint\": ${e.message}",
                e
            )
        }

        config
    } finally {
        connection.disconnect()
    }
}
