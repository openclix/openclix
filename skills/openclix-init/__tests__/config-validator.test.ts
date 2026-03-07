import { describe, test, expect } from 'bun:test';
import { validateConfig } from '../templates/react-native/infrastructure/ConfigValidator';
import { makeMinimalConfig, makeEventCampaign, makeScheduledCampaign, makeRecurringCampaign } from './helpers/fixtures';
import type { Config, Campaign } from '../templates/react-native/domain/OpenClixTypes';

function validate(overrides?: Partial<Config>) {
  return validateConfig(makeMinimalConfig(overrides));
}

function validateWithCampaign(id: string, campaign: Campaign, configOverrides?: Partial<Config>) {
  return validateConfig(
    makeMinimalConfig({ campaigns: { [id]: campaign }, ...configOverrides }),
  );
}

function hasError(result: ReturnType<typeof validateConfig>, code: string): boolean {
  return result.errors.some((e) => e.code === code);
}

function hasWarning(result: ReturnType<typeof validateConfig>, code: string): boolean {
  return result.warnings.some((e) => e.code === code);
}

describe('validateConfig', () => {
  describe('root-level', () => {
    test('valid minimal config passes', () => {
      const result = validate();
      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    test('wrong schema_version', () => {
      const result = validate({ schema_version: 'wrong' as any });
      expect(hasError(result, 'INVALID_SCHEMA_VERSION')).toBe(true);
    });

    test('empty config_version', () => {
      const result = validate({ config_version: '' });
      expect(hasError(result, 'MISSING_CONFIG_VERSION')).toBe(true);
    });

    test('empty campaigns', () => {
      const result = validate({ campaigns: {} });
      expect(hasError(result, 'EMPTY_CAMPAIGNS')).toBe(true);
    });

    test('additional root properties', () => {
      const config = { ...makeMinimalConfig(), extra: true } as any;
      const result = validateConfig(config);
      expect(hasError(result, 'UNEXPECTED_CONFIG_PROPERTY')).toBe(true);
    });

    test('wrong $schema', () => {
      const result = validate({ $schema: 'https://wrong.com/schema.json' as any });
      expect(hasError(result, 'INVALID_SCHEMA_POINTER')).toBe(true);
    });
  });

  describe('settings', () => {
    test('valid frequency_cap passes', () => {
      const result = validate({
        settings: { frequency_cap: { max_count: 3, window_seconds: 3600 } },
      });
      expect(result.valid).toBe(true);
    });

    test('max_count < 1', () => {
      const result = validate({
        settings: { frequency_cap: { max_count: 0, window_seconds: 3600 } },
      });
      expect(hasError(result, 'INVALID_FREQUENCY_CAP')).toBe(true);
    });

    test('window_seconds < 1', () => {
      const result = validate({
        settings: { frequency_cap: { max_count: 3, window_seconds: 0 } },
      });
      expect(hasError(result, 'INVALID_FREQUENCY_CAP')).toBe(true);
    });

    test('DnD hours outside 0-23', () => {
      const result = validate({
        settings: { do_not_disturb: { start_hour: -1, end_hour: 24 } },
      });
      expect(hasError(result, 'INVALID_DND_HOURS')).toBe(true);
    });

    test('non-integer frequency_cap fields', () => {
      const result = validate({
        settings: { frequency_cap: { max_count: 1.5, window_seconds: 3600.1 } },
      });
      expect(hasError(result, 'INVALID_FREQUENCY_CAP')).toBe(true);
    });
  });

  describe('campaign fields', () => {
    test('non-kebab-case ID', () => {
      const result = validateWithCampaign('BadCase', makeEventCampaign());
      expect(hasError(result, 'INVALID_CAMPAIGN_ID')).toBe(true);
    });

    test('missing name', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({ name: '' as any }),
      );
      expect(hasError(result, 'MISSING_CAMPAIGN_NAME')).toBe(true);
    });

    test('invalid type', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({ type: 'invalid' as any }),
      );
      expect(hasError(result, 'INVALID_CAMPAIGN_TYPE')).toBe(true);
    });

    test('invalid status', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({ status: 'draft' as any }),
      );
      expect(hasError(result, 'INVALID_CAMPAIGN_STATUS')).toBe(true);
    });

    test('campaign-level frequency_cap validated', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          frequency_cap: { max_count: 0, window_seconds: 100 },
        }),
      );
      expect(hasError(result, 'INVALID_FREQUENCY_CAP')).toBe(true);
    });
  });

  describe('trigger — event', () => {
    test('valid event trigger passes', () => {
      const result = validateWithCampaign('test-campaign', makeEventCampaign());
      expect(result.valid).toBe(true);
    });

    test('missing trigger.event', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          trigger: { type: 'event' } as any,
        }),
      );
      expect(hasError(result, 'MISSING_EVENT_CONFIG')).toBe(true);
    });

    test('missing conditions', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: { connector: 'and', conditions: [] },
            },
          },
        }),
      );
      expect(hasError(result, 'MISSING_EVENT_CONDITIONS')).toBe(true);
    });

    test('invalid operator', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: {
                connector: 'and',
                conditions: [
                  { field: 'name', operator: 'bad_op' as any, values: ['x'] },
                ],
              },
            },
          },
        }),
      );
      expect(hasError(result, 'INVALID_EVENT_OPERATOR')).toBe(true);
    });

    test('property field without property_name', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: {
                connector: 'and',
                conditions: [
                  { field: 'property', operator: 'equal', values: ['x'] },
                ],
              },
            },
          },
        }),
      );
      expect(hasError(result, 'MISSING_PROPERTY_NAME')).toBe(true);
    });

    test('name field with property_name produces warning', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: {
                connector: 'and',
                conditions: [
                  { field: 'name', property_name: 'unused', operator: 'equal', values: ['x'] },
                ],
              },
            },
          },
        }),
      );
      expect(hasWarning(result, 'UNUSED_PROPERTY_NAME')).toBe(true);
    });

    test('exists with values produces warning', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: {
                connector: 'and',
                conditions: [
                  { field: 'property', property_name: 'p', operator: 'exists', values: ['x'] },
                ],
              },
            },
          },
        }),
      );
      expect(hasWarning(result, 'UNUSED_EVENT_VALUES')).toBe(true);
    });

    test('negative delay_seconds', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: {
                connector: 'and',
                conditions: [{ field: 'name', operator: 'equal', values: ['x'] }],
              },
              delay_seconds: -1,
            },
          },
        }),
      );
      expect(hasError(result, 'INVALID_DELAY_SECONDS')).toBe(true);
    });
  });

  describe('trigger — scheduled', () => {
    test('valid scheduled trigger passes', () => {
      const result = validateWithCampaign('test-campaign', makeScheduledCampaign());
      expect(result.valid).toBe(true);
    });

    test('invalid execute_at', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeScheduledCampaign({
          trigger: {
            type: 'scheduled',
            scheduled: { execute_at: 'not-a-date' },
          },
        }),
      );
      expect(hasError(result, 'INVALID_SCHEDULED_EXECUTE_AT')).toBe(true);
    });
  });

  describe('trigger — recurring', () => {
    test('valid weekly recurring passes', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeRecurringCampaign({
          trigger: {
            type: 'recurring',
            recurring: {
              rule: {
                type: 'weekly',
                interval: 1,
                weekly_rule: { days_of_week: ['monday', 'friday'] },
                time_of_day: { hour: 9, minute: 0 },
              },
            },
          },
        }),
      );
      expect(result.valid).toBe(true);
    });

    test('missing rule', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeRecurringCampaign({
          trigger: { type: 'recurring', recurring: {} as any },
        }),
      );
      expect(hasError(result, 'MISSING_RECURRENCE_RULE')).toBe(true);
    });

    test('invalid recurrence type', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeRecurringCampaign({
          trigger: {
            type: 'recurring',
            recurring: { rule: { type: 'monthly' as any, interval: 1 } },
          },
        }),
      );
      expect(hasError(result, 'INVALID_RECURRENCE_TYPE')).toBe(true);
    });

    test('interval < 1', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeRecurringCampaign({
          trigger: {
            type: 'recurring',
            recurring: { rule: { type: 'daily', interval: 0 } },
          },
        }),
      );
      expect(hasError(result, 'INVALID_RECURRENCE_INTERVAL')).toBe(true);
    });

    test('weekly without weekly_rule', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeRecurringCampaign({
          trigger: {
            type: 'recurring',
            recurring: { rule: { type: 'weekly', interval: 1 } },
          },
        }),
      );
      expect(hasError(result, 'MISSING_WEEKLY_DAYS')).toBe(true);
    });

    test('invalid day names', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeRecurringCampaign({
          trigger: {
            type: 'recurring',
            recurring: {
              rule: {
                type: 'weekly',
                interval: 1,
                weekly_rule: { days_of_week: ['notaday' as any] },
              },
            },
          },
        }),
      );
      expect(hasError(result, 'INVALID_WEEKLY_DAY')).toBe(true);
    });

    test('end_at <= start_at', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeRecurringCampaign({
          trigger: {
            type: 'recurring',
            recurring: {
              start_at: '2026-02-01T00:00:00.000Z',
              end_at: '2026-01-01T00:00:00.000Z',
              rule: { type: 'daily', interval: 1 },
            },
          },
        }),
      );
      expect(hasError(result, 'INVALID_RECURRING_RANGE')).toBe(true);
    });

    test('invalid time_of_day hour/minute', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeRecurringCampaign({
          trigger: {
            type: 'recurring',
            recurring: {
              rule: {
                type: 'daily',
                interval: 1,
                time_of_day: { hour: 25, minute: -1 },
              },
            },
          },
        }),
      );
      expect(hasError(result, 'INVALID_TIME_OF_DAY_HOUR')).toBe(true);
      expect(hasError(result, 'INVALID_TIME_OF_DAY_MINUTE')).toBe(true);
    });
  });

  describe('message', () => {
    test('valid message passes', () => {
      const result = validateWithCampaign('test-campaign', makeEventCampaign());
      expect(result.valid).toBe(true);
    });

    test('invalid channel_type', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          message: {
            channel_type: 'email' as any,
            content: { title: 'T', body: 'B' },
          },
        }),
      );
      expect(hasError(result, 'INVALID_CHANNEL_TYPE')).toBe(true);
    });

    test('missing title', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          message: {
            channel_type: 'app_push',
            content: { title: '', body: 'Body text' },
          },
        }),
      );
      expect(hasError(result, 'MISSING_MESSAGE_TITLE')).toBe(true);
    });

    test('title > 120 chars', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          message: {
            channel_type: 'app_push',
            content: { title: 'x'.repeat(121), body: 'Body' },
          },
        }),
      );
      expect(hasError(result, 'INVALID_MESSAGE_TITLE_LENGTH')).toBe(true);
    });

    test('body > 500 chars', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          message: {
            channel_type: 'app_push',
            content: { title: 'Title', body: 'x'.repeat(501) },
          },
        }),
      );
      expect(hasError(result, 'INVALID_MESSAGE_BODY_LENGTH')).toBe(true);
    });

    test('invalid image_url', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          message: {
            channel_type: 'app_push',
            content: { title: 'T', body: 'B', image_url: 'not a url' },
          },
        }),
      );
      expect(hasError(result, 'INVALID_IMAGE_URL')).toBe(true);
    });

    test('relative landing_url passes (URI reference)', () => {
      const result = validateWithCampaign(
        'test-campaign',
        makeEventCampaign({
          message: {
            channel_type: 'app_push',
            content: { title: 'T', body: 'B', landing_url: '/path/to/page' },
          },
        }),
      );
      expect(result.valid).toBe(true);
    });
  });
});
