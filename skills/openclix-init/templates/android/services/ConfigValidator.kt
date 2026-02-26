package ai.openclix.services

import ai.openclix.models.Config
import ai.openclix.models.DayOfWeek
import ai.openclix.models.EventConditionGroup
import ai.openclix.models.EventConditionOperator
import ai.openclix.models.RecurrenceType
import ai.openclix.models.TriggerType
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

data class ValidationIssue(
    val path: String,
    val code: String,
    val message: String
)

data class ValidationResult(
    val valid: Boolean,
    val errors: List<ValidationIssue>,
    val warnings: List<ValidationIssue>
)

private val kebabCasePattern = Regex("^[a-z0-9]+(-[a-z0-9]+)*$")
private val validStatuses = setOf("running", "paused")
private val validChannelTypes = setOf("app_push")
private val validTriggerTypes = TriggerType.entries.map { triggerType -> triggerType.value }.toSet()
private val validRecurrenceTypes = RecurrenceType.entries.map { recurrenceType -> recurrenceType.value }.toSet()
private val validWeekDays = DayOfWeek.entries.map { dayOfWeek -> dayOfWeek.value }.toSet()
private val validEventConnectors = setOf("and", "or")
private val validEventFields = setOf("name", "property")
private val validEventOperators = EventConditionOperator.entries.map { operator -> operator.value }.toSet()

private fun isValidIsoDate(value: String?): Boolean {
    if (value.isNullOrBlank()) return false

    val formats = listOf(
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'Z'"
    )

    for (pattern in formats) {
        try {
            val formatter = SimpleDateFormat(pattern, Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
                isLenient = false
            }
            if (formatter.parse(value) != null) {
                return true
            }
        } catch (_: Exception) {
            continue
        }
    }

    return false
}

private fun parseIsoDateEpoch(value: String?): Long? {
    if (value.isNullOrBlank()) return null

    val formats = listOf(
        "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'Z'"
    )

    for (pattern in formats) {
        try {
            val formatter = SimpleDateFormat(pattern, Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
                isLenient = false
            }
            val parsedDate = formatter.parse(value)
            if (parsedDate != null) {
                return parsedDate.time
            }
        } catch (_: Exception) {
            continue
        }
    }

    return null
}

private fun validateEventConditionGroup(
    group: EventConditionGroup?,
    path: String,
    errors: MutableList<ValidationIssue>,
    warnings: MutableList<ValidationIssue>
) {
    if (group == null) {
        errors.add(
            ValidationIssue(
                path = path,
                code = "INVALID_EVENT_CONDITION_GROUP",
                message = "event condition group must be an object"
            )
        )
        return
    }

    if (!validEventConnectors.contains(group.connector)) {
        errors.add(
            ValidationIssue(
                path = "$path.connector",
                code = "INVALID_EVENT_CONNECTOR",
                message = "connector must be 'and' or 'or'"
            )
        )
    }

    if (group.conditions.isEmpty()) {
        errors.add(
            ValidationIssue(
                path = "$path.conditions",
                code = "MISSING_EVENT_CONDITIONS",
                message = "conditions must contain at least one entry"
            )
        )
        return
    }

    for ((conditionIndex, condition) in group.conditions.withIndex()) {
        val conditionPath = "$path.conditions[$conditionIndex]"

        if (!validEventFields.contains(condition.field)) {
            errors.add(
                ValidationIssue(
                    path = "$conditionPath.field",
                    code = "INVALID_EVENT_FIELD",
                    message = "field must be 'name' or 'property'"
                )
            )
        }

        if (condition.field == "property" && condition.property_name.isNullOrBlank()) {
            errors.add(
                ValidationIssue(
                    path = "$conditionPath.property_name",
                    code = "MISSING_PROPERTY_NAME",
                    message = "field 'property' requires property_name"
                )
            )
        }

        if (condition.field == "name" && !condition.property_name.isNullOrBlank()) {
            warnings.add(
                ValidationIssue(
                    path = "$conditionPath.property_name",
                    code = "UNUSED_PROPERTY_NAME",
                    message = "property_name is ignored when field is 'name'"
                )
            )
        }

        if (!validEventOperators.contains(condition.operator.value)) {
            errors.add(
                ValidationIssue(
                    path = "$conditionPath.operator",
                    code = "INVALID_EVENT_OPERATOR",
                    message = "operator is not supported"
                )
            )
        }

        val operatorRequiresValues =
            condition.operator.value != "exists" && condition.operator.value != "not_exists"

        if (operatorRequiresValues && condition.values.isEmpty()) {
            errors.add(
                ValidationIssue(
                    path = "$conditionPath.values",
                    code = "MISSING_EVENT_VALUES",
                    message = "values must not be empty for this operator"
                )
            )
        }

        if (!operatorRequiresValues && condition.values.isNotEmpty()) {
            warnings.add(
                ValidationIssue(
                    path = "$conditionPath.values",
                    code = "UNUSED_EVENT_VALUES",
                    message = "values are ignored for exists/not_exists operators"
                )
            )
        }
    }
}

