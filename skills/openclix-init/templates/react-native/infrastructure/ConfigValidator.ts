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

const MAX_MESSAGE_TITLE_LENGTH = 120;
const MAX_MESSAGE_BODY_LENGTH = 500;

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

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

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

function isInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value);
}

function isValidUri(value: string | undefined): boolean {
  if (!isNonEmptyString(value)) return false;
  if (/\s/.test(value)) return false;
  try {
    const parsed = new URL(value);
    return parsed.protocol.length > 0;
  } catch {
    return false;
  }
}

function isValidUriReference(value: string | undefined): boolean {
  if (!isNonEmptyString(value)) return false;
  if (/\s/.test(value)) return false;

  if (isValidUri(value)) return true;

  try {
    new URL(value, 'https://openclix.local');
    return true;
  } catch {
    return false;
  }
}

function buildPropertyPath(basePath: string, key: string): string {
  return basePath === '.' ? `.${key}` : `${basePath}.${key}`;
}

function validateNoAdditionalProperties(
  target: Record<string, unknown>,
  allowedKeys: readonly string[],
  path: string,
  errors: ValidationIssue[],
  code: string,
): void {
  const allowed = new Set(allowedKeys);
  for (const key of Object.keys(target)) {
    if (allowed.has(key)) continue;
    errors.push({
      path: buildPropertyPath(path, key),
      code,
      message: `Property '${key}' is not allowed`,
    });
  }
}

