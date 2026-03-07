import { describe, test, expect } from 'bun:test';
import { ScheduleCalculator } from '../templates/react-native/domain/CampaignUtils';

const calc = new ScheduleCalculator();

describe('ScheduleCalculator', () => {
  test('returns execute_at from input', () => {
    const result = calc.calculate({
      now: '2026-01-15T10:00:00.000Z',
      execute_at: '2026-01-15T12:00:00.000Z',
    });
    expect(result.execute_at).toBe('2026-01-15T12:00:00.000Z');
    expect(result.skipped).toBe(false);
  });

  test('returns now when no execute_at', () => {
    const result = calc.calculate({ now: '2026-01-15T10:00:00.000Z' });
    expect(result.execute_at).toBe('2026-01-15T10:00:00.000Z');
    expect(result.skipped).toBe(false);
  });

  test('applies delay_seconds when no execute_at', () => {
    const result = calc.calculate({
      now: '2026-01-15T10:00:00.000Z',
      delay_seconds: 300,
    });
    expect(result.execute_at).toBe('2026-01-15T10:05:00.000Z');
    expect(result.skipped).toBe(false);
  });

  test('invalid execute_at falls back to now', () => {
    const result = calc.calculate({
      now: '2026-01-15T10:00:00.000Z',
      execute_at: 'not-a-date',
    });
    expect(result.execute_at).toBe('2026-01-15T10:00:00.000Z');
    expect(result.skipped).toBe(false);
  });

  test('DnD normal window: hour in [start, end) is blocked', () => {
    // execute_at at 14:00 UTC, DnD 13-16
    const result = calc.calculate({
      now: '2026-01-15T14:00:00.000Z',
      do_not_disturb: { start_hour: 13, end_hour: 16 },
    });
    expect(result.skipped).toBe(true);
    expect(result.skip_reason).toBe('campaign_do_not_disturb_blocked');
  });

  test('DnD normal window: hour outside is allowed', () => {
    const result = calc.calculate({
      now: '2026-01-15T10:00:00.000Z',
      do_not_disturb: { start_hour: 13, end_hour: 16 },
    });
    expect(result.skipped).toBe(false);
  });

  test('DnD overnight wrap (22-6): hour=23 is blocked', () => {
    const result = calc.calculate({
      now: '2026-01-15T23:00:00.000Z',
      do_not_disturb: { start_hour: 22, end_hour: 6 },
    });
    expect(result.skipped).toBe(true);
  });

  test('DnD overnight wrap (22-6): hour=3 is blocked', () => {
    const result = calc.calculate({
      now: '2026-01-15T03:00:00.000Z',
      do_not_disturb: { start_hour: 22, end_hour: 6 },
    });
    expect(result.skipped).toBe(true);
  });

  test('DnD overnight wrap: hour=10 is allowed', () => {
    const result = calc.calculate({
      now: '2026-01-15T10:00:00.000Z',
      do_not_disturb: { start_hour: 22, end_hour: 6 },
    });
    expect(result.skipped).toBe(false);
  });

  test('boundary: hour == end_hour is allowed (half-open)', () => {
    // DnD 13-16, hour=16 should be allowed
    const result = calc.calculate({
      now: '2026-01-15T16:00:00.000Z',
      do_not_disturb: { start_hour: 13, end_hour: 16 },
    });
    expect(result.skipped).toBe(false);
  });

  test('boundary: hour == start_hour is blocked', () => {
    const result = calc.calculate({
      now: '2026-01-15T13:00:00.000Z',
      do_not_disturb: { start_hour: 13, end_hour: 16 },
    });
    expect(result.skipped).toBe(true);
  });

  test('no DnD config is not blocked', () => {
    const result = calc.calculate({ now: '2026-01-15T23:00:00.000Z' });
    expect(result.skipped).toBe(false);
  });

  test('execute_at with delay_seconds — delay is ignored', () => {
    const result = calc.calculate({
      now: '2026-01-15T10:00:00.000Z',
      execute_at: '2026-01-15T12:00:00.000Z',
      delay_seconds: 300,
    });
    expect(result.execute_at).toBe('2026-01-15T12:00:00.000Z');
  });

  test('delay_seconds of 0 returns now', () => {
    const result = calc.calculate({
      now: '2026-01-15T10:00:00.000Z',
      delay_seconds: 0,
    });
    expect(result.execute_at).toBe('2026-01-15T10:00:00.000Z');
  });

  test('negative delay_seconds returns now', () => {
    const result = calc.calculate({
      now: '2026-01-15T10:00:00.000Z',
      delay_seconds: -10,
    });
    expect(result.execute_at).toBe('2026-01-15T10:00:00.000Z');
  });
});