fun validateConfig(config: Config): ValidationResult {
    val errors = mutableListOf<ValidationIssue>()
    val warnings = mutableListOf<ValidationIssue>()

    if (config.schema_version != "openclix/config/v1") {
        errors.add(
            ValidationIssue(
                path = ".schema_version",
                code = "INVALID_SCHEMA_VERSION",
                message = "Expected 'openclix/config/v1', got '${config.schema_version}'"
            )
        )
    }

    if (config.config_version.isBlank()) {
        errors.add(
            ValidationIssue(
                path = ".config_version",
                code = "MISSING_CONFIG_VERSION",
                message = "config_version is required and must be a non-empty string"
            )
        )
    }

    if (config.campaigns.isEmpty()) {
        errors.add(
            ValidationIssue(
                path = ".campaigns",
                code = "EMPTY_CAMPAIGNS",
                message = "At least one campaign is required"
            )
        )
    }

    config.settings?.frequency_cap?.let { frequencyCap ->
        if (frequencyCap.max_count < 1) {
            errors.add(
                ValidationIssue(
                    path = ".settings.frequency_cap.max_count",
                    code = "INVALID_FREQUENCY_CAP",
                    message = "frequency_cap.max_count must be >= 1"
                )
            )
        }
        if (frequencyCap.window_seconds < 1) {
            errors.add(
                ValidationIssue(
                    path = ".settings.frequency_cap.window_seconds",
                    code = "INVALID_FREQUENCY_CAP",
                    message = "frequency_cap.window_seconds must be >= 1"
                )
            )
        }
    }

    config.settings?.do_not_disturb?.let { doNotDisturb ->
        if (doNotDisturb.start_hour !in 0..23) {
            errors.add(
                ValidationIssue(
                    path = ".settings.do_not_disturb.start_hour",
                    code = "INVALID_DND_HOURS",
                    message = "do_not_disturb.start_hour must be 0-23"
                )
            )
        }
        if (doNotDisturb.end_hour !in 0..23) {
            errors.add(
                ValidationIssue(
                    path = ".settings.do_not_disturb.end_hour",
                    code = "INVALID_DND_HOURS",
                    message = "do_not_disturb.end_hour must be 0-23"
                )
            )
        }
    }

    for ((campaignId, campaign) in config.campaigns) {
        val basePath = ".campaigns[\"$campaignId\"]"

        if (!kebabCasePattern.matches(campaignId)) {
            errors.add(
                ValidationIssue(
                    path = basePath,
                    code = "INVALID_CAMPAIGN_ID",
                    message = "Campaign ID '$campaignId' must be kebab-case"
                )
            )
        }

        if (campaign.name.isBlank()) {
            errors.add(
                ValidationIssue(
                    path = "$basePath.name",
                    code = "MISSING_CAMPAIGN_NAME",
                    message = "Campaign missing required name"
                )
            )
        }

        if (campaign.type != "campaign") {
            errors.add(
                ValidationIssue(
                    path = "$basePath.type",
                    code = "INVALID_CAMPAIGN_TYPE",
                    message = "Campaign type must be 'campaign'"
                )
            )
        }

        if (campaign.description.isBlank()) {
            warnings.add(
                ValidationIssue(
                    path = "$basePath.description",
                    code = "MISSING_DESCRIPTION",
                    message = "Campaign is missing a description"
                )
            )
        }

        if (!validStatuses.contains(campaign.status.value)) {
            errors.add(
                ValidationIssue(
                    path = "$basePath.status",
                    code = "INVALID_CAMPAIGN_STATUS",
                    message = "Campaign status '${campaign.status.value}' is not valid (expected 'running' or 'paused')"
                )
            )
        }

        if (!validTriggerTypes.contains(campaign.trigger.type.value)) {
            errors.add(
                ValidationIssue(
                    path = "$basePath.trigger.type",
                    code = "INVALID_TRIGGER_TYPE",
                    message = "trigger.type '${campaign.trigger.type.value}' is not valid (expected 'event', 'scheduled', or 'recurring')"
                )
            )
        }

        if (campaign.trigger.type == TriggerType.EVENT) {
            if (campaign.trigger.event == null) {
                errors.add(
                    ValidationIssue(
                        path = "$basePath.trigger.event",
                        code = "MISSING_EVENT_CONFIG",
                        message = "Trigger type 'event' requires trigger.event configuration"
                    )
                )
            } else {
                validateEventConditionGroup(
                    group = campaign.trigger.event.trigger_event,
                    path = "$basePath.trigger.event.trigger_event",
                    errors = errors,
                    warnings = warnings
                )

                if (campaign.trigger.event.cancel_event != null) {
                    validateEventConditionGroup(
                        group = campaign.trigger.event.cancel_event,
                        path = "$basePath.trigger.event.cancel_event",
                        errors = errors,
                        warnings = warnings
                    )
                }

                if (campaign.trigger.event.delay_seconds != null && campaign.trigger.event.delay_seconds < 0) {
                    errors.add(
                        ValidationIssue(
                            path = "$basePath.trigger.event.delay_seconds",
                            code = "INVALID_DELAY_SECONDS",
                            message = "event.delay_seconds must be >= 0"
                        )
                    )
                }
            }
        }

        if (campaign.trigger.type == TriggerType.SCHEDULED) {
            if (campaign.trigger.scheduled == null) {
                errors.add(
                    ValidationIssue(
                        path = "$basePath.trigger.scheduled",
                        code = "MISSING_SCHEDULED_CONFIG",
                        message = "Trigger type 'scheduled' requires trigger.scheduled configuration"
                    )
                )
            } else if (!isValidIsoDate(campaign.trigger.scheduled.execute_at)) {
                errors.add(
                    ValidationIssue(
                        path = "$basePath.trigger.scheduled.execute_at",
                        code = "INVALID_SCHEDULED_EXECUTE_AT",
                        message = "scheduled.execute_at must be a valid ISO 8601 datetime"
                    )
                )
            }
        }

        if (campaign.trigger.type == TriggerType.RECURRING) {
            if (campaign.trigger.recurring == null) {
                errors.add(
                    ValidationIssue(
                        path = "$basePath.trigger.recurring",
                        code = "MISSING_RECURRING_CONFIG",
                        message = "Trigger type 'recurring' requires trigger.recurring configuration"
                    )
                )
            } else {
                val recurring = campaign.trigger.recurring
                val recurrenceRule = recurring.rule

                if (!validRecurrenceTypes.contains(recurrenceRule.type.value)) {
                    errors.add(
                        ValidationIssue(
                            path = "$basePath.trigger.recurring.rule.type",
                            code = "INVALID_RECURRENCE_TYPE",
                            message = "recurring.rule.type '${recurrenceRule.type.value}' is not valid (expected 'hourly', 'daily', or 'weekly')"
                        )
                    )
                }

                if (recurrenceRule.interval < 1) {
                    errors.add(
                        ValidationIssue(
                            path = "$basePath.trigger.recurring.rule.interval",
                            code = "INVALID_RECURRENCE_INTERVAL",
                            message = "recurring.rule.interval must be an integer >= 1"
                        )
                    )
                }

                recurrenceRule.time_of_day?.let { timeOfDay ->
                    if (timeOfDay.hour !in 0..23) {
                        errors.add(
                            ValidationIssue(
                                path = "$basePath.trigger.recurring.rule.time_of_day.hour",
                                code = "INVALID_TIME_OF_DAY_HOUR",
                                message = "time_of_day.hour must be an integer between 0 and 23"
                            )
                        )
                    }
                    if (timeOfDay.minute !in 0..59) {
                        errors.add(
                            ValidationIssue(
                                path = "$basePath.trigger.recurring.rule.time_of_day.minute",
                                code = "INVALID_TIME_OF_DAY_MINUTE",
                                message = "time_of_day.minute must be an integer between 0 and 59"
                            )
                        )
                    }
                }

                if (recurrenceRule.type == RecurrenceType.WEEKLY) {
                    val weekDays = recurrenceRule.weekly_rule?.days_of_week ?: emptyList()
                    if (weekDays.isEmpty()) {
                        errors.add(
                            ValidationIssue(
                                path = "$basePath.trigger.recurring.rule.weekly_rule.days_of_week",
                                code = "MISSING_WEEKLY_DAYS",
                                message = "weekly recurrence requires weekly_rule.days_of_week"
                            )
                        )
                    } else {
                        val hasInvalidWeekDay = weekDays.any { day ->
                            !validWeekDays.contains(day.value)
                        }
                        if (hasInvalidWeekDay) {
                            errors.add(
                                ValidationIssue(
                                    path = "$basePath.trigger.recurring.rule.weekly_rule.days_of_week",
                                    code = "INVALID_WEEKLY_DAY",
                                    message = "weekly_rule.days_of_week must contain valid weekday strings (sunday-saturday)"
                                )
                            )
                        }
                    }
                }

                if (!recurring.start_at.isNullOrBlank() && !isValidIsoDate(recurring.start_at)) {
                    errors.add(
                        ValidationIssue(
                            path = "$basePath.trigger.recurring.start_at",
                            code = "INVALID_RECURRING_START_AT",
                            message = "recurring.start_at must be a valid ISO 8601 datetime"
                        )
                    )
                }

                if (!recurring.end_at.isNullOrBlank() && !isValidIsoDate(recurring.end_at)) {
                    errors.add(
                        ValidationIssue(
                            path = "$basePath.trigger.recurring.end_at",
                            code = "INVALID_RECURRING_END_AT",
                            message = "recurring.end_at must be a valid ISO 8601 datetime"
                        )
                    )
                }

                if (!recurring.start_at.isNullOrBlank() && !recurring.end_at.isNullOrBlank()) {
                    val startAtEpoch = parseIsoDateEpoch(recurring.start_at)
                    val endAtEpoch = parseIsoDateEpoch(recurring.end_at)

                    if (startAtEpoch != null && endAtEpoch != null && endAtEpoch <= startAtEpoch) {
                        errors.add(
                            ValidationIssue(
                                path = "$basePath.trigger.recurring.end_at",
                                code = "INVALID_RECURRING_RANGE",
                                message = "recurring.end_at must be later than recurring.start_at"
                            )
                        )
                    }
                }
            }
        }

        if (!validChannelTypes.contains(campaign.message.channel_type.value)) {
            errors.add(
                ValidationIssue(
                    path = "$basePath.message.channel_type",
                    code = "INVALID_CHANNEL_TYPE",
                    message = "channel_type must be 'app_push'"
                )
            )
        }

        if (campaign.message.content.title.isBlank()) {
            errors.add(
                ValidationIssue(
                    path = "$basePath.message.content.title",
                    code = "MISSING_MESSAGE_TITLE",
                    message = "Message content must have a title"
                )
            )
        }

        if (campaign.message.content.body.isBlank()) {
            errors.add(
                ValidationIssue(
                    path = "$basePath.message.content.body",
                    code = "MISSING_MESSAGE_BODY",
                    message = "Message content must have a body"
                )
            )
        }
    }

    return ValidationResult(
        valid = errors.isEmpty(),
        errors = errors,
        warnings = warnings
    )
}
