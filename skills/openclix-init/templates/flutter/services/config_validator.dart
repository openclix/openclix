import '../models/clix_types.dart';

class ValidationIssue {
  final String path;
  final String code;
  final String message;

  ValidationIssue({
    required this.path,
    required this.code,
    required this.message,
  });
}

class ValidationResult {
  final bool valid;
  final List<ValidationIssue> errors;
  final List<ValidationIssue> warnings;

  ValidationResult({
    required this.valid,
    required this.errors,
    required this.warnings,
  });
}

final RegExp kebabCasePattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

final Set<String> validCampaignStatuses = CampaignStatus.values
    .map((status) => status.value)
    .toSet();

final Set<String> validChannelTypes = ChannelType.values
    .map((channelType) => channelType.value)
    .toSet();

final Set<String> validTriggerTypes = TriggerType.values
    .map((triggerType) => triggerType.value)
    .toSet();

final Set<String> validRecurrenceTypes = RecurrenceType.values
    .map((recurrenceType) => recurrenceType.value)
    .toSet();

final Set<String> validWeekDays = DayOfWeek.values
    .map((dayOfWeek) => dayOfWeek.value)
    .toSet();

const Set<String> validEventConnectors = {'and', 'or'};
const Set<String> validEventFields = {'name', 'property'};

final Set<String> validEventOperators = EventConditionOperator.values
    .map((operator) => operator.value)
    .toSet();

const int maximumMessageTitleLength = 120;
const int maximumMessageBodyLength = 500;

// TODO: Additional-property enforcement is skipped because this validator
// receives typed Config models instead of the raw JSON object graph.

bool isValidIsoDateString(String? value) {
  if (value == null || value.isEmpty) return false;

  try {
    DateTime.parse(value);
    return true;
  } catch (_) {
    return false;
  }
}

bool isNonEmptyStringValue(Object? value) {
  return value is String && value.isNotEmpty;
}

bool isValidUri(String? value) {
  if (value == null || value.isEmpty) return false;
  if (RegExp(r'\s').hasMatch(value)) return false;

  final parsed = Uri.tryParse(value);
  return parsed != null && parsed.scheme.isNotEmpty;
}

bool isValidUriReference(String? value) {
  if (value == null || value.isEmpty) return false;
  if (RegExp(r'\s').hasMatch(value)) return false;

  final parsed = Uri.tryParse(value);
  return parsed != null;
}

void validateEventConditionGroup(
  EventConditionGroup? group,
  String path,
  List<ValidationIssue> errors,
  List<ValidationIssue> warnings,
) {
  if (group == null) {
    errors.add(
      ValidationIssue(
        path: path,
        code: 'INVALID_EVENT_CONDITION_GROUP',
        message: 'event condition group must be an object',
      ),
    );
    return;
  }

  if (!validEventConnectors.contains(group.connector)) {
    errors.add(
      ValidationIssue(
        path: '$path.connector',
        code: 'INVALID_EVENT_CONNECTOR',
        message: "connector must be 'and' or 'or'",
      ),
    );
  }

  if (group.conditions.isEmpty) {
    errors.add(
      ValidationIssue(
        path: '$path.conditions',
        code: 'MISSING_EVENT_CONDITIONS',
        message: 'conditions must contain at least one entry',
      ),
    );
    return;
  }

  for (var index = 0; index < group.conditions.length; index += 1) {
    final condition = group.conditions[index];
    final conditionPath = '$path.conditions[$index]';

    if (!validEventFields.contains(condition.field)) {
      errors.add(
        ValidationIssue(
          path: '$conditionPath.field',
          code: 'INVALID_EVENT_FIELD',
          message: "field must be 'name' or 'property'",
        ),
      );
    }

    if (condition.field == 'property' &&
        !isNonEmptyStringValue(condition.propertyName)) {
      errors.add(
        ValidationIssue(
          path: '$conditionPath.property_name',
          code: 'MISSING_PROPERTY_NAME',
          message: "field 'property' requires property_name",
        ),
      );
    }

    if (condition.field == 'name' &&
        isNonEmptyStringValue(condition.propertyName)) {
      warnings.add(
        ValidationIssue(
          path: '$conditionPath.property_name',
          code: 'UNUSED_PROPERTY_NAME',
          message: "property_name is ignored when field is 'name'",
        ),
      );
    }

    if (!validEventOperators.contains(condition.operator.value)) {
      errors.add(
        ValidationIssue(
          path: '$conditionPath.operator',
          code: 'INVALID_EVENT_OPERATOR',
          message: 'operator is not supported',
        ),
      );
    }

    final requiresValues =
        condition.operator != EventConditionOperator.exists &&
        condition.operator != EventConditionOperator.notExists;

    if (requiresValues && condition.values.isEmpty) {
      errors.add(
        ValidationIssue(
          path: '$conditionPath.values',
          code: 'MISSING_EVENT_VALUES',
          message: 'values must not be empty for this operator',
        ),
      );
    }

    if (!requiresValues && condition.values.isNotEmpty) {
      warnings.add(
        ValidationIssue(
          path: '$conditionPath.values',
          code: 'UNUSED_EVENT_VALUES',
          message: 'values are ignored for exists/not_exists operators',
        ),
      );
    }
  }
}

