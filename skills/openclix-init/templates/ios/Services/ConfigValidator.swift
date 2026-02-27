import Foundation

public struct ValidationIssue {
    public let path: String
    public let code: String
    public let message: String

    public init(path: String, code: String, message: String) {
        self.path = path
        self.code = code
        self.message = message
    }
}

public struct ValidationResult {
    public let valid: Bool
    public let errors: [ValidationIssue]
    public let warnings: [ValidationIssue]

    public init(valid: Bool, errors: [ValidationIssue], warnings: [ValidationIssue]) {
        self.valid = valid
        self.errors = errors
        self.warnings = warnings
    }
}

private let kebabCaseExpression = try! NSRegularExpression(
    pattern: "^[a-z0-9]+(-[a-z0-9]+)*$"
)
private let maximumMessageTitleLength = 120
private let maximumMessageBodyLength = 500

private func parseIsoDate(_ value: String?) -> Date? {
    guard let value = value, !value.isEmpty else { return nil }

    let internetFormatter = ISO8601DateFormatter()
    internetFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = internetFormatter.date(from: value) {
        return parsed
    }

    return ISO8601DateFormatter().date(from: value)
}

private func isValidIsoDate(_ value: String?) -> Bool {
    return parseIsoDate(value) != nil
}

private func isBlank(_ value: String) -> Bool {
    return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func isValidUri(_ value: String?) -> Bool {
    guard let value, !isBlank(value) else { return false }
    if value.rangeOfCharacter(from: .whitespacesAndNewlines) != nil { return false }

    guard let components = URLComponents(string: value),
          let scheme = components.scheme,
          !scheme.isEmpty else {
        return false
    }

    return true
}

private func isValidUriReference(_ value: String?) -> Bool {
    guard let value, !isBlank(value) else { return false }
    if value.rangeOfCharacter(from: .whitespacesAndNewlines) != nil { return false }
    if isValidUri(value) { return true }

    guard let baseURL = URL(string: "https://openclix.local") else {
        return false
    }
    return URL(string: value, relativeTo: baseURL) != nil
}

private func validateEventConditionGroup(
    _ group: EventConditionGroup,
    path: String,
    errors: inout [ValidationIssue],
    warnings: inout [ValidationIssue]
) {
    if group.conditions.isEmpty {
        errors.append(
            ValidationIssue(
                path: "\(path).conditions",
                code: "MISSING_EVENT_CONDITIONS",
                message: "conditions must contain at least one entry"
            )
        )
        return
    }

    for (conditionIndex, condition) in group.conditions.enumerated() {
        let conditionPath = "\(path).conditions[\(conditionIndex)]"

        if condition.field == .property,
           (condition.property_name == nil || condition.property_name?.isEmpty == true) {
            errors.append(
                ValidationIssue(
                    path: "\(conditionPath).property_name",
                    code: "MISSING_PROPERTY_NAME",
                    message: "field 'property' requires property_name"
                )
            )
        }

        if condition.field == .name,
           let propertyName = condition.property_name,
           !propertyName.isEmpty {
            warnings.append(
                ValidationIssue(
                    path: "\(conditionPath).property_name",
                    code: "UNUSED_PROPERTY_NAME",
                    message: "property_name is ignored when field is 'name'"
                )
            )
        }

        let operatorRequiresValues = condition.operator != .exists && condition.operator != .not_exists
        if operatorRequiresValues && condition.values.isEmpty {
            errors.append(
                ValidationIssue(
                    path: "\(conditionPath).values",
                    code: "MISSING_EVENT_VALUES",
                    message: "values must not be empty for this operator"
                )
            )
        }

        if !operatorRequiresValues && !condition.values.isEmpty {
            warnings.append(
                ValidationIssue(
                    path: "\(conditionPath).values",
                    code: "UNUSED_EVENT_VALUES",
                    message: "values are ignored for exists/not_exists operators"
                )
            )
        }
    }
}

public func validateConfig(_ config: Config) -> ValidationResult {
    var errors: [ValidationIssue] = []
    var warnings: [ValidationIssue] = []
    // TODO: Validate additionalProperties with raw JSON before Codable decoding.

    if config.schema_version != "openclix/config/v1" {
        errors.append(
            ValidationIssue(
                path: ".schema_version",
                code: "INVALID_SCHEMA_VERSION",
                message: "Expected 'openclix/config/v1', got '\(config.schema_version)'"
            )
        )
    }

    if config.config_version.isEmpty {
        errors.append(
            ValidationIssue(
                path: ".config_version",
                code: "MISSING_CONFIG_VERSION",
                message: "config_version is required and must be a non-empty string"
            )
        )
    }

    if config.campaigns.isEmpty {
        errors.append(
            ValidationIssue(
                path: ".campaigns",
                code: "EMPTY_CAMPAIGNS",
                message: "At least one campaign is required"
            )
        )
    }

    if let frequencyCap = config.settings?.frequency_cap {
        if frequencyCap.max_count < 1 {
            errors.append(
                ValidationIssue(
                    path: ".settings.frequency_cap.max_count",
                    code: "INVALID_FREQUENCY_CAP",
                    message: "frequency_cap.max_count must be an integer >= 1"
                )
            )
        }

        if frequencyCap.window_seconds < 1 {
            errors.append(
                ValidationIssue(
                    path: ".settings.frequency_cap.window_seconds",
                    code: "INVALID_FREQUENCY_CAP",
                    message: "frequency_cap.window_seconds must be an integer >= 1"
                )
            )
        }
    }

    if let doNotDisturb = config.settings?.do_not_disturb {
        if doNotDisturb.start_hour < 0 || doNotDisturb.start_hour > 23 {
            errors.append(
                ValidationIssue(
                    path: ".settings.do_not_disturb.start_hour",
                    code: "INVALID_DND_HOURS",
                    message: "do_not_disturb.start_hour must be an integer between 0 and 23"
                )
            )
        }

        if doNotDisturb.end_hour < 0 || doNotDisturb.end_hour > 23 {
            errors.append(
                ValidationIssue(
                    path: ".settings.do_not_disturb.end_hour",
                    code: "INVALID_DND_HOURS",
                    message: "do_not_disturb.end_hour must be an integer between 0 and 23"
                )
            )
        }
    }

    for (campaignId, campaign) in config.campaigns {
        let basePath = ".campaigns[\"\(campaignId)\"]"

        let campaignIdentifierRange = NSRange(campaignId.startIndex..., in: campaignId)
        if kebabCaseExpression.firstMatch(in: campaignId, range: campaignIdentifierRange) == nil {
            errors.append(
                ValidationIssue(
                    path: basePath,
                    code: "INVALID_CAMPAIGN_ID",
                    message: "Campaign ID '\(campaignId)' must be kebab-case"
                )
            )
        }

        if campaign.name.isEmpty {
            errors.append(
                ValidationIssue(
                    path: "\(basePath).name",
                    code: "MISSING_CAMPAIGN_NAME",
                    message: "Campaign missing required name"
                )
            )
        }

        if campaign.type != "campaign" {
            errors.append(
                ValidationIssue(
                    path: "\(basePath).type",
                    code: "INVALID_CAMPAIGN_TYPE",
                    message: "Campaign type must be 'campaign'"
                )
            )
        }

        if isBlank(campaign.description) {
            errors.append(
                ValidationIssue(
                    path: "\(basePath).description",
                    code: "MISSING_DESCRIPTION",
                    message: "Campaign description is required"
                )
            )
        }

        switch campaign.trigger.type {
        case .event:
            guard let eventTrigger = campaign.trigger.event else {
                errors.append(
                    ValidationIssue(
                        path: "\(basePath).trigger.event",
                        code: "MISSING_EVENT_CONFIG",
                        message: "Trigger type 'event' requires trigger.event configuration"
                    )
                )
                break
            }

            validateEventConditionGroup(
                eventTrigger.trigger_event,
                path: "\(basePath).trigger.event.trigger_event",
                errors: &errors,
                warnings: &warnings
            )

            if let cancelEvent = eventTrigger.cancel_event {
                validateEventConditionGroup(
                    cancelEvent,
                    path: "\(basePath).trigger.event.cancel_event",
                    errors: &errors,
                    warnings: &warnings
                )
            }

            if let delaySeconds = eventTrigger.delay_seconds,
               delaySeconds < 0 {
                errors.append(
                    ValidationIssue(
                        path: "\(basePath).trigger.event.delay_seconds",
                        code: "INVALID_DELAY_SECONDS",
                        message: "event.delay_seconds must be an integer >= 0"
                    )
                )
            }

        case .scheduled:
            guard let scheduledTrigger = campaign.trigger.scheduled else {
                errors.append(
                    ValidationIssue(
                        path: "\(basePath).trigger.scheduled",
                        code: "MISSING_SCHEDULED_CONFIG",
                        message: "Trigger type 'scheduled' requires trigger.scheduled configuration"
                    )
                )
                break
            }

            if !isValidIsoDate(scheduledTrigger.execute_at) {
                errors.append(
                    ValidationIssue(
                        path: "\(basePath).trigger.scheduled.execute_at",
                        code: "INVALID_SCHEDULED_EXECUTE_AT",
                        message: "scheduled.execute_at must be a valid ISO 8601 datetime"
                    )
                )
            }

        case .recurring:
            guard let recurringTrigger = campaign.trigger.recurring else {
                errors.append(
                    ValidationIssue(
                        path: "\(basePath).trigger.recurring",
                        code: "MISSING_RECURRING_CONFIG",
                        message: "Trigger type 'recurring' requires trigger.recurring configuration"
                    )
                )
                break
            }

            if recurringTrigger.rule.interval < 1 {
                errors.append(
                    ValidationIssue(
                        path: "\(basePath).trigger.recurring.rule.interval",
                        code: "INVALID_RECURRING_INTERVAL",
                        message: "recurring.rule.interval must be an integer >= 1"
                    )
                )
            }

            if let timeOfDay = recurringTrigger.rule.time_of_day {
                if timeOfDay.hour < 0 || timeOfDay.hour > 23 {
                    errors.append(
                        ValidationIssue(
                            path: "\(basePath).trigger.recurring.rule.time_of_day.hour",
                            code: "INVALID_TIME_OF_DAY_HOUR",
                            message: "time_of_day.hour must be an integer between 0 and 23"
                        )
                    )
                }

                if timeOfDay.minute < 0 || timeOfDay.minute > 59 {
                    errors.append(
                        ValidationIssue(
                            path: "\(basePath).trigger.recurring.rule.time_of_day.minute",
                            code: "INVALID_TIME_OF_DAY_MINUTE",
                            message: "time_of_day.minute must be an integer between 0 and 59"
                        )
                    )
                }
            }

            if recurringTrigger.rule.type == .weekly {
                let days = recurringTrigger.rule.weekly_rule?.days_of_week ?? []
                if days.isEmpty {
                    errors.append(
                        ValidationIssue(
                            path: "\(basePath).trigger.recurring.rule.weekly_rule.days_of_week",
                            code: "MISSING_WEEKLY_DAYS",
                            message: "weekly recurrence requires weekly_rule.days_of_week"
                        )
                    )
                }
            }

            if recurringTrigger.start_at != nil && !isValidIsoDate(recurringTrigger.start_at) {
                errors.append(
                    ValidationIssue(
                        path: "\(basePath).trigger.recurring.start_at",
                        code: "INVALID_RECURRING_START_AT",
                        message: "recurring.start_at must be a valid ISO 8601 datetime"
                    )
                )
            }

            if recurringTrigger.end_at != nil && !isValidIsoDate(recurringTrigger.end_at) {
                errors.append(
                    ValidationIssue(
                        path: "\(basePath).trigger.recurring.end_at",
                        code: "INVALID_RECURRING_END_AT",
                        message: "recurring.end_at must be a valid ISO 8601 datetime"
                    )
                )
            }

            if let startDate = parseIsoDate(recurringTrigger.start_at),
               let endDate = parseIsoDate(recurringTrigger.end_at),
               endDate <= startDate {
                errors.append(
                    ValidationIssue(
                        path: "\(basePath).trigger.recurring.end_at",
                        code: "INVALID_RECURRING_RANGE",
                        message: "recurring.end_at must be later than recurring.start_at"
                    )
                )
            }
        }

        if campaign.message.channel_type != .app_push {
            errors.append(
                ValidationIssue(
                    path: "\(basePath).message.channel_type",
                    code: "INVALID_CHANNEL_TYPE",
                    message: "channel_type must be 'app_push'"
                )
            )
        }

        if isBlank(campaign.message.content.title) {
            errors.append(
                ValidationIssue(
                    path: "\(basePath).message.content.title",
                    code: "MISSING_MESSAGE_TITLE",
                    message: "Message content must have a title"
                )
            )
        } else if campaign.message.content.title.count > maximumMessageTitleLength {
            errors.append(
                ValidationIssue(
                    path: "\(basePath).message.content.title",
                    code: "INVALID_MESSAGE_TITLE_LENGTH",
                    message: "title must be \(maximumMessageTitleLength) characters or less"
                )
            )
        }

        if isBlank(campaign.message.content.body) {
            errors.append(
                ValidationIssue(
                    path: "\(basePath).message.content.body",
                    code: "MISSING_MESSAGE_BODY",
                    message: "Message content must have a body"
                )
            )
        } else if campaign.message.content.body.count > maximumMessageBodyLength {
            errors.append(
                ValidationIssue(
                    path: "\(basePath).message.content.body",
                    code: "INVALID_MESSAGE_BODY_LENGTH",
                    message: "body must be \(maximumMessageBodyLength) characters or less"
                )
            )
        }

        if campaign.message.content.image_url != nil
            && !isValidUri(campaign.message.content.image_url) {
            errors.append(
                ValidationIssue(
                    path: "\(basePath).message.content.image_url",
                    code: "INVALID_IMAGE_URL",
                    message: "image_url must be a valid URI"
                )
            )
        }

        if campaign.message.content.landing_url != nil
            && !isValidUriReference(campaign.message.content.landing_url) {
            errors.append(
                ValidationIssue(
                    path: "\(basePath).message.content.landing_url",
                    code: "INVALID_LANDING_URL",
                    message: "landing_url must be a valid URI reference"
                )
            )
        }
    }

    return ValidationResult(valid: errors.isEmpty, errors: errors, warnings: warnings)
}
