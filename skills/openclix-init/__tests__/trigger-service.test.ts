import { describe, test, expect } from 'bun:test';
import { TriggerService } from '../templates/react-native/engine/TriggerService';
import {
  makeMinimalConfig,
  makeEventCampaign,
  makeScheduledCampaign,
  makeRecurringCampaign,
  makeEvent,
  makeQueuedMessage,
  makeEmptySnapshot,
} from './helpers/fixtures';
import {
  createMockLogger,
  createMockScheduler,
  createMockRepository,
  createMockRecordEvent,
} from './helpers/mocks';
import type { TriggerServiceDependencies } from '../templates/react-native/engine/TriggerService';
import type { TriggerContext, Config } from '../templates/react-native/domain/OpenClixTypes';

function makeTriggerService(overrides?: Partial<TriggerServiceDependencies>) {
  const logger = createMockLogger();
  const scheduler = createMockScheduler();
  const repository = createMockRepository();
  const recordEvent = createMockRecordEvent();
  const finalRecordEvent =
    overrides && 'recordEvent' in overrides
      ? overrides.recordEvent
      : recordEvent;
  const deps: TriggerServiceDependencies = {
    campaignStateRepository: overrides?.campaignStateRepository ?? repository,
    messageScheduler: (overrides?.messageScheduler ?? scheduler) as any,
    clock: overrides?.clock ?? { now: () => '2026-01-15T10:00:00.000Z' },
    logger: overrides?.logger ?? logger,
    recordEvent: finalRecordEvent,
  };
  const service = new TriggerService(deps);
  return { service, logger: deps.logger as ReturnType<typeof createMockLogger>, scheduler: (deps.messageScheduler as unknown) as ReturnType<typeof createMockScheduler>, repository: (deps.campaignStateRepository as unknown) as ReturnType<typeof createMockRepository>, recordEvent: deps.recordEvent as ReturnType<typeof createMockRecordEvent> };
}

