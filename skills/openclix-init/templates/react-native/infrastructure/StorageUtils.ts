export const CAMPAIGN_STATE_KEYS = {
  campaign_states: '@openclix/campaign_states',
  queued_messages: '@openclix/queued_messages',
  trigger_history: '@openclix/trigger_history',
  events: '@openclix/events',
  meta: '@openclix/campaign_state_meta',
} as const;

export function parseJson<T>(raw: string | null): T | null {
  if (!raw) return null;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

export function parseArray<T>(raw: string | null): T[] {
  const parsed = parseJson<unknown>(raw);
  return Array.isArray(parsed) ? (parsed as T[]) : [];
}

export function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.length > 0;
}

export function toIsoStringOrCurrentTime(value: unknown): string {
  const date =
    value instanceof Date
      ? value
      : typeof value === 'number' || typeof value === 'string'
        ? new Date(value)
        : null;

  if (!date || Number.isNaN(date.getTime())) {
    return new Date().toISOString();
  }

  return date.toISOString();
}
