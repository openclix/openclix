import type {
  Event,
  CampaignStateSnapshot,
  Campaign,
  Config,
  TriggerContext,
  QueuedMessage,
  CampaignTriggerHistory,
  CampaignQueuedMessage,
} from '../../templates/react-native/domain/OpenClixTypes';

export function makeEvent(overrides?: Partial<Event>): Event {
  return {
    id: 'evt-001',
    name: 'button_clicked',
    source_type: 'app',
    properties: {},
    created_at: '2026-01-15T10:00:00.000Z',
    ...overrides,
  };
}

export function makeEmptySnapshot(now?: string): CampaignStateSnapshot {
  return {
    campaign_states: [],
    queued_messages: [],
    trigger_history: [],
    updated_at: now ?? '2026-01-15T10:00:00.000Z',
  };
}

export function makeSnapshotWithHistory(
  entries: CampaignTriggerHistory[],
): CampaignStateSnapshot {
  return {
    ...makeEmptySnapshot(),
    trigger_history: entries,
  };
}

export function makeSnapshotWithQueuedMessages(
  messages: CampaignQueuedMessage[],
): CampaignStateSnapshot {
  return {
    ...makeEmptySnapshot(),
    queued_messages: messages,
  };
}

export function makeEventCampaign(overrides?: Partial<Campaign>): Campaign {
  return {
    name: 'Test Event Campaign',
    type: 'campaign',
    description: 'A test event-triggered campaign',
    status: 'running',
    trigger: {
      type: 'event',
      event: {
        trigger_event: {
          connector: 'and',
          conditions: [
            { field: 'name', operator: 'equal', values: ['button_clicked'] },
          ],
        },
      },
    },
    message: {
      channel_type: 'app_push',
      content: {
        title: 'Hello {{username}}',
        body: 'You clicked the button!',
      },
    },
    ...overrides,
  };
}

export function makeScheduledCampaign(overrides?: Partial<Campaign>): Campaign {
  return {
    name: 'Test Scheduled Campaign',
    type: 'campaign',
    description: 'A test scheduled campaign',
    status: 'running',
    trigger: {
      type: 'scheduled',
      scheduled: {
        execute_at: '2026-01-20T09:00:00.000Z',
      },
    },
    message: {
      channel_type: 'app_push',
      content: {
        title: 'Scheduled Notification',
        body: 'This is a scheduled message.',
      },
    },
    ...overrides,
  };
}

export function makeRecurringCampaign(overrides?: Partial<Campaign>): Campaign {
  return {
    name: 'Test Recurring Campaign',
    type: 'campaign',
    description: 'A test recurring campaign',
    status: 'running',
    trigger: {
      type: 'recurring',
      recurring: {
        rule: {
          type: 'daily',
          interval: 1,
          time_of_day: { hour: 9, minute: 0 },
        },
      },
    },
    message: {
      channel_type: 'app_push',
      content: {
        title: 'Daily Reminder',
        body: 'Time for your daily check-in!',
      },
    },
    ...overrides,
  };
}

export function makeMinimalConfig(overrides?: Partial<Config>): Config {
  return {
    schema_version: 'openclix/config/v1',
    config_version: '1.0.0',
    campaigns: {
      'test-campaign': makeEventCampaign(),
    },
    ...overrides,
  };
}

export function makeEventTrackedContext(
  event: Event,
  now?: string,
): TriggerContext {
  return {
    trigger: 'event_tracked',
    event,
    now: now ?? event.created_at,
  };
}

export function makeAppBootContext(now?: string): TriggerContext {
  return {
    trigger: 'app_boot',
    now: now ?? '2026-01-15T10:00:00.000Z',
  };
}

export function makeQueuedMessage(overrides?: Partial<QueuedMessage>): QueuedMessage {
  return {
    id: 'msg-001',
    campaign_id: 'test-campaign',
    channel_type: 'app_push',
    status: 'scheduled',
    content: {
      title: 'Test Title',
      body: 'Test Body',
    },
    execute_at: '2026-01-15T10:05:00.000Z',
    created_at: '2026-01-15T10:00:00.000Z',
    ...overrides,
  };
}