ValidationResult validateConfig(Config config) {
  final errors = <ValidationIssue>[];
  final warnings = <ValidationIssue>[];

  if (config.schemaVersion != 'openclix/config/v1') {
    errors.add(
      ValidationIssue(
        path: '.schema_version',
        code: 'INVALID_SCHEMA_VERSION',
        message: "Expected 'openclix/config/v1', got '${config.schemaVersion}'",
      ),
    );
  }

  if (config.configVersion.isEmpty) {
    errors.add(
      ValidationIssue(
        path: '.config_version',
        code: 'MISSING_CONFIG_VERSION',
        message: 'config_version is required and must be a non-empty string',
      ),
    );
  }

  if (config.campaigns.isEmpty) {
    errors.add(
      ValidationIssue(
        path: '.campaigns',
        code: 'EMPTY_CAMPAIGNS',
        message: 'At least one campaign is required',
      ),
    );
  }

  final frequencyCap = config.settings?.frequencyCap;
  if (frequencyCap != null) {
    if (frequencyCap.maxCount < 1) {
      errors.add(
        ValidationIssue(
          path: '.settings.frequency_cap.max_count',
          code: 'INVALID_FREQUENCY_CAP',
          message: 'frequency_cap.max_count must be an integer >= 1',
        ),
      );
    }

    if (frequencyCap.windowSeconds < 1) {
      errors.add(
        ValidationIssue(
          path: '.settings.frequency_cap.window_seconds',
          code: 'INVALID_FREQUENCY_CAP',
          message: 'frequency_cap.window_seconds must be an integer >= 1',
        ),
      );
    }
  }

  final doNotDisturb = config.settings?.doNotDisturb;
  if (doNotDisturb != null) {
    if (doNotDisturb.startHour < 0 || doNotDisturb.startHour > 23) {
      errors.add(
        ValidationIssue(
          path: '.settings.do_not_disturb.start_hour',
          code: 'INVALID_DND_HOURS',
          message: 'do_not_disturb.start_hour must be an integer 0-23',
        ),
      );
    }

    if (doNotDisturb.endHour < 0 || doNotDisturb.endHour > 23) {
      errors.add(
        ValidationIssue(
          path: '.settings.do_not_disturb.end_hour',
          code: 'INVALID_DND_HOURS',
          message: 'do_not_disturb.end_hour must be an integer 0-23',
        ),
      );
    }
  }

  for (final campaignEntry in config.campaigns.entries) {
    final campaignId = campaignEntry.key;
    final campaign = campaignEntry.value;
    final basePath = '.campaigns["$campaignId"]';

    if (!kebabCasePattern.hasMatch(campaignId)) {
      errors.add(
        ValidationIssue(
          path: basePath,
          code: 'INVALID_CAMPAIGN_ID',
          message: "Campaign ID '$campaignId' must be kebab-case",
        ),
      );
    }

    if (campaign.name.isEmpty) {
      errors.add(
        ValidationIssue(
          path: '$basePath.name',
          code: 'MISSING_CAMPAIGN_NAME',
          message: 'Campaign missing required name',
        ),
      );
    }

    if (campaign.type != 'campaign') {
      errors.add(
        ValidationIssue(
          path: '$basePath.type',
          code: 'INVALID_CAMPAIGN_TYPE',
          message: "Campaign type must be 'campaign'",
        ),
      );
    }

    if (campaign.description.trim().isEmpty) {
      errors.add(
        ValidationIssue(
          path: '$basePath.description',
          code: 'MISSING_DESCRIPTION',
          message: 'Campaign missing required description',
        ),
      );
    }

    if (!validCampaignStatuses.contains(campaign.status.value)) {
      errors.add(
        ValidationIssue(
          path: '$basePath.status',
          code: 'INVALID_CAMPAIGN_STATUS',
          message:
              "Campaign status '${campaign.status.value}' is not valid "
              "(expected 'running' or 'paused')",
        ),
      );
    }

    if (!validTriggerTypes.contains(campaign.trigger.type.value)) {
      errors.add(
        ValidationIssue(
          path: '$basePath.trigger.type',
          code: 'INVALID_TRIGGER_TYPE',
          message:
              "trigger.type '${campaign.trigger.type.value}' is not valid "
              "(expected 'event', 'scheduled', or 'recurring')",
        ),
      );
    }

    if (campaign.trigger.type == TriggerType.event) {
      final eventConfiguration = campaign.trigger.event;
      if (eventConfiguration == null) {
        errors.add(
          ValidationIssue(
            path: '$basePath.trigger.event',
            code: 'MISSING_EVENT_CONFIG',
            message:
                "Trigger type 'event' requires trigger.event configuration",
          ),
        );
      } else {
        validateEventConditionGroup(
          eventConfiguration.triggerEvent,
          '$basePath.trigger.event.trigger_event',
          errors,
          warnings,
        );

        if (eventConfiguration.cancelEvent != null) {
          validateEventConditionGroup(
            eventConfiguration.cancelEvent,
            '$basePath.trigger.event.cancel_event',
            errors,
            warnings,
          );
        }

        if (eventConfiguration.delaySeconds != null &&
            eventConfiguration.delaySeconds! < 0) {
          errors.add(
            ValidationIssue(
              path: '$basePath.trigger.event.delay_seconds',
              code: 'INVALID_DELAY_SECONDS',
              message: 'event.delay_seconds must be an integer >= 0',
            ),
          );
        }
      }
    }

    if (campaign.trigger.type == TriggerType.scheduled) {
      final scheduledConfiguration = campaign.trigger.scheduled;
      if (scheduledConfiguration == null) {
        errors.add(
          ValidationIssue(
            path: '$basePath.trigger.scheduled',
            code: 'MISSING_SCHEDULED_CONFIG',
            message:
                "Trigger type 'scheduled' requires trigger.scheduled configuration",
          ),
        );
      } else if (!isValidIsoDateString(scheduledConfiguration.executeAt)) {
        errors.add(
          ValidationIssue(
            path: '$basePath.trigger.scheduled.execute_at',
            code: 'INVALID_SCHEDULED_EXECUTE_AT',
            message: 'scheduled.execute_at must be a valid ISO 8601 datetime',
          ),
        );
      }
    }

    if (campaign.trigger.type == TriggerType.recurring) {
      final recurringConfiguration = campaign.trigger.recurring;
      if (recurringConfiguration == null) {
        errors.add(
          ValidationIssue(
            path: '$basePath.trigger.recurring',
            code: 'MISSING_RECURRING_CONFIG',
            message:
                "Trigger type 'recurring' requires trigger.recurring configuration",
          ),
        );
      } else {
        final rule = recurringConfiguration.rule;

        if (!validRecurrenceTypes.contains(rule.type.value)) {
          errors.add(
            ValidationIssue(
              path: '$basePath.trigger.recurring.rule.type',
              code: 'INVALID_RECURRENCE_TYPE',
              message:
                  "recurring.rule.type '${rule.type.value}' is not valid "
                  "(expected 'hourly', 'daily', or 'weekly')",
            ),
          );
        }

        if (rule.interval < 1) {
          errors.add(
            ValidationIssue(
              path: '$basePath.trigger.recurring.rule.interval',
              code: 'INVALID_RECURRENCE_INTERVAL',
              message: 'recurring.rule.interval must be an integer >= 1',
            ),
          );
        }

        if (rule.timeOfDay != null) {
          if (rule.timeOfDay!.hour < 0 || rule.timeOfDay!.hour > 23) {
            errors.add(
              ValidationIssue(
                path: '$basePath.trigger.recurring.rule.time_of_day.hour',
                code: 'INVALID_TIME_OF_DAY_HOUR',
                message: 'time_of_day.hour must be an integer between 0 and 23',
              ),
            );
          }

          if (rule.timeOfDay!.minute < 0 || rule.timeOfDay!.minute > 59) {
            errors.add(
              ValidationIssue(
                path: '$basePath.trigger.recurring.rule.time_of_day.minute',
                code: 'INVALID_TIME_OF_DAY_MINUTE',
                message:
                    'time_of_day.minute must be an integer between 0 and 59',
              ),
            );
          }
        }

        if (rule.type == RecurrenceType.weekly) {
          final daysOfWeek = rule.weeklyRule?.daysOfWeek ?? const <DayOfWeek>[];
          if (daysOfWeek.isEmpty) {
            errors.add(
              ValidationIssue(
                path:
                    '$basePath.trigger.recurring.rule.weekly_rule.days_of_week',
                code: 'MISSING_WEEKLY_DAYS',
                message: 'weekly recurrence requires weekly_rule.days_of_week',
              ),
            );
          } else if (daysOfWeek.any(
            (day) => !validWeekDays.contains(day.value),
          )) {
            errors.add(
              ValidationIssue(
                path:
                    '$basePath.trigger.recurring.rule.weekly_rule.days_of_week',
                code: 'INVALID_WEEKLY_DAY',
                message:
                    'weekly_rule.days_of_week must contain valid weekday strings '
                    '(sunday-saturday)',
              ),
            );
          }
        }

        if (recurringConfiguration.startAt != null &&
            !isValidIsoDateString(recurringConfiguration.startAt)) {
          errors.add(
            ValidationIssue(
              path: '$basePath.trigger.recurring.start_at',
              code: 'INVALID_RECURRING_START_AT',
              message: 'recurring.start_at must be a valid ISO 8601 datetime',
            ),
          );
        }

        if (recurringConfiguration.endAt != null &&
            !isValidIsoDateString(recurringConfiguration.endAt)) {
          errors.add(
            ValidationIssue(
              path: '$basePath.trigger.recurring.end_at',
              code: 'INVALID_RECURRING_END_AT',
              message: 'recurring.end_at must be a valid ISO 8601 datetime',
            ),
          );
        }

        if (recurringConfiguration.startAt != null &&
            recurringConfiguration.endAt != null) {
          final startDateTime = DateTime.tryParse(
            recurringConfiguration.startAt!,
          );
          final endDateTime = DateTime.tryParse(recurringConfiguration.endAt!);

          if (startDateTime != null &&
              endDateTime != null &&
              !endDateTime.isAfter(startDateTime)) {
            errors.add(
              ValidationIssue(
                path: '$basePath.trigger.recurring.end_at',
                code: 'INVALID_RECURRING_RANGE',
                message:
                    'recurring.end_at must be later than recurring.start_at',
              ),
            );
          }
        }
      }
    }

    if (!validChannelTypes.contains(campaign.message.channelType.value)) {
      errors.add(
        ValidationIssue(
          path: '$basePath.message.channel_type',
          code: 'INVALID_CHANNEL_TYPE',
          message: "channel_type must be 'app_push'",
        ),
      );
    }

    if (campaign.message.content.title.isEmpty) {
      errors.add(
        ValidationIssue(
          path: '$basePath.message.content.title',
          code: 'MISSING_MESSAGE_TITLE',
          message: 'Message content must have a title',
        ),
      );
    } else if (campaign.message.content.title.length >
        maximumMessageTitleLength) {
      errors.add(
        ValidationIssue(
          path: '$basePath.message.content.title',
          code: 'INVALID_MESSAGE_TITLE_LENGTH',
          message:
              'title must be $maximumMessageTitleLength characters or less',
        ),
      );
    }

    if (campaign.message.content.body.isEmpty) {
      errors.add(
        ValidationIssue(
          path: '$basePath.message.content.body',
          code: 'MISSING_MESSAGE_BODY',
          message: 'Message content must have a body',
        ),
      );
    } else if (campaign.message.content.body.length >
        maximumMessageBodyLength) {
      errors.add(
        ValidationIssue(
          path: '$basePath.message.content.body',
          code: 'INVALID_MESSAGE_BODY_LENGTH',
          message: 'body must be $maximumMessageBodyLength characters or less',
        ),
      );
    }

    if (campaign.message.content.imageUrl != null &&
        !isValidUri(campaign.message.content.imageUrl)) {
      errors.add(
        ValidationIssue(
          path: '$basePath.message.content.image_url',
          code: 'INVALID_IMAGE_URL',
          message: 'image_url must be a valid URI',
        ),
      );
    }

    if (campaign.message.content.landingUrl != null &&
        !isValidUriReference(campaign.message.content.landingUrl)) {
      errors.add(
        ValidationIssue(
          path: '$basePath.message.content.landing_url',
          code: 'INVALID_LANDING_URL',
          message: 'landing_url must be a valid URI reference',
        ),
      );
    }
  }

  return ValidationResult(
    valid: errors.isEmpty,
    errors: errors,
    warnings: warnings,
  );
}
