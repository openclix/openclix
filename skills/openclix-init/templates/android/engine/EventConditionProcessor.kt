package ai.openclix.engine

import ai.openclix.models.Event
import ai.openclix.models.EventCondition
import ai.openclix.models.EventConditionGroup
import ai.openclix.models.EventConditionOperator

private fun applyOperator(
    operator: EventConditionOperator,
    lhs: Any?,
    values: List<String>
): Boolean {
    if (lhs == null) {
        return when (operator) {
            EventConditionOperator.NOT_EQUAL,
            EventConditionOperator.NOT_CONTAINS,
            EventConditionOperator.NOT_IN,
            EventConditionOperator.NOT_EXISTS -> true
            EventConditionOperator.EXISTS -> false
            else -> false
        }
    }

    val lhsStr = lhs.toString()
    val firstValue = values.firstOrNull() ?: ""

    return when (operator) {
        EventConditionOperator.EQUAL -> lhsStr == firstValue
        EventConditionOperator.NOT_EQUAL -> lhsStr != firstValue
        EventConditionOperator.GREATER_THAN -> {
            val l = lhsStr.toDoubleOrNull() ?: return false
            val r = firstValue.toDoubleOrNull() ?: return false
            l > r
        }
        EventConditionOperator.GREATER_THAN_OR_EQUAL -> {
            val l = lhsStr.toDoubleOrNull() ?: return false
            val r = firstValue.toDoubleOrNull() ?: return false
            l >= r
        }
        EventConditionOperator.LESS_THAN -> {
            val l = lhsStr.toDoubleOrNull() ?: return false
            val r = firstValue.toDoubleOrNull() ?: return false
            l < r
        }
        EventConditionOperator.LESS_THAN_OR_EQUAL -> {
            val l = lhsStr.toDoubleOrNull() ?: return false
            val r = firstValue.toDoubleOrNull() ?: return false
            l <= r
        }
        EventConditionOperator.CONTAINS -> lhsStr.contains(firstValue)
        EventConditionOperator.NOT_CONTAINS -> !lhsStr.contains(firstValue)
        EventConditionOperator.STARTS_WITH -> lhsStr.startsWith(firstValue)
        EventConditionOperator.ENDS_WITH -> lhsStr.endsWith(firstValue)
        EventConditionOperator.MATCHES -> {
            try {
                Regex(firstValue).containsMatchIn(lhsStr)
            } catch (_: Exception) {
                false
            }
        }
        EventConditionOperator.EXISTS -> true
        EventConditionOperator.NOT_EXISTS -> false
        EventConditionOperator.IN -> values.contains(lhsStr)
        EventConditionOperator.NOT_IN -> !values.contains(lhsStr)
    }
}

class EventConditionProcessor {

    fun process(group: EventConditionGroup, event: Event): Boolean {
        val conditions = group.conditions

        if (conditions.isEmpty()) {
            return group.connector == "and"
        }

        val evaluateRule = { rule: EventCondition ->
            val lhs: Any? = when (rule.field) {
                "name" -> event.name
                "property" -> event.properties?.get(rule.property_name!!)
                else -> null
            }
            applyOperator(rule.operator, lhs, rule.values)
        }

        return if (group.connector == "and") {
            conditions.all(evaluateRule)
        } else {
            conditions.any(evaluateRule)
        }
    }
}