describe('TriggerService', () => {
  test('no config returns empty TriggerResult', async () => {
    const { service } = makeTriggerService();
    const result = await service.trigger({
      trigger: 'app_boot',
      now: '2026-01-15T10:00:00.000Z',
    });
    expect(result.traces).toHaveLength(0);
    expect(result.queued_messages).toHaveLength(0);
  });

  test('replaceConfig makes campaigns available', async () => {
    const { service } = makeTriggerService();
    const config = makeMinimalConfig();
    service.replaceConfig(config);
    expect(service.getConfig()).toBe(config);
  });

  test('event_tracked with matching event schedules message', async () => {
    const { service, scheduler } = makeTriggerService();
    service.replaceConfig(makeMinimalConfig());
    const event = makeEvent();
    const result = await service.trigger({
      trigger: 'event_tracked',
      event,
      now: '2026-01-15T10:00:00.000Z',
    });
    expect(result.queued_messages).toHaveLength(1);
    expect(scheduler.scheduledMessages).toHaveLength(1);
  });

  test('event_tracked with non-matching returns skip trace', async () => {
    const { service } = makeTriggerService();
    service.replaceConfig(makeMinimalConfig());
    const result = await service.trigger({
      trigger: 'event_tracked',
      event: makeEvent({ name: 'wrong_event' }),
      now: '2026-01-15T10:00:00.000Z',
    });
    expect(result.queued_messages).toHaveLength(0);
    expect(result.traces.some((t) => t.result === 'skipped')).toBe(true);
  });

  test('app_boot triggers scheduled (not event)', async () => {
    const { service, scheduler } = makeTriggerService();
    const config = makeMinimalConfig({
      campaigns: {
        'scheduled-camp': makeScheduledCampaign(),
      },
    });
    service.replaceConfig(config);
    const result = await service.trigger({
      trigger: 'app_boot',
      now: '2026-01-15T10:00:00.000Z',
    });
    expect(result.queued_messages).toHaveLength(1);
  });

  test('app_boot reconciles queued messages from scheduler', async () => {
    const pendingMsg = makeQueuedMessage({ campaign_id: 'test-campaign' });
    const scheduler = createMockScheduler({ pendingMessages: [pendingMsg] });
    const repository = createMockRepository();
    // Pre-populate snapshot with a stale message that's not in scheduler
    repository.snapshot.queued_messages.push({
      message_id: 'stale-msg',
      campaign_id: 'test-campaign',
      execute_at: '2026-01-15T10:00:00.000Z',
      trigger_type: 'event',
      created_at: '2026-01-15T09:00:00.000Z',
    });
    const { service } = makeTriggerService({
      messageScheduler: scheduler,
      campaignStateRepository: repository,
    });
    service.replaceConfig(makeMinimalConfig());
    await service.trigger({ trigger: 'app_boot', now: '2026-01-15T10:00:00.000Z' });
    // After reconcile, only the pending msg from scheduler should remain
    const saved = repository.savedSnapshots;
    expect(saved.length).toBeGreaterThan(0);
    const lastSnapshot = saved[saved.length - 1];
    const msgIds = lastSnapshot.queued_messages.map((m) => m.message_id);
    expect(msgIds).toContain('msg-001');
    expect(msgIds).not.toContain('stale-msg');
  });

  test('cancel event matching cancels pending and emits cancelled', async () => {
    const repository = createMockRepository();
    const pendingMsg = makeQueuedMessage({
      id: 'pending-msg',
      campaign_id: 'cancel-camp',
      created_at: '2026-01-15T09:00:00.000Z',
      execute_at: '2026-01-15T11:00:00.000Z',
    });
    repository.snapshot.queued_messages.push({
      message_id: 'pending-msg',
      campaign_id: 'cancel-camp',
      execute_at: '2026-01-15T11:00:00.000Z',
      trigger_type: 'event',
      created_at: '2026-01-15T09:00:00.000Z',
    });
    const scheduler = createMockScheduler({ pendingMessages: [pendingMsg] });
    const recordEvent = createMockRecordEvent();
    const { service } = makeTriggerService({
      campaignStateRepository: repository,
      messageScheduler: scheduler,
      recordEvent,
    });
    const config: Config = {
      schema_version: 'openclix/config/v1',
      config_version: '1.0.0',
      campaigns: {
        'cancel-camp': makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: {
                connector: 'and',
                conditions: [{ field: 'name', operator: 'equal', values: ['purchase'] }],
              },
              cancel_event: {
                connector: 'and',
                conditions: [{ field: 'name', operator: 'equal', values: ['cancel_action'] }],
              },
            },
          },
        }),
      },
    };
    service.replaceConfig(config);
    const cancelEvent = makeEvent({
      name: 'cancel_action',
      created_at: '2026-01-15T10:00:00.000Z',
    });
    const result = await service.trigger({
      trigger: 'event_tracked',
      event: cancelEvent,
      now: '2026-01-15T10:00:00.000Z',
    });
    expect(scheduler.cancelledIds).toContain('pending-msg');
    const cancelTraces = result.traces.filter((t) => t.action === 'cancel_message');
    expect(cancelTraces).toHaveLength(1);
    expect(recordEvent.recordedEvents.some((e) => e.name === 'openclix.message.cancelled')).toBe(true);
  });

  test('cancellation only within window (created_at to execute_at)', async () => {
    const repository = createMockRepository();
    repository.snapshot.queued_messages.push({
      message_id: 'pending-msg',
      campaign_id: 'cancel-camp',
      execute_at: '2026-01-15T11:00:00.000Z',
      trigger_type: 'event',
      created_at: '2026-01-15T09:00:00.000Z',
    });
    const scheduler = createMockScheduler();
    const { service } = makeTriggerService({
      campaignStateRepository: repository,
      messageScheduler: scheduler,
    });
    const config: Config = {
      schema_version: 'openclix/config/v1',
      config_version: '1.0.0',
      campaigns: {
        'cancel-camp': makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: {
                connector: 'and',
                conditions: [{ field: 'name', operator: 'equal', values: ['purchase'] }],
              },
              cancel_event: {
                connector: 'and',
                conditions: [{ field: 'name', operator: 'equal', values: ['cancel_action'] }],
              },
            },
          },
        }),
      },
    };
    service.replaceConfig(config);
    // Event outside window (after execute_at)
    const lateEvent = makeEvent({
      name: 'cancel_action',
      created_at: '2026-01-15T12:00:00.000Z',
    });
    await service.trigger({
      trigger: 'event_tracked',
      event: lateEvent,
      now: '2026-01-15T12:00:00.000Z',
    });
    expect(scheduler.cancelledIds).toHaveLength(0);
  });

  test('markCampaignUntriggered called after cancellation', async () => {
    const repository = createMockRepository();
    repository.snapshot.queued_messages.push({
      message_id: 'pending-msg',
      campaign_id: 'cancel-camp',
      execute_at: '2026-01-15T11:00:00.000Z',
      trigger_type: 'event',
      created_at: '2026-01-15T09:00:00.000Z',
    });
    repository.snapshot.campaign_states.push({
      campaign_id: 'cancel-camp',
      triggered: true,
      delivery_count: 1,
    });
    const scheduler = createMockScheduler();
    const { service } = makeTriggerService({
      campaignStateRepository: repository,
      messageScheduler: scheduler,
    });
    const config: Config = {
      schema_version: 'openclix/config/v1',
      config_version: '1.0.0',
      campaigns: {
        'cancel-camp': makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: {
                connector: 'and',
                conditions: [{ field: 'name', operator: 'equal', values: ['purchase'] }],
              },
              cancel_event: {
                connector: 'and',
                conditions: [{ field: 'name', operator: 'equal', values: ['cancel_action'] }],
              },
            },
          },
        }),
      },
    };
    service.replaceConfig(config);
    await service.trigger({
      trigger: 'event_tracked',
      event: makeEvent({ name: 'cancel_action', created_at: '2026-01-15T10:00:00.000Z' }),
      now: '2026-01-15T10:00:00.000Z',
    });
    const saved = repository.savedSnapshots;
    expect(saved.length).toBeGreaterThan(0);
    const lastSnapshot = saved[saved.length - 1];
    const campaignState = lastSnapshot.campaign_states.find((s) => s.campaign_id === 'cancel-camp');
    expect(campaignState?.triggered).toBe(false);
  });

  test('scheduler.schedule failure emits message.failed', async () => {
    const scheduler = createMockScheduler({ scheduleError: new Error('schedule failed') });
    const recordEvent = createMockRecordEvent();
    const { service } = makeTriggerService({
      messageScheduler: scheduler,
      recordEvent,
    });
    service.replaceConfig(makeMinimalConfig());
    const result = await service.trigger({
      trigger: 'event_tracked',
      event: makeEvent(),
      now: '2026-01-15T10:00:00.000Z',
    });
    expect(result.queued_messages).toHaveLength(0);
    expect(recordEvent.recordedEvents.some((e) => e.name === 'openclix.message.failed')).toBe(true);
  });

  test('continues processing after scheduler error', async () => {
    const scheduler = createMockScheduler({ scheduleError: new Error('fail') });
    const { service } = makeTriggerService({ messageScheduler: scheduler });
    const config = makeMinimalConfig({
      campaigns: {
        'camp-a': makeEventCampaign(),
        'camp-b': makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: {
                connector: 'and',
                conditions: [{ field: 'name', operator: 'equal', values: ['button_clicked'] }],
              },
            },
          },
        }),
      },
    });
    service.replaceConfig(config);
    const result = await service.trigger({
      trigger: 'event_tracked',
      event: makeEvent(),
      now: '2026-01-15T10:00:00.000Z',
    });
    // Both should have traces even though scheduling failed
    expect(result.traces.length).toBeGreaterThanOrEqual(2);
  });

  test('saveSnapshot called after processing', async () => {
    const repository = createMockRepository();
    const { service } = makeTriggerService({ campaignStateRepository: repository });
    service.replaceConfig(makeMinimalConfig());
    await service.trigger({
      trigger: 'event_tracked',
      event: makeEvent(),
      now: '2026-01-15T10:00:00.000Z',
    });
    expect(repository.savedSnapshots.length).toBeGreaterThan(0);
  });

  test('saveSnapshot failure logged, does not throw', async () => {
    const repository = createMockRepository();
    repository.saveError = new Error('save failed');
    const logger = createMockLogger();
    const { service } = makeTriggerService({
      campaignStateRepository: repository,
      logger,
    });
    service.replaceConfig(makeMinimalConfig());
    // Should not throw
    await service.trigger({
      trigger: 'event_tracked',
      event: makeEvent(),
      now: '2026-01-15T10:00:00.000Z',
    });
    expect(logger.errorCalls.some((c) => String(c[0]).includes('Failed to persist'))).toBe(true);
  });

  test('openclix.message.scheduled emitted on success', async () => {
    const recordEvent = createMockRecordEvent();
    const { service } = makeTriggerService({ recordEvent });
    service.replaceConfig(makeMinimalConfig());
    await service.trigger({
      trigger: 'event_tracked',
      event: makeEvent(),
      now: '2026-01-15T10:00:00.000Z',
    });
    expect(recordEvent.recordedEvents.some((e) => e.name === 'openclix.message.scheduled')).toBe(true);
  });

  test('recordEvent not called when callback absent', async () => {
    const { service } = makeTriggerService({ recordEvent: undefined });
    service.replaceConfig(makeMinimalConfig());
    // Should not throw
    await service.trigger({
      trigger: 'event_tracked',
      event: makeEvent(),
      now: '2026-01-15T10:00:00.000Z',
    });
  });

  test('concurrent trigger() calls are serialized', async () => {
    const executionOrder: number[] = [];
    let resolveFirst: (() => void) | undefined;
    const blockingScheduler = createMockScheduler();
    const originalSchedule = blockingScheduler.schedule.bind(blockingScheduler);
    let callCount = 0;
    blockingScheduler.schedule = async (record) => {
      callCount++;
      if (callCount === 1) {
        executionOrder.push(1);
        // Block the first call until we release it
        await new Promise<void>((resolve) => { resolveFirst = resolve; });
      } else {
        executionOrder.push(2);
      }
      return originalSchedule(record);
    };
    const { service } = makeTriggerService({ messageScheduler: blockingScheduler });
    service.replaceConfig(makeMinimalConfig());
    const event = makeEvent();
    const p1 = service.trigger({ trigger: 'event_tracked', event, now: '2026-01-15T10:00:00.000Z' });
    const p2 = service.trigger({ trigger: 'event_tracked', event, now: '2026-01-15T10:00:01.000Z' });
    // Give p2 a chance to start if it were not serialized
    await new Promise((r) => setTimeout(r, 10));
    // Only call 1 should have started scheduling
    expect(executionOrder).toEqual([1]);
    // Release the first call
    resolveFirst!();
    const [r1, r2] = await Promise.all([p1, p2]);
    // After first completes, second should run — both in order
    expect(executionOrder).toEqual([1, 2]);
    expect(r1.evaluated_at).toBe('2026-01-15T10:00:00.000Z');
    expect(r2.evaluated_at).toBe('2026-01-15T10:00:01.000Z');
  });

  test('listPending failure during reconciliation warns and continues', async () => {
    const scheduler = createMockScheduler();
    // Override listPending to throw
    scheduler.listPending = async () => { throw new Error('listPending failed'); };
    const logger = createMockLogger();
    const { service } = makeTriggerService({
      messageScheduler: scheduler,
      logger,
    });
    service.replaceConfig(makeMinimalConfig({
      campaigns: { 'sched-camp': makeScheduledCampaign() },
    }));
    // app_boot triggers reconciliation
    const result = await service.trigger({
      trigger: 'app_boot',
      now: '2026-01-15T10:00:00.000Z',
    });
    expect(result.evaluated_at).toBe('2026-01-15T10:00:00.000Z');
    expect(logger.warnCalls.some((c) => String(c[0]).includes('reconcile'))).toBe(true);
  });

  test('cancel failure emits message.failed and continues', async () => {
    const repository = createMockRepository();
    repository.snapshot.queued_messages.push({
      message_id: 'pending-msg',
      campaign_id: 'cancel-camp',
      execute_at: '2026-01-15T11:00:00.000Z',
      trigger_type: 'event',
      created_at: '2026-01-15T09:00:00.000Z',
    });
    const scheduler = createMockScheduler();
    // Override cancel to throw
    scheduler.cancel = async () => { throw new Error('cancel failed'); };
    const recordEvent = createMockRecordEvent();
    const logger = createMockLogger();
    const { service } = makeTriggerService({
      campaignStateRepository: repository,
      messageScheduler: scheduler,
      recordEvent,
      logger,
    });
    const config = makeMinimalConfig({
      campaigns: {
        'cancel-camp': makeEventCampaign({
          trigger: {
            type: 'event',
            event: {
              trigger_event: {
                connector: 'and',
                conditions: [{ field: 'name', operator: 'equal', values: ['purchase'] }],
              },
              cancel_event: {
                connector: 'and',
                conditions: [{ field: 'name', operator: 'equal', values: ['do_cancel'] }],
              },
            },
          },
        }),
      },
    });
    service.replaceConfig(config);
    const result = await service.trigger({
      trigger: 'event_tracked',
      event: makeEvent({ name: 'do_cancel', created_at: '2026-01-15T10:00:00.000Z' }),
      now: '2026-01-15T10:00:00.000Z',
    });
    // Should emit message.failed via recordEvent
    expect(recordEvent.recordedEvents.some((e) => e.name === 'openclix.message.failed')).toBe(true);
    // Should warn in logger
    expect(logger.warnCalls.some((c) => String(c[0]).includes('Failed to cancel'))).toBe(true);
    // Should still complete
    expect(result.evaluated_at).toBe('2026-01-15T10:00:00.000Z');
  });
});
