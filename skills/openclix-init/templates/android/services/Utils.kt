package ai.openclix.services

import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

private val TEMPLATE_VARIABLE_PATTERN = Regex("\\{\\{([a-zA-Z_][a-zA-Z0-9_.]*)\\}\\}")

private fun resolvePath(obj: Map<String, Any?>, path: String): Any? {
    val segments = path.split(".")
    var current: Any? = obj

    for (segment in segments) {
        if (current == null) return null
        if (current !is Map<*, *>) return null
        current = current[segment]
    }

    return current
}

private fun valueToString(value: Any?): String {
    return when (value) {
        null -> ""
        is String -> value
        is Number -> value.toString()
        is Boolean -> if (value) "true" else "false"
        is Map<*, *> -> JSONObject(value).toString()
        is List<*> -> JSONArray(value).toString()
        else -> value.toString()
    }
}

private fun hasPath(obj: Map<String, Any?>, path: String): Boolean {
    val segments = path.split(".")
    var current: Any? = obj

    for ((index, segment) in segments.withIndex()) {
        if (current == null) return false
        if (current !is Map<*, *>) return false
        if (!current.containsKey(segment)) return false
        if (index < segments.size - 1) {
            current = current[segment]
        }
    }

    return true
}

fun renderTemplate(template: String, variables: Map<String, Any?>): String {
    return TEMPLATE_VARIABLE_PATTERN.replace(template) { matchResult ->
        val variableName = matchResult.groupValues[1]
        val resolved = resolvePath(variables, variableName)

        if (resolved == null && !hasPath(variables, variableName)) {
            matchResult.value
        } else {
            valueToString(resolved)
        }
    }
}

fun generateUUID(): String = UUID.randomUUID().toString()
