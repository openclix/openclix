import { describe, test, expect } from 'bun:test';
import { CampaignStateService } from '../templates/react-native/domain/CampaignStateService';
import {
  makeEmptySnapshot,
  makeQueuedMessage,
} from './helpers/fixtures';
import type {
  CampaignStateSnapshot,
  QueuedMessage,
  TriggerType,
} from '../templates/react-native/domain/OpenClixTypes';

const service = new CampaignStateService();

function applyEvent(
  snapshot: CampaignStateSnapshot,
  opts?: {
    campaign_id?: string;
    trigger_type?: TriggerType;
    queued_message?: QueuedMessage;
    now?: string;
    scheduled_for?: string;
  },
) {
  service.applyQueuedMessage({
    snapshot,
    campaign_id: opts?.campaign_id ?? 'test-campaign',
    trigger_type: opts?.trigger_type ?? 'event',
    queued_message: opts?.queued_message ?? makeQueuedMessage(),
    now: opts?.now ?? '2026-01-15T10:00:00.000Z',
    scheduled_for: opts?.scheduled_for,
    max_trigger_history: 100,
  });
}

describe('CampaignStateService', () => {
  describe('applyQueuedMessage', () => {
    test('creates new campaign state when none exists', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot);
      expect(snapshot.campaign_states).toHaveLength(1);
      expect(snapshot.campaign_states[0].campaign_id).toBe('test-campaign');
    });

    test('increments delivery_count', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot);
      applyEvent(snapshot, {
        queued_message: makeQueuedMessage({ id: 'msg-002' }),
        now: '2026-01-15T10:01:00.000Z',
      });
      expect(snapshot.campaign_states[0].delivery_count).toBe(2);
    });

    test('sets triggered=true for non-recurring (event)', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot, { trigger_type: 'event' });
      expect(snapshot.campaign_states[0].triggered).toBe(true);
    });

    test('sets triggered=true for non-recurring (scheduled)', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot, { trigger_type: 'scheduled' });
      expect(snapshot.campaign_states[0].triggered).toBe(true);
    });

    test('sets triggered=false for recurring', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot, { trigger_type: 'recurring' });
      expect(snapshot.campaign_states[0].triggered).toBe(false);
    });

    test('sets recurring_anchor_at on first trigger only', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot, {
        trigger_type: 'recurring',
        scheduled_for: '2026-01-15T09:00:00.000Z',
      });
      const firstAnchor = snapshot.campaign_states[0].recurring_anchor_at;
      expect(firstAnchor).toBe('2026-01-15T09:00:00.000Z');

      applyEvent(snapshot, {
        trigger_type: 'recurring',
        scheduled_for: '2026-01-16T09:00:00.000Z',
        now: '2026-01-16T09:00:00.000Z',
        queued_message: makeQueuedMessage({ id: 'msg-002' }),
      });
      expect(snapshot.campaign_states[0].recurring_anchor_at).toBe(firstAnchor);
    });

    test('updates recurring_last_scheduled_at each time', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot, {
        trigger_type: 'recurring',
        scheduled_for: '2026-01-15T09:00:00.000Z',
      });
      expect(snapshot.campaign_states[0].recurring_last_scheduled_at).toBe(
        '2026-01-15T09:00:00.000Z',
      );

      applyEvent(snapshot, {
        trigger_type: 'recurring',
        scheduled_for: '2026-01-16T09:00:00.000Z',
        now: '2026-01-16T09:00:00.000Z',
        queued_message: makeQueuedMessage({ id: 'msg-002' }),
      });
      expect(snapshot.campaign_states[0].recurring_last_scheduled_at).toBe(
        '2026-01-16T09:00:00.000Z',
      );
    });

    test('sets last_triggered_at to now', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot, { now: '2026-01-15T12:30:00.000Z' });
      expect(snapshot.campaign_states[0].last_triggered_at).toBe(
        '2026-01-15T12:30:00.000Z',
      );
    });

    test('appends to trigger_history', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot);
      expect(snapshot.trigger_history).toHaveLength(1);
      expect(snapshot.trigger_history[0].campaign_id).toBe('test-campaign');
    });

    test('trims trigger_history when exceeding max', () => {
      const snapshot = makeEmptySnapshot();
      for (let i = 0; i < 5; i++) {
        service.applyQueuedMessage({
          snapshot,
          campaign_id: 'test-campaign',
          trigger_type: 'event',
          queued_message: makeQueuedMessage({ id: `msg-${i}` }),
          now: `2026-01-15T10:0${i}:00.000Z`,
          max_trigger_history: 3,
        });
      }
      expect(snapshot.trigger_history).toHaveLength(3);
      expect(snapshot.trigger_history[0].triggered_at).toBe('2026-01-15T10:02:00.000Z');
    });

    test('upserts queued_message record', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot);
      expect(snapshot.queued_messages).toHaveLength(1);
      expect(snapshot.queued_messages[0].message_id).toBe('msg-001');
    });
  });

  describe('reconcileQueuedMessages', () => {
    test('retains messages present in scheduler', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot);
      const pending = [makeQueuedMessage()];
      service.reconcileQueuedMessages({
        snapshot,
        scheduler_pending_messages: pending,
        resolve_trigger_type: () => 'event',
      });
      expect(snapshot.queued_messages).toHaveLength(1);
    });

    test('removes messages absent from scheduler', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot);
      service.reconcileQueuedMessages({
        snapshot,
        scheduler_pending_messages: [],
        resolve_trigger_type: () => 'event',
      });
      expect(snapshot.queued_messages).toHaveLength(0);
    });

    test('preserves existing created_at', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot);
      const originalCreatedAt = snapshot.queued_messages[0].created_at;
      const pendingMsg = makeQueuedMessage({ created_at: '2026-02-01T00:00:00.000Z' });
      service.reconcileQueuedMessages({
        snapshot,
        scheduler_pending_messages: [pendingMsg],
        resolve_trigger_type: () => 'event',
      });
      expect(snapshot.queued_messages[0].created_at).toBe(originalCreatedAt);
    });

    test('infers trigger_type from callback', () => {
      const snapshot = makeEmptySnapshot();
      const pending = [makeQueuedMessage({ campaign_id: 'recurring-camp' })];
      service.reconcileQueuedMessages({
        snapshot,
        scheduler_pending_messages: pending,
        resolve_trigger_type: (id) => (id === 'recurring-camp' ? 'recurring' : undefined),
      });
      expect(snapshot.queued_messages[0].trigger_type).toBe('recurring');
    });
  });

  describe('removeQueuedMessage / markCampaignUntriggered', () => {
    test('removes message by id', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot);
      expect(snapshot.queued_messages).toHaveLength(1);
      service.removeQueuedMessage(snapshot, 'msg-001');
      expect(snapshot.queued_messages).toHaveLength(0);
    });

    test('no-op when message not found', () => {
      const snapshot = makeEmptySnapshot();
      service.removeQueuedMessage(snapshot, 'nonexistent');
      expect(snapshot.queued_messages).toHaveLength(0);
    });

    test('sets triggered=false for existing campaign', () => {
      const snapshot = makeEmptySnapshot();
      applyEvent(snapshot, { trigger_type: 'event' });
      expect(snapshot.campaign_states[0].triggered).toBe(true);
      service.markCampaignUntriggered(snapshot, 'test-campaign');
      expect(snapshot.campaign_states[0].triggered).toBe(false);
    });

    test('no-op when campaign not found', () => {
      const snapshot = makeEmptySnapshot();
      service.markCampaignUntriggered(snapshot, 'nonexistent');
      expect(snapshot.campaign_states).toHaveLength(0);
    });
  });
});