function validateEventConditionGroup(
  group: unknown,
  path: string,
  errors: ValidationIssue[],
  warnings: ValidationIssue[],
): void {
  if (!isObjectRecord(group)) {
    errors.push({
      path,
      code: 'INVALID_EVENT_CONDITION_GROUP',
      message: 'event condition group must be an object',
    });
    return;
  }

  validateNoAdditionalProperties(
    group,
    ['connector', 'conditions'],
    path,
    errors,
    'UNEXPECTED_EVENT_CONDITION_GROUP_PROPERTY',
  );

  if (!VALID_EVENT_CONNECTORS.has(String(group.connector))) {
    errors.push({
      path: `${path}.connector`,
      code: 'INVALID_EVENT_CONNECTOR',
      message: "connector must be 'and' or 'or'",
    });
  }

  if (!Array.isArray(group.conditions) || group.conditions.length === 0) {
    errors.push({
      path: `${path}.conditions`,
      code: 'MISSING_EVENT_CONDITIONS',
      message: 'conditions must contain at least one entry',
    });
    return;
  }

  group.conditions.forEach((condition, conditionIndex) => {
    const conditionPath = `${path}.conditions[${conditionIndex}]`;

    if (!isObjectRecord(condition)) {
      errors.push({
        path: conditionPath,
        code: 'INVALID_EVENT_CONDITION',
        message: 'condition must be an object',
      });
      return;
    }

    validateNoAdditionalProperties(
      condition,
      ['field', 'property_name', 'operator', 'values'],
      conditionPath,
      errors,
      'UNEXPECTED_EVENT_CONDITION_PROPERTY',
    );

    const field = String(condition.field);
    if (!VALID_EVENT_FIELDS.has(field)) {
      errors.push({
        path: `${conditionPath}.field`,
        code: 'INVALID_EVENT_FIELD',
        message: "field must be 'name' or 'property'",
      });
    }

    if (field === 'property' && !isNonEmptyString(condition.property_name)) {
      errors.push({
        path: `${conditionPath}.property_name`,
        code: 'MISSING_PROPERTY_NAME',
        message: "field 'property' requires property_name",
      });
    }

    if (field === 'name' && isNonEmptyString(condition.property_name)) {
      warnings.push({
        path: `${conditionPath}.property_name`,
        code: 'UNUSED_PROPERTY_NAME',
        message: "property_name is ignored when field is 'name'",
      });
    }

    const operator = String(condition.operator);
    if (!VALID_EVENT_OPERATORS.has(operator)) {
      errors.push({
        path: `${conditionPath}.operator`,
        code: 'INVALID_EVENT_OPERATOR',
        message: 'operator is not supported',
      });
    }

    const values = condition.values;
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
  const configRecord = config as unknown as Record<string, unknown>;

  validateNoAdditionalProperties(
    configRecord,
    ['$schema', 'schema_version', 'config_version', 'settings', 'campaigns'],
    '.',
    errors,
    'UNEXPECTED_CONFIG_PROPERTY',
  );

  if (
    configRecord['$schema'] !== undefined &&
    configRecord['$schema'] !== 'https://openclix.ai/schemas/openclix.schema.json'
  ) {
    errors.push({
      path: '.$schema',
      code: 'INVALID_SCHEMA_POINTER',
      message:
        "Expected '$schema' to be 'https://openclix.ai/schemas/openclix.schema.json'",
    });
  }

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

  if (config.settings !== undefined) {
    if (!isObjectRecord(config.settings)) {
      errors.push({
        path: '.settings',
        code: 'INVALID_SETTINGS',
        message: 'settings must be an object',
      });
    } else {
      validateNoAdditionalProperties(
        config.settings,
        ['frequency_cap', 'do_not_disturb'],
        '.settings',
        errors,
        'UNEXPECTED_SETTINGS_PROPERTY',
      );
    }
  }

  if (config.settings?.frequency_cap) {
    const frequencyCap = config.settings.frequency_cap as unknown as Record<string, unknown>;
    validateNoAdditionalProperties(
      frequencyCap,
      ['max_count', 'window_seconds'],
      '.settings.frequency_cap',
      errors,
      'UNEXPECTED_FREQUENCY_CAP_PROPERTY',
    );

    if (!isInteger(frequencyCap.max_count) || frequencyCap.max_count < 1) {
      errors.push({
        path: '.settings.frequency_cap.max_count',
        code: 'INVALID_FREQUENCY_CAP',
        message: 'frequency_cap.max_count must be an integer >= 1',
      });
    }
    if (!isInteger(frequencyCap.window_seconds) || frequencyCap.window_seconds < 1) {
      errors.push({
        path: '.settings.frequency_cap.window_seconds',
        code: 'INVALID_FREQUENCY_CAP',
        message: 'frequency_cap.window_seconds must be an integer >= 1',
      });
    }
  }

  if (config.settings?.do_not_disturb) {
    const doNotDisturb = config.settings.do_not_disturb as unknown as Record<string, unknown>;
    validateNoAdditionalProperties(
      doNotDisturb,
      ['start_hour', 'end_hour'],
      '.settings.do_not_disturb',
      errors,
      'UNEXPECTED_DND_PROPERTY',
    );

    if (
      !isInteger(doNotDisturb.start_hour) ||
      doNotDisturb.start_hour < 0 ||
      doNotDisturb.start_hour > 23
    ) {
      errors.push({
        path: '.settings.do_not_disturb.start_hour',
        code: 'INVALID_DND_HOURS',
        message: 'do_not_disturb.start_hour must be an integer between 0 and 23',
      });
    }
    if (
      !isInteger(doNotDisturb.end_hour) ||
      doNotDisturb.end_hour < 0 ||
      doNotDisturb.end_hour > 23
    ) {
      errors.push({
        path: '.settings.do_not_disturb.end_hour',
        code: 'INVALID_DND_HOURS',
        message: 'do_not_disturb.end_hour must be an integer between 0 and 23',
      });
    }
  }

  if (config.campaigns && typeof config.campaigns === 'object') {
    for (const [campaignId, campaign] of Object.entries(config.campaigns)) {
      const basePath = `.campaigns["${campaignId}"]`;

      if (!isObjectRecord(campaign)) {
        errors.push({
          path: basePath,
          code: 'INVALID_CAMPAIGN',
          message: 'campaign entry must be an object',
        });
        continue;
      }

      validateNoAdditionalProperties(
        campaign,
        ['name', 'type', 'description', 'status', 'trigger', 'message'],
        basePath,
        errors,
        'UNEXPECTED_CAMPAIGN_PROPERTY',
      );

      if (!KEBAB_CASE_PATTERN.test(campaignId)) {
        errors.push({
          path: basePath,
          code: 'INVALID_CAMPAIGN_ID',
          message: `Campaign ID '${campaignId}' must be kebab-case`,
        });
      }

      if (!isNonEmptyString(campaign.name)) {
        errors.push({
          path: `${basePath}.name`,
          code: 'MISSING_CAMPAIGN_NAME',
          message: 'Campaign missing required name',
        });
      }

      if (campaign.type !== 'campaign') {
        errors.push({
          path: `${basePath}.type`,
          code: 'INVALID_CAMPAIGN_TYPE',
          message: "Campaign type must be 'campaign'",
        });
      }

      if (!isNonEmptyString(campaign.description)) {
        errors.push({
          path: `${basePath}.description`,
          code: 'MISSING_DESCRIPTION',
          message: 'Campaign description is required',
        });
      }

      if (!VALID_STATUSES.has(String(campaign.status))) {
        errors.push({
          path: `${basePath}.status`,
          code: 'INVALID_CAMPAIGN_STATUS',
          message: `Campaign status '${String(campaign.status)}' is not valid (expected 'running' or 'paused')`,
        });
      }

      if (!isObjectRecord(campaign.trigger)) {
        errors.push({
          path: `${basePath}.trigger`,
          code: 'MISSING_TRIGGER',
          message: 'Campaign missing required trigger',
        });
      } else {
        validateNoAdditionalProperties(
          campaign.trigger,
          ['type', 'event', 'scheduled', 'recurring'],
          `${basePath}.trigger`,
          errors,
          'UNEXPECTED_TRIGGER_PROPERTY',
        );

        const triggerType = String(campaign.trigger.type);
        if (!VALID_TRIGGER_TYPES.has(triggerType)) {
          errors.push({
            path: `${basePath}.trigger.type`,
            code: 'INVALID_TRIGGER_TYPE',
            message:
              `trigger.type '${triggerType}' is not valid ` +
              "(expected 'event', 'scheduled', or 'recurring')",
          });
        }

        if (triggerType === 'event') {
          if (!isObjectRecord(campaign.trigger.event)) {
            errors.push({
              path: `${basePath}.trigger.event`,
              code: 'MISSING_EVENT_CONFIG',
              message: "Trigger type 'event' requires trigger.event configuration",
            });
          } else {
            validateNoAdditionalProperties(
              campaign.trigger.event,
              ['trigger_event', 'delay_seconds', 'cancel_event'],
              `${basePath}.trigger.event`,
              errors,
              'UNEXPECTED_EVENT_TRIGGER_PROPERTY',
            );

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
              (!isInteger(campaign.trigger.event.delay_seconds) ||
                campaign.trigger.event.delay_seconds < 0)
            ) {
              errors.push({
                path: `${basePath}.trigger.event.delay_seconds`,
                code: 'INVALID_DELAY_SECONDS',
                message: 'event.delay_seconds must be an integer >= 0',
              });
            }
          }
        }

        if (triggerType === 'scheduled') {
          if (!isObjectRecord(campaign.trigger.scheduled)) {
            errors.push({
              path: `${basePath}.trigger.scheduled`,
              code: 'MISSING_SCHEDULED_CONFIG',
              message: "Trigger type 'scheduled' requires trigger.scheduled configuration",
            });
          } else {
            validateNoAdditionalProperties(
              campaign.trigger.scheduled,
              ['execute_at'],
              `${basePath}.trigger.scheduled`,
              errors,
              'UNEXPECTED_SCHEDULED_TRIGGER_PROPERTY',
            );

            if (!isValidIsoDate(campaign.trigger.scheduled.execute_at)) {
              errors.push({
                path: `${basePath}.trigger.scheduled.execute_at`,
                code: 'INVALID_SCHEDULED_EXECUTE_AT',
                message: 'scheduled.execute_at must be a valid ISO 8601 datetime',
              });
            }
          }
        }

        if (triggerType === 'recurring') {
          if (!isObjectRecord(campaign.trigger.recurring)) {
            errors.push({
              path: `${basePath}.trigger.recurring`,
              code: 'MISSING_RECURRING_CONFIG',
              message: "Trigger type 'recurring' requires trigger.recurring configuration",
            });
          } else {
            const recurring = campaign.trigger.recurring;

            validateNoAdditionalProperties(
              recurring,
              ['start_at', 'end_at', 'rule'],
              `${basePath}.trigger.recurring`,
              errors,
              'UNEXPECTED_RECURRING_TRIGGER_PROPERTY',
            );

            if (!isObjectRecord(recurring.rule)) {
              errors.push({
                path: `${basePath}.trigger.recurring.rule`,
                code: 'MISSING_RECURRENCE_RULE',
                message: 'recurring.rule is required',
              });
            } else {
              const rule = recurring.rule;
              validateNoAdditionalProperties(
                rule,
                ['type', 'interval', 'weekly_rule', 'time_of_day'],
                `${basePath}.trigger.recurring.rule`,
                errors,
                'UNEXPECTED_RECURRENCE_RULE_PROPERTY',
              );

              if (!VALID_RECURRENCE_TYPES.has(String(rule.type))) {
                errors.push({
                  path: `${basePath}.trigger.recurring.rule.type`,
                  code: 'INVALID_RECURRENCE_TYPE',
                  message:
                    `recurring.rule.type '${String(rule.type)}' is not valid ` +
                    "(expected 'hourly', 'daily', or 'weekly')",
                });
              }

              if (!isInteger(rule.interval) || rule.interval < 1) {
                errors.push({
                  path: `${basePath}.trigger.recurring.rule.interval`,
                  code: 'INVALID_RECURRENCE_INTERVAL',
                  message: 'recurring.rule.interval must be an integer >= 1',
                });
              }

              if (rule.time_of_day !== undefined) {
                if (!isObjectRecord(rule.time_of_day)) {
                  errors.push({
                    path: `${basePath}.trigger.recurring.rule.time_of_day`,
                    code: 'INVALID_TIME_OF_DAY',
                    message: 'time_of_day must be an object',
                  });
                } else {
                  validateNoAdditionalProperties(
                    rule.time_of_day,
                    ['hour', 'minute'],
                    `${basePath}.trigger.recurring.rule.time_of_day`,
                    errors,
                    'UNEXPECTED_TIME_OF_DAY_PROPERTY',
                  );

                  if (
                    !isInteger(rule.time_of_day.hour) ||
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
                    !isInteger(rule.time_of_day.minute) ||
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
              }

              if (rule.type === 'weekly') {
                if (!isObjectRecord(rule.weekly_rule)) {
                  errors.push({
                    path: `${basePath}.trigger.recurring.rule.weekly_rule`,
                    code: 'MISSING_WEEKLY_DAYS',
                    message: 'weekly recurrence requires weekly_rule.days_of_week',
                  });
                } else {
                  validateNoAdditionalProperties(
                    rule.weekly_rule,
                    ['days_of_week'],
                    `${basePath}.trigger.recurring.rule.weekly_rule`,
                    errors,
                    'UNEXPECTED_WEEKLY_RULE_PROPERTY',
                  );

                  const days = rule.weekly_rule.days_of_week;
                  if (!Array.isArray(days) || days.length === 0) {
                    errors.push({
                      path: `${basePath}.trigger.recurring.rule.weekly_rule.days_of_week`,
                      code: 'MISSING_WEEKLY_DAYS',
                      message: 'weekly recurrence requires weekly_rule.days_of_week',
                    });
                  } else if (days.some((day) => !VALID_WEEK_DAYS.has(String(day)))) {
                    errors.push({
                      path: `${basePath}.trigger.recurring.rule.weekly_rule.days_of_week`,
                      code: 'INVALID_WEEKLY_DAY',
                      message:
                        'weekly_rule.days_of_week must contain valid weekday strings (sunday-saturday)',
                    });
                  }
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

      if (!isObjectRecord(campaign.message)) {
        errors.push({
          path: `${basePath}.message`,
          code: 'MISSING_MESSAGE',
          message: 'Campaign missing required message',
        });
      } else {
        validateNoAdditionalProperties(
          campaign.message,
          ['channel_type', 'content'],
          `${basePath}.message`,
          errors,
          'UNEXPECTED_MESSAGE_PROPERTY',
        );

        if (!VALID_CHANNEL_TYPES.has(String(campaign.message.channel_type))) {
          errors.push({
            path: `${basePath}.message.channel_type`,
            code: 'INVALID_CHANNEL_TYPE',
            message: "channel_type must be 'app_push'",
          });
        }

        const content = campaign.message.content;
        if (!isObjectRecord(content)) {
          errors.push({
            path: `${basePath}.message.content`,
            code: 'MISSING_MESSAGE_CONTENT',
            message: 'message.content is required',
          });
          continue;
        }

        validateNoAdditionalProperties(
          content,
          ['title', 'body', 'image_url', 'landing_url'],
          `${basePath}.message.content`,
          errors,
          'UNEXPECTED_MESSAGE_CONTENT_PROPERTY',
        );

        if (!isNonEmptyString(content.title)) {
          errors.push({
            path: `${basePath}.message.content.title`,
            code: 'MISSING_MESSAGE_TITLE',
            message: 'Message content must have a title',
          });
        } else if (content.title.length > MAX_MESSAGE_TITLE_LENGTH) {
          errors.push({
            path: `${basePath}.message.content.title`,
            code: 'INVALID_MESSAGE_TITLE_LENGTH',
            message: `title must be ${MAX_MESSAGE_TITLE_LENGTH} characters or less`,
          });
        }

        if (!isNonEmptyString(content.body)) {
          errors.push({
            path: `${basePath}.message.content.body`,
            code: 'MISSING_MESSAGE_BODY',
            message: 'Message content must have a body',
          });
        } else if (content.body.length > MAX_MESSAGE_BODY_LENGTH) {
          errors.push({
            path: `${basePath}.message.content.body`,
            code: 'INVALID_MESSAGE_BODY_LENGTH',
            message: `body must be ${MAX_MESSAGE_BODY_LENGTH} characters or less`,
          });
        }

        if (content.image_url !== undefined && !isValidUri(String(content.image_url))) {
          errors.push({
            path: `${basePath}.message.content.image_url`,
            code: 'INVALID_IMAGE_URL',
            message: 'image_url must be a valid URI',
          });
        }

        if (
          content.landing_url !== undefined &&
          !isValidUriReference(String(content.landing_url))
        ) {
          errors.push({
            path: `${basePath}.message.content.landing_url`,
            code: 'INVALID_LANDING_URL',
            message: 'landing_url must be a valid URI reference',
          });
        }
      }
    }
  }

  return { valid: errors.length === 0, errors, warnings };
}
