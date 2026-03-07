import { describe, test, expect } from 'bun:test';
import { CampaignProcessor } from '../templates/react-native/domain/CampaignProcessor';
import { EventConditionProcessor, ScheduleCalculator } from '../templates/react-native/domain/CampaignUtils';
import {
  makeEventCampaign,
  makeScheduledCampaign,
  makeRecurringCampaign,
  makeEmptySnapshot,
  makeEvent,
  makeEventTrackedContext,
  makeAppBootContext,
  makeSnapshotWithHistory,
  makeSnapshotWithQueuedMessages,
} from './helpers/fixtures';
import { createMockLogger } from './helpers/mocks';
import type { CampaignProcessorDeps } from '../templates/react-native/domain/CampaignProcessor';
import type { Settings, TriggerContext } from '../templates/react-native/domain/OpenClixTypes';

const processor = new CampaignProcessor();
const eventConditionProcessor = new EventConditionProcessor();
const scheduleCalculator = new ScheduleCalculator();

function makeDeps(settings?: Settings): CampaignProcessorDeps {
  return {
    eventConditionProcessor,
    scheduleCalculator,
    logger: createMockLogger(),
    settings,
  };
}

describe('CampaignProcessor', () => {
  test('paused campaign is skipped', () => {
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign({ status: 'paused' }),
      makeEventTrackedContext(makeEvent()),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
    expect(decision.trace.skip_reason).toBe('campaign_not_running');
  });

  test('event campaign on app_boot is skipped', () => {
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign(),
      makeAppBootContext(),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
  });

  test('scheduled campaign on event_tracked is skipped', () => {
    const decision = processor.process(
      'test-campaign',
      makeScheduledCampaign(),
      makeEventTrackedContext(makeEvent()),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
  });

  test('event campaign on event_tracked proceeds', () => {
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign(),
      makeEventTrackedContext(makeEvent()),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('trigger');
  });

  test('recurring campaign on app_foreground proceeds', () => {
    const decision = processor.process(
      'test-campaign',
      makeRecurringCampaign(),
      { trigger: 'app_foreground', now: '2026-01-15T10:00:00.000Z' },
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('trigger');
  });

  test('global freq cap exceeded', () => {
    const now = '2026-01-15T10:00:00.000Z';
    const snapshot = makeSnapshotWithHistory([
      { triggered_at: '2026-01-15T09:55:00.000Z' },
      { triggered_at: '2026-01-15T09:56:00.000Z' },
      { triggered_at: '2026-01-15T09:57:00.000Z' },
    ]);
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign(),
      makeEventTrackedContext(makeEvent(), now),
      snapshot,
      makeDeps({ frequency_cap: { max_count: 3, window_seconds: 3600 } }),
    );
    expect(decision.action).toBe('skip');
    expect(decision.trace.skip_reason).toBe('campaign_frequency_cap_exceeded');
  });

  test('within global freq cap proceeds', () => {
    const now = '2026-01-15T10:00:00.000Z';
    const snapshot = makeSnapshotWithHistory([
      { triggered_at: '2026-01-15T09:55:00.000Z' },
    ]);
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign(),
      makeEventTrackedContext(makeEvent(), now),
      snapshot,
      makeDeps({ frequency_cap: { max_count: 3, window_seconds: 3600 } }),
    );
    expect(decision.action).toBe('trigger');
  });

  test('campaign freq cap exceeded', () => {
    const now = '2026-01-15T10:00:00.000Z';
    const snapshot = makeSnapshotWithHistory([
      { campaign_id: 'test-campaign', triggered_at: '2026-01-15T09:55:00.000Z' },
      { campaign_id: 'test-campaign', triggered_at: '2026-01-15T09:56:00.000Z' },
    ]);
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign({ frequency_cap: { max_count: 2, window_seconds: 3600 } }),
      makeEventTrackedContext(makeEvent(), now),
      snapshot,
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
    expect(decision.trace.skip_reason).toBe('campaign_frequency_cap_exceeded');
  });

  test('only counts this campaigns history for campaign cap', () => {
    const now = '2026-01-15T10:00:00.000Z';
    const snapshot = makeSnapshotWithHistory([
      { campaign_id: 'other-campaign', triggered_at: '2026-01-15T09:55:00.000Z' },
      { campaign_id: 'other-campaign', triggered_at: '2026-01-15T09:56:00.000Z' },
    ]);
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign({ frequency_cap: { max_count: 2, window_seconds: 3600 } }),
      makeEventTrackedContext(makeEvent(), now),
      snapshot,
      makeDeps(),
    );
    expect(decision.action).toBe('trigger');
  });

  test('recurring with future pending is skipped', () => {
    const now = '2026-01-15T10:00:00.000Z';
    const snapshot = makeSnapshotWithQueuedMessages([
      {
        message_id: 'msg-001',
        campaign_id: 'test-campaign',
        execute_at: '2026-01-15T11:00:00.000Z',
        trigger_type: 'recurring',
        created_at: '2026-01-15T09:00:00.000Z',
      },
    ]);
    const decision = processor.process(
      'test-campaign',
      makeRecurringCampaign(),
      { trigger: 'app_boot', now },
      snapshot,
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
  });

  test('matching event conditions triggers with delay', () => {
    const campaign = makeEventCampaign({
      trigger: {
        type: 'event',
        event: {
          trigger_event: {
            connector: 'and',
            conditions: [{ field: 'name', operator: 'equal', values: ['button_clicked'] }],
          },
          delay_seconds: 60,
        },
      },
    });
    const now = '2026-01-15T10:00:00.000Z';
    const decision = processor.process(
      'test-campaign',
      campaign,
      makeEventTrackedContext(makeEvent(), now),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('trigger');
    expect(decision.queued_message?.execute_at).toBe('2026-01-15T10:01:00.000Z');
  });

  test('non-matching conditions returns trigger_event_not_matched', () => {
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign(),
      makeEventTrackedContext(makeEvent({ name: 'wrong_event' })),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
    expect(decision.trace.skip_reason).toBe('trigger_event_not_matched');
  });

  test('event trigger without event in context is skipped', () => {
    const context: TriggerContext = { trigger: 'event_tracked', now: '2026-01-15T10:00:00.000Z' };
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign(),
      context,
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
    expect(decision.trace.skip_reason).toBe('trigger_event_not_matched');
  });

  test('future scheduled execute_at triggers', () => {
    const now = '2026-01-15T10:00:00.000Z';
    const decision = processor.process(
      'test-campaign',
      makeScheduledCampaign(),
      makeAppBootContext(now),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('trigger');
  });

  test('past scheduled execute_at is skipped', () => {
    const now = '2026-01-25T10:00:00.000Z';
    const decision = processor.process(
      'test-campaign',
      makeScheduledCampaign(),
      makeAppBootContext(now),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
  });

  test('hourly recurrence computes next', () => {
    const campaign = makeRecurringCampaign({
      trigger: {
        type: 'recurring',
        recurring: { rule: { type: 'hourly', interval: 2 } },
      },
    });
    const now = '2026-01-15T10:00:00.000Z';
    const decision = processor.process(
      'test-campaign',
      campaign,
      makeAppBootContext(now),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('trigger');
    expect(decision.queued_message).toBeDefined();
  });

  test('daily recurrence with time_of_day', () => {
    const campaign = makeRecurringCampaign({
      trigger: {
        type: 'recurring',
        recurring: {
          rule: { type: 'daily', interval: 1, time_of_day: { hour: 14, minute: 30 } },
        },
      },
    });
    const now = '2026-01-15T10:00:00.000Z';
    const decision = processor.process(
      'test-campaign',
      campaign,
      makeAppBootContext(now),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('trigger');
    expect(decision.queued_message?.execute_at).toContain('14:30:00');
  });

  test('weekly recurrence with specific days', () => {
    const campaign = makeRecurringCampaign({
      trigger: {
        type: 'recurring',
        recurring: {
          rule: {
            type: 'weekly',
            interval: 1,
            weekly_rule: { days_of_week: ['monday', 'wednesday', 'friday'] },
            time_of_day: { hour: 9, minute: 0 },
          },
        },
      },
    });
    const now = '2026-01-15T08:00:00.000Z';
    const decision = processor.process(
      'test-campaign',
      campaign,
      makeAppBootContext(now),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('trigger');
  });

  test('recurring with end_at boundary', () => {
    const campaign = makeRecurringCampaign({
      trigger: {
        type: 'recurring',
        recurring: {
          start_at: '2026-01-01T00:00:00.000Z',
          end_at: '2026-01-10T00:00:00.000Z',
          rule: { type: 'daily', interval: 1, time_of_day: { hour: 9, minute: 0 } },
        },
      },
    });
    const now = '2026-01-15T10:00:00.000Z';
    const decision = processor.process(
      'test-campaign',
      campaign,
      makeAppBootContext(now),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
  });

  test('recurring with lastScheduledAt advances by 60s', () => {
    const campaign = makeRecurringCampaign({
      trigger: {
        type: 'recurring',
        recurring: { rule: { type: 'hourly', interval: 1 } },
      },
    });
    const now = '2026-01-15T10:00:00.000Z';
    const snapshot = makeEmptySnapshot();
    snapshot.campaign_states.push({
      campaign_id: 'test-campaign',
      triggered: false,
      delivery_count: 1,
      recurring_last_scheduled_at: '2026-01-15T10:00:00.000Z',
      recurring_anchor_at: '2026-01-15T09:00:00.000Z',
    });
    const decision = processor.process(
      'test-campaign',
      campaign,
      makeAppBootContext(now),
      snapshot,
      makeDeps(),
    );
    expect(decision.action).toBe('trigger');
    expect(decision.queued_message).toBeDefined();
    // Should schedule for 11:00 (next hourly after 10:00 + 60s)
    expect(decision.queued_message!.execute_at).toContain('11:00:00');
  });

  test('duplicate campaign+execute_at is skipped', () => {
    const now = '2026-01-15T10:00:00.000Z';
    const campaign = makeEventCampaign();
    const expectedExecuteAt = now;
    const snapshot = makeSnapshotWithQueuedMessages([
      {
        message_id: 'existing-msg',
        campaign_id: 'test-campaign',
        execute_at: expectedExecuteAt,
        trigger_type: 'event',
        created_at: now,
      },
    ]);
    const decision = processor.process(
      'test-campaign',
      campaign,
      makeEventTrackedContext(makeEvent(), now),
      snapshot,
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
  });

  test('DnD blocks with campaign_do_not_disturb_blocked', () => {
    // Use UTC hour 14 for now, DnD window 13-16
    const now = '2026-01-15T14:00:00.000Z';
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign(),
      makeEventTrackedContext(makeEvent({ created_at: now }), now),
      makeEmptySnapshot(),
      makeDeps({ do_not_disturb: { start_hour: 13, end_hour: 16 } }),
    );
    expect(decision.action).toBe('skip');
    expect(decision.trace.skip_reason).toBe('campaign_do_not_disturb_blocked');
  });

  test('successful trigger creates QueuedMessage with rendered content', () => {
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign(),
      makeEventTrackedContext(makeEvent({ properties: { username: 'Alice' } })),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('trigger');
    expect(decision.queued_message?.content.title).toBe('Hello Alice');
    expect(decision.queued_message?.content.body).toBe('You clicked the button!');
  });

  test('template variables from event.properties rendered', () => {
    const campaign = makeEventCampaign({
      message: {
        channel_type: 'app_push',
        content: {
          title: 'Hi {{name}}',
          body: 'Score: {{score}}',
        },
      },
    });
    const event = makeEvent({ properties: { name: 'Bob', score: 99 } });
    const decision = processor.process(
      'test-campaign',
      campaign,
      makeEventTrackedContext(event),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.queued_message?.content.title).toBe('Hi Bob');
    expect(decision.queued_message?.content.body).toBe('Score: 99');
  });

  test('event campaign with missing trigger.event config is skipped', () => {
    const decision = processor.process(
      'test-campaign',
      makeEventCampaign({ trigger: { type: 'event' } as any }),
      makeEventTrackedContext(makeEvent()),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
    expect(decision.trace.skip_reason).toBe('trigger_event_not_matched');
  });

  test('scheduled campaign with missing scheduled config is skipped', () => {
    const decision = processor.process(
      'test-campaign',
      makeScheduledCampaign({ trigger: { type: 'scheduled' } as any }),
      makeAppBootContext(),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
  });

  test('recurring campaign with missing recurring config is skipped', () => {
    const decision = processor.process(
      'test-campaign',
      makeRecurringCampaign({ trigger: { type: 'recurring' } as any }),
      makeAppBootContext(),
      makeEmptySnapshot(),
      makeDeps(),
    );
    expect(decision.action).toBe('skip');
  });
});
