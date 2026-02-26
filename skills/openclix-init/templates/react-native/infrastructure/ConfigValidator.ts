import type {
  Config,
  CampaignStatus,
  ChannelType,
  TriggerType,
  RecurrenceType,
  DayOfWeek,
} from '../domain/ClixTypes';

export interface ValidationIssue {
  path: string;
  code: string;
  message: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationIssue[];
  warnings: ValidationIssue[];
}

const KEBAB_CASE_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const VALID_STATUSES: ReadonlySet<string> = new Set<CampaignStatus>(['running', 'paused']);
const VALID_CHANNEL_TYPES: ReadonlySet<string> = new Set<ChannelType>(['app_push']);
const VALID_TRIGGER_TYPES: ReadonlySet<string> = new Set<TriggerType>([
  'event',
  'scheduled',
  'recurring',
]);
const VALID_RECURRENCE_TYPES: ReadonlySet<string> = new Set<RecurrenceType>([
  'hourly',
  'daily',
  'weekly',
]);
const VALID_WEEK_DAYS: ReadonlySet<string> = new Set<DayOfWeek>([
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
]);
const VALID_EVENT_CONNECTORS: ReadonlySet<string> = new Set(['and', 'or']);
const VALID_EVENT_FIELDS: ReadonlySet<string> = new Set(['name', 'property']);
const VALID_EVENT_OPERATORS: ReadonlySet<string> = new Set([
  'equal',
  'not_equal',
  'greater_than',
  'greater_than_or_equal',
  'less_than',
  'less_than_or_equal',
  'contains',
  'not_contains',
  'starts_with',
  'ends_with',
  'matches',
  'exists',
  'not_exists',
  'in',
  'not_in',
]);

function isValidIsoDate(value: string | undefined): boolean {
  if (!value || typeof value !== 'string') return false;
  return !Number.isNaN(new Date(value).getTime());
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.length > 0;
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === 'string');
}

function validateEventConditionGroup(
  group: unknown,
  path: string,
  errors: ValidationIssue[],
  warnings: ValidationIssue[],
): void {
  if (!group || typeof group !== 'object') {
    errors.push({
      path,
      code: 'INVALID_EVENT_CONDITION_GROUP',
      message: 'event condition group must be an object',
    });
    return;
  }

  const conditionGroup = group as Record<string, unknown>;
  if (!VALID_EVENT_CONNECTORS.has(String(conditionGroup.connector))) {
    errors.push({
      path: `${path}.connector`,
      code: 'INVALID_EVENT_CONNECTOR',
      message: "connector must be 'and' or 'or'",
    });
  }

  if (!Array.isArray(conditionGroup.conditions) || conditionGroup.conditions.length === 0) {
    errors.push({
      path: `${path}.conditions`,
      code: 'MISSING_EVENT_CONDITIONS',
      message: 'conditions must contain at least one entry',
    });
    return;
  }

  conditionGroup.conditions.forEach((condition, conditionIndex) => {
    const conditionPath = `${path}.conditions[${conditionIndex}]`;

    if (!condition || typeof condition !== 'object') {
      errors.push({
        path: conditionPath,
        code: 'INVALID_EVENT_CONDITION',
        message: 'condition must be an object',
      });
      return;
    }

    const conditionRecord = condition as Record<string, unknown>;
    const field = String(conditionRecord.field);
    if (!VALID_EVENT_FIELDS.has(field)) {
      errors.push({
        path: `${conditionPath}.field`,
        code: 'INVALID_EVENT_FIELD',
        message: "field must be 'name' or 'property'",
      });
    }

    if (field === 'property' && !isNonEmptyString(conditionRecord.property_name)) {
      errors.push({
        path: `${conditionPath}.property_name`,
        code: 'MISSING_PROPERTY_NAME',
        message: "field 'property' requires property_name",
      });
    }

    if (field === 'name' && isNonEmptyString(conditionRecord.property_name)) {
      warnings.push({
        path: `${conditionPath}.property_name`,
        code: 'UNUSED_PROPERTY_NAME',
        message: "property_name is ignored when field is 'name'",
      });
    }

    const operator = String(conditionRecord.operator);
    if (!VALID_EVENT_OPERATORS.has(operator)) {
      errors.push({
        path: `${conditionPath}.operator`,
        code: 'INVALID_EVENT_OPERATOR',
        message: 'operator is not supported',
      });
    }

    const values = conditionRecord.values;
    if (!isStringArray(values)) {
      errors.push({
        path: `${conditionPath}.values`,
        code: 'INVALID_EVENT_VALUES',
        message: 'values must be an array of strings',
      });
      return;
    }

    const operatorRequiresValues = operator !== 'exists' && operator !== 'not_exists';
    if (operatorRequiresValues && values.length === 0) {
      errors.push({
        path: `${conditionPath}.values`,
        code: 'MISSING_EVENT_VALUES',
        message: 'values must not be empty for this operator',
      });
    }

    if (!operatorRequiresValues && values.length > 0) {
      warnings.push({
        path: `${conditionPath}.values`,
        code: 'UNUSED_EVENT_VALUES',
        message: 'values are ignored for exists/not_exists operators',
      });
    }
  });
}

