import type {
  EventConditionGroup,
  EventConditionOperator,
  EventCondition,
  Event,
  DoNotDisturb,
  SkipReason,
} from './ClixTypes';

/** Simple UUID v4 generator (no crypto dependency). */
export function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/** Matches {{identifier}} where identifier supports dot-notation (e.g. {{user.firstName}}). */
const TEMPLATE_VARIABLE_PATTERN = /\{\{([a-zA-Z_][a-zA-Z0-9_.]*)\}\}/g;

function resolvePath(obj: Record<string, unknown>, path: string): unknown {
  const segments = path.split('.');
  let current: unknown = obj;

  for (const segment of segments) {
    if (current === null || current === undefined) return undefined;
    if (typeof current !== 'object') return undefined;
    current = (current as Record<string, unknown>)[segment];
  }

  return current;
}

function valueToString(value: unknown): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  if (typeof value === 'boolean') return (value ? 'true' : 'false');
  return JSON.stringify(value);
}

/** Resolves {{variableName}} placeholders. Unresolved variables are kept as-is. */
export function renderTemplate(
  template: string,
  variables: Record<string, unknown>,
): string {
  return template.replace(TEMPLATE_VARIABLE_PATTERN, (match, variableName: string) => {
    const resolved = resolvePath(variables, variableName);
    if (resolved === undefined) return match;
    return valueToString(resolved);
  });
}

function applyOperator(
  operator: EventConditionOperator,
  lhs: unknown,
  values: string[],
): boolean {
  if (lhs === null || lhs === undefined) {
    switch (operator) {
      case 'not_equal':
      case 'not_contains':
      case 'not_in':
      case 'not_exists':
        return true;
      case 'exists':
        return false;
      default:
        return false;
    }
  }

  const lhsStr = String(lhs);
  const firstValue = values[0] ?? '';

  switch (operator) {
    case 'equal':
      return lhsStr === firstValue;
    case 'not_equal':
      return lhsStr !== firstValue;
    case 'greater_than': {
      const l = Number(lhs), r = Number(firstValue);
      return !Number.isNaN(l) && !Number.isNaN(r) && l > r;
    }
    case 'greater_than_or_equal': {
      const l = Number(lhs), r = Number(firstValue);
      return !Number.isNaN(l) && !Number.isNaN(r) && l >= r;
    }
    case 'less_than': {
      const l = Number(lhs), r = Number(firstValue);
      return !Number.isNaN(l) && !Number.isNaN(r) && l < r;
    }
    case 'less_than_or_equal': {
      const l = Number(lhs), r = Number(firstValue);
      return !Number.isNaN(l) && !Number.isNaN(r) && l <= r;
    }
    case 'contains':
      return lhsStr.includes(firstValue);
    case 'not_contains':
      return !lhsStr.includes(firstValue);
    case 'starts_with':
      return lhsStr.startsWith(firstValue);
    case 'ends_with':
      return lhsStr.endsWith(firstValue);
    case 'matches':
      try {
        return new RegExp(firstValue).test(lhsStr);
      } catch {
        return false;
      }
    case 'exists':
      return true;
    case 'not_exists':
      return false;
    case 'in':
      return values.includes(lhsStr);
    case 'not_in':
      return !values.includes(lhsStr);
    default:
      return false;
  }
}

export class EventConditionProcessor {
  process(group: EventConditionGroup, event: Event): boolean {
    const { connector, conditions } = group;

    if (conditions.length === 0) {
      return connector === 'and';
    }

    const evaluateRule = (rule: EventCondition): boolean => {
      let lhs: unknown;

      switch (rule.field) {
        case 'name':
          lhs = event.name;
          break;
        case 'property':
          lhs = event.properties?.[rule.property_name!];
          break;
        default:
          return false;
      }

      return applyOperator(rule.operator, lhs, rule.values);
    };

    if (connector === 'and') {
      return conditions.every(evaluateRule);
    }

    return conditions.some(evaluateRule);
  }
}

export interface ScheduleInput {
  now: string;
  execute_at?: string;
  delay_seconds?: number;
  do_not_disturb?: DoNotDisturb;
}

export interface ScheduleResult {
  execute_at: string;
  skipped: boolean;
  skip_reason?: SkipReason;
}

function isInDoNotDisturbWindow(hour: number, doNotDisturb: DoNotDisturb): boolean {
  const { start_hour, end_hour } = doNotDisturb;
  if (start_hour <= end_hour) {
    return hour >= start_hour && hour < end_hour;
  }
  // Overnight: start > end means wraps past midnight
  return hour >= start_hour || hour < end_hour;
}

export class ScheduleCalculator {
  calculate(input: ScheduleInput): ScheduleResult {
    const { now, execute_at, delay_seconds, do_not_disturb } = input;
    let executeAt = execute_at ? new Date(execute_at) : new Date(now);

    if (Number.isNaN(executeAt.getTime())) {
      executeAt = new Date(now);
    } else if (!execute_at && delay_seconds && delay_seconds > 0) {
      executeAt = new Date(executeAt.getTime() + delay_seconds * 1000);
    }

    if (
      do_not_disturb &&
      isInDoNotDisturbWindow(executeAt.getHours(), do_not_disturb)
    ) {
      return {
        execute_at: executeAt.toISOString(),
        skipped: true,
        skip_reason: 'campaign_do_not_disturb_blocked',
      };
    }

    return {
      execute_at: executeAt.toISOString(),
      skipped: false,
    };
  }
}
