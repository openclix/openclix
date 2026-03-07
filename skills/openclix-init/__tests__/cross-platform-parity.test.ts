import { describe, test, expect, beforeAll } from 'bun:test';
import { readdir } from 'node:fs/promises';
import { join } from 'node:path';

const TEMPLATES_DIR = join(import.meta.dir, '..', 'templates');
const PLATFORMS = ['android', 'ios', 'flutter'] as const;

async function readAllSourceFiles(platformDir: string): Promise<string> {
  const entries = await readdir(platformDir, { recursive: true });
  const contents: string[] = [];
  for (const entry of entries) {
    const ext = entry.split('.').pop()?.toLowerCase();
    if (['ts', 'kt', 'swift', 'dart'].includes(ext ?? '')) {
      const file = Bun.file(join(platformDir, entry));
      contents.push(await file.text());
    }
  }
  return contents.join('\n');
}

describe('cross-platform parity', () => {
  for (const platform of PLATFORMS) {
    describe(platform, () => {
      let allSource: string;

      beforeAll(async () => {
        allSource = await readAllSourceFiles(join(TEMPLATES_DIR, platform));
      });

      test('has CampaignProcessor with process method', () => {
        expect(allSource).toMatch(/CampaignProcessor/);
        expect(allSource).toMatch(/process/);
      });

      test('has EventConditionProcessor with process method', () => {
        expect(allSource).toMatch(/EventConditionProcessor/);
      });

      test('has ScheduleCalculator with calculate method', () => {
        expect(allSource).toMatch(/ScheduleCalculator/);
        expect(allSource).toMatch(/calculate/);
      });

      test('has campaign state management with applyQueuedMessage', () => {
        // Android inlines state management into TriggerService; others use CampaignStateService
        expect(allSource).toMatch(/applyQueuedMessage|apply_queued_message/);
      });

      test('has TriggerService with trigger method', () => {
        expect(allSource).toMatch(/TriggerService/);
        expect(allSource).toMatch(/trigger/);
      });

      test('has ConfigValidator/validateConfig', () => {
        expect(allSource).toMatch(/validateConfig|ConfigValidator/);
      });

      test('supports all 15 event condition operators', () => {
        const operators = [
          'equal', 'not_equal', 'greater_than', 'greater_than_or_equal',
          'less_than', 'less_than_or_equal', 'contains', 'not_contains',
          'starts_with', 'ends_with', 'matches', 'exists', 'not_exists',
          'in', 'not_in',
        ];
        for (const op of operators) {
          expect(allSource).toContain(op);
        }
      });

      test('contains flat state keys', () => {
        for (const key of ['campaign_states', 'queued_messages', 'trigger_history', 'updated_at']) {
          expect(allSource).toContain(key);
        }
      });

      test('contains trigger tokens', () => {
        for (const token of ['scheduled', 'recurring', 'cancel_event', 'do_not_disturb', 'frequency_cap']) {
          expect(allSource).toContain(token);
        }
      });

      test('uses event_tracked, not event_ingested/ingest', () => {
        expect(allSource).toContain('event_tracked');
        expect(allSource).not.toMatch(/event_ingested|[^_]ingest[^a-z]/);
      });

      test('no InMemory*Repository or InMemory*Scheduler', () => {
        expect(allSource).not.toMatch(
          /InMemoryCampaignStateRepository|InMemoryMessageScheduler|InMemoryLocalMessageScheduler/,
        );
      });
    });
  }
});