export function validateConfig(config: Config): ValidationResult {
  const errors: ValidationIssue[] = [];
  const warnings: ValidationIssue[] = [];

  if (config.schema_version !== 'openclix/config/v1') {
    errors.push({
      path: '.schema_version',
      code: 'INVALID_SCHEMA_VERSION',
      message: `Expected 'openclix/config/v1', got '${config.schema_version}'`,
    });
  }

  if (typeof config.config_version !== 'string' || config.config_version.length === 0) {
    errors.push({
      path: '.config_version',
      code: 'MISSING_CONFIG_VERSION',
      message: 'config_version is required and must be a non-empty string',
    });
  }

  if (!config.campaigns || typeof config.campaigns !== 'object' || Object.keys(config.campaigns).length === 0) {
    errors.push({
      path: '.campaigns',
      code: 'EMPTY_CAMPAIGNS',
      message: 'At least one campaign is required',
    });
  }

  if (config.settings?.frequency_cap) {
    const frequencyCap = config.settings.frequency_cap;
    if (typeof frequencyCap.max_count !== 'number' || frequencyCap.max_count < 1) {
      errors.push({
        path: '.settings.frequency_cap.max_count',
        code: 'INVALID_FREQUENCY_CAP',
        message: 'frequency_cap.max_count must be >= 1',
      });
    }
    if (
      typeof frequencyCap.window_seconds !== 'number' ||
      frequencyCap.window_seconds < 1
    ) {
      errors.push({
        path: '.settings.frequency_cap.window_seconds',
        code: 'INVALID_FREQUENCY_CAP',
        message: 'frequency_cap.window_seconds must be >= 1',
      });
    }
  }

  if (config.settings?.do_not_disturb) {
    const doNotDisturb = config.settings.do_not_disturb;
    if (
      typeof doNotDisturb.start_hour !== 'number' ||
      doNotDisturb.start_hour < 0 ||
      doNotDisturb.start_hour > 23
    ) {
      errors.push({
        path: '.settings.do_not_disturb.start_hour',
        code: 'INVALID_DND_HOURS',
        message: 'do_not_disturb.start_hour must be 0-23',
      });
    }
    if (
      typeof doNotDisturb.end_hour !== 'number' ||
      doNotDisturb.end_hour < 0 ||
      doNotDisturb.end_hour > 23
    ) {
      errors.push({
        path: '.settings.do_not_disturb.end_hour',
        code: 'INVALID_DND_HOURS',
        message: 'do_not_disturb.end_hour must be 0-23',
      });
    }
  }

  if (config.campaigns && typeof config.campaigns === 'object') {
    for (const [campaignId, campaign] of Object.entries(config.campaigns)) {
      const basePath = `.campaigns["${campaignId}"]`;

      if (!KEBAB_CASE_PATTERN.test(campaignId)) {
        errors.push({
          path: `${basePath}`,
          code: 'INVALID_CAMPAIGN_ID',
          message: `Campaign ID '${campaignId}' must be kebab-case`,
        });
      }

      if (!campaign.name || campaign.name.length === 0) {
        errors.push({
          path: `${basePath}.name`,
          code: 'MISSING_CAMPAIGN_NAME',
          message: 'Campaign missing required name',
        });
      }

      if (!campaign.type || campaign.type !== 'campaign') {
        errors.push({
          path: `${basePath}.type`,
          code: 'INVALID_CAMPAIGN_TYPE',
          message: `Campaign type must be 'campaign'`,
        });
      }

      if (!campaign.description && campaign.description !== '') {
        warnings.push({
          path: `${basePath}.description`,
          code: 'MISSING_DESCRIPTION',
          message: 'Campaign is missing a description',
        });
      }

      if (!VALID_STATUSES.has(campaign.status)) {
        errors.push({
          path: `${basePath}.status`,
          code: 'INVALID_CAMPAIGN_STATUS',
          message: `Campaign status '${campaign.status}' is not valid (expected 'running' or 'paused')`,
        });
      }

      if (!campaign.trigger) {
        errors.push({
          path: `${basePath}.trigger`,
          code: 'MISSING_TRIGGER',
          message: 'Campaign missing required trigger',
        });
      } else {
        if (!VALID_TRIGGER_TYPES.has(campaign.trigger.type)) {
          errors.push({
            path: `${basePath}.trigger.type`,
            code: 'INVALID_TRIGGER_TYPE',
            message:
              `trigger.type '${campaign.trigger.type}' is not valid ` +
              `(expected 'event', 'scheduled', or 'recurring')`,
          });
        }

        if (campaign.trigger.type === 'event') {
          if (!campaign.trigger.event) {
            errors.push({
              path: `${basePath}.trigger.event`,
              code: 'MISSING_EVENT_CONFIG',
              message: "Trigger type 'event' requires trigger.event configuration",
            });
          } else {
            validateEventConditionGroup(
              campaign.trigger.event.trigger_event,
              `${basePath}.trigger.event.trigger_event`,
              errors,
              warnings,
            );

            if (campaign.trigger.event.cancel_event) {
              validateEventConditionGroup(
                campaign.trigger.event.cancel_event,
                `${basePath}.trigger.event.cancel_event`,
                errors,
                warnings,
              );
            }

            if (
              campaign.trigger.event.delay_seconds !== undefined &&
              (!Number.isFinite(campaign.trigger.event.delay_seconds) ||
                campaign.trigger.event.delay_seconds < 0)
            ) {
              errors.push({
                path: `${basePath}.trigger.event.delay_seconds`,
                code: 'INVALID_DELAY_SECONDS',
                message: 'event.delay_seconds must be >= 0',
              });
            }
          }
        }

        if (campaign.trigger.type === 'scheduled') {
          if (!campaign.trigger.scheduled) {
            errors.push({
              path: `${basePath}.trigger.scheduled`,
              code: 'MISSING_SCHEDULED_CONFIG',
              message: "Trigger type 'scheduled' requires trigger.scheduled configuration",
            });
          } else if (!isValidIsoDate(campaign.trigger.scheduled.execute_at)) {
            errors.push({
              path: `${basePath}.trigger.scheduled.execute_at`,
              code: 'INVALID_SCHEDULED_EXECUTE_AT',
              message: 'scheduled.execute_at must be a valid ISO 8601 datetime',
            });
          }
        }

        if (campaign.trigger.type === 'recurring') {
          if (!campaign.trigger.recurring) {
            errors.push({
              path: `${basePath}.trigger.recurring`,
              code: 'MISSING_RECURRING_CONFIG',
              message: "Trigger type 'recurring' requires trigger.recurring configuration",
            });
          } else {
            const recurring = campaign.trigger.recurring;
            const rule = recurring.rule;

            if (!rule) {
              errors.push({
                path: `${basePath}.trigger.recurring.rule`,
                code: 'MISSING_RECURRENCE_RULE',
                message: 'recurring.rule is required',
              });
            } else {
              if (!VALID_RECURRENCE_TYPES.has(rule.type)) {
                errors.push({
                  path: `${basePath}.trigger.recurring.rule.type`,
                  code: 'INVALID_RECURRENCE_TYPE',
                  message:
                    `recurring.rule.type '${rule.type}' is not valid ` +
                    `(expected 'hourly', 'daily', or 'weekly')`,
                });
              }

              if (!Number.isInteger(rule.interval) || rule.interval < 1) {
                errors.push({
                  path: `${basePath}.trigger.recurring.rule.interval`,
                  code: 'INVALID_RECURRENCE_INTERVAL',
                  message: 'recurring.rule.interval must be an integer >= 1',
                });
              }

              if (rule.time_of_day) {
                if (
                  !Number.isInteger(rule.time_of_day.hour) ||
                  rule.time_of_day.hour < 0 ||
                  rule.time_of_day.hour > 23
                ) {
                  errors.push({
                    path: `${basePath}.trigger.recurring.rule.time_of_day.hour`,
                    code: 'INVALID_TIME_OF_DAY_HOUR',
                    message: 'time_of_day.hour must be an integer between 0 and 23',
                  });
                }
                if (
                  !Number.isInteger(rule.time_of_day.minute) ||
                  rule.time_of_day.minute < 0 ||
                  rule.time_of_day.minute > 59
                ) {
                  errors.push({
                    path: `${basePath}.trigger.recurring.rule.time_of_day.minute`,
                    code: 'INVALID_TIME_OF_DAY_MINUTE',
                    message: 'time_of_day.minute must be an integer between 0 and 59',
                  });
                }
              }

              if (rule.type === 'weekly') {
                const days = rule.weekly_rule?.days_of_week;
                if (!days || days.length === 0) {
                  errors.push({
                    path: `${basePath}.trigger.recurring.rule.weekly_rule.days_of_week`,
                    code: 'MISSING_WEEKLY_DAYS',
                    message: "weekly recurrence requires weekly_rule.days_of_week",
                  });
                } else if (days.some((day) => !VALID_WEEK_DAYS.has(day))) {
                  errors.push({
                    path: `${basePath}.trigger.recurring.rule.weekly_rule.days_of_week`,
                    code: 'INVALID_WEEKLY_DAY',
                    message:
                      'weekly_rule.days_of_week must contain valid weekday strings (sunday-saturday)',
                  });
                }
              }
            }

            if (recurring.start_at && !isValidIsoDate(recurring.start_at)) {
              errors.push({
                path: `${basePath}.trigger.recurring.start_at`,
                code: 'INVALID_RECURRING_START_AT',
                message: 'recurring.start_at must be a valid ISO 8601 datetime',
              });
            }
            if (recurring.end_at && !isValidIsoDate(recurring.end_at)) {
              errors.push({
                path: `${basePath}.trigger.recurring.end_at`,
                code: 'INVALID_RECURRING_END_AT',
                message: 'recurring.end_at must be a valid ISO 8601 datetime',
              });
            }
            if (recurring.start_at && recurring.end_at) {
              const startAt = new Date(recurring.start_at).getTime();
              const endAt = new Date(recurring.end_at).getTime();
              if (!Number.isNaN(startAt) && !Number.isNaN(endAt) && endAt <= startAt) {
                errors.push({
                  path: `${basePath}.trigger.recurring.end_at`,
                  code: 'INVALID_RECURRING_RANGE',
                  message: 'recurring.end_at must be later than recurring.start_at',
                });
              }
            }
          }
        }
      }

      if (!campaign.message) {
        errors.push({
          path: `${basePath}.message`,
          code: 'MISSING_MESSAGE',
          message: 'Campaign missing required message',
        });
      } else {
        if (!VALID_CHANNEL_TYPES.has(campaign.message.channel_type)) {
          errors.push({
            path: `${basePath}.message.channel_type`,
            code: 'INVALID_CHANNEL_TYPE',
            message: `channel_type must be 'app_push'`,
          });
        }
        if (!campaign.message.content?.title) {
          errors.push({
            path: `${basePath}.message.content.title`,
            code: 'MISSING_MESSAGE_TITLE',
            message: 'Message content must have a title',
          });
        }
        if (!campaign.message.content?.body) {
          errors.push({
            path: `${basePath}.message.content.body`,
            code: 'MISSING_MESSAGE_BODY',
            message: 'Message content must have a body',
          });
        }
      }
    }
  }

  return { valid: errors.length === 0, errors, warnings };
}
