// Schema types — mirrors openclix.schema.json (snake_case)
// Campaign state types — SDK internal (camelCase)

export type JsonValue = string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue };

// ---------------------------------------------------------------------------
// Config (from JSON)
// ---------------------------------------------------------------------------

export interface Config {
  /** Canonical config schema URL (optional but recommended). */
  '$schema'?: 'https://openclix.ai/schemas/openclix.schema.json';
  schema_version: 'openclix/config/v1';
  config_version: string;
  settings?: Settings;
  /** Map of campaign ID (kebab-case) to campaign definition. */
  campaigns: Record<string, Campaign>;
}

export interface Settings {
  frequency_cap?: FrequencyCap;
  do_not_disturb?: DoNotDisturb;
}

export interface FrequencyCap {
  max_count: number;
  /** Rolling time window in seconds. */
  window_seconds: number;
}

export interface DoNotDisturb {
  /** 0-23, device local time. */
  start_hour: number;
  /** 0-23. When end < start, wraps past midnight. */
  end_hour: number;
}

export type CampaignStatus = 'running' | 'paused';

export interface Campaign {
  name: string;
  type: 'campaign';
  description: string;
  status: CampaignStatus;
  trigger: CampaignTrigger;
  message: Message;
}

export type TriggerType = 'event' | 'scheduled' | 'recurring';

export interface CampaignTrigger {
  type: TriggerType;
  /** Required when type is 'event'. */
  event?: EventTriggerConfig;
  /** Required when type is 'scheduled'. */
  scheduled?: ScheduledTriggerConfig;
  /** Required when type is 'recurring'. */
  recurring?: RecurringTriggerConfig;
}

export interface EventTriggerConfig {
  trigger_event: EventConditionGroup;
  /** Delay in seconds before enrollment is confirmed. */
  delay_seconds?: number;
  /** Conditions that cancel a pending trigger during the delay period. */
  cancel_event?: EventConditionGroup;
}

export interface ScheduledTriggerConfig {
  /** ISO 8601. */
  execute_at: string;
}

export type RecurrenceType = 'hourly' | 'daily' | 'weekly';
export type DayOfWeek =
  | 'sunday'
  | 'monday'
  | 'tuesday'
  | 'wednesday'
  | 'thursday'
  | 'friday'
  | 'saturday';

export interface TimeOfDay {
  hour: number;
  minute: number;
}

export interface WeeklyRule {
  days_of_week: DayOfWeek[];
}

export interface RecurrenceRule {
  type: RecurrenceType;
  interval: number;
  weekly_rule?: WeeklyRule;
  time_of_day?: TimeOfDay;
}

export interface RecurringTriggerConfig {
  /** ISO 8601. */
  start_at?: string;
  /** ISO 8601. */
  end_at?: string;
  rule: RecurrenceRule;
}

export interface EventConditionGroup {
  connector: 'and' | 'or';
  conditions: EventCondition[];
}

export interface EventCondition {
  field: 'name' | 'property';
  /** Required when field is 'property'. */
  property_name?: string;
  operator: EventConditionOperator;
  /** All values are strings; the SDK casts as needed. */
  values: string[];
}

export type EventConditionOperator =
  | 'equal'
  | 'not_equal'
  | 'greater_than'
  | 'greater_than_or_equal'
  | 'less_than'
  | 'less_than_or_equal'
  | 'contains'
  | 'not_contains'
  | 'starts_with'
  | 'ends_with'
  | 'matches'
  | 'exists'
  | 'not_exists'
  | 'in'
  | 'not_in';

export type ChannelType = 'app_push';

export interface Message {
  channel_type: ChannelType;
  content: MessageContent;
}

export interface MessageContent {
  /** Supports {{key}} template variables. Max 120 chars. */
  title: string;
  /** Supports {{key}} template variables. Max 500 chars. */
  body: string;
  image_url?: string;
  /** URL or deep link opened on notification tap. */
  landing_url?: string;
}

// ---------------------------------------------------------------------------
// Queued Message (device-local delivery queue)
// ---------------------------------------------------------------------------

export type QueuedMessageStatus = 'scheduled' | 'delivered' | 'cancelled';

export type SkipReason =
  | 'campaign_not_running'
  | 'campaign_frequency_cap_exceeded'
  | 'campaign_do_not_disturb_blocked'
  | 'trigger_event_not_matched'
  | 'trigger_cancel_event_matched';

export interface QueuedMessage {
  id: string;
  campaign_id: string;
  channel_type: ChannelType;
  status: QueuedMessageStatus;
  content: { title: string; body: string; image_url?: string; landing_url?: string };
  trigger_event_id?: string;
  skip_reason?: SkipReason;
  /** ISO 8601. */
  execute_at: string;
  /** ISO 8601. */
  created_at: string;
}

// ---------------------------------------------------------------------------
// Event (trigger input)
// ---------------------------------------------------------------------------

export type EventSourceType = 'app' | 'system';

export type SystemEventName =
  | 'clix.message.scheduled'
  | 'clix.message.delivered'
  | 'clix.message.opened'
  | 'clix.message.cancelled'
  | 'clix.message.failed';

export interface Event {
  id: string;
  name: string;
  source_type: EventSourceType;
  properties?: Record<string, JsonValue>;
  /** ISO 8601. */
  created_at: string;
}

// ---------------------------------------------------------------------------
// SDK Campaign state types
// ---------------------------------------------------------------------------

export type ClixLogLevel = 'debug' | 'info' | 'warn' | 'error' | 'none';

export interface TriggerContext {
  event?: Event;
  trigger: 'app_boot' | 'app_foreground' | 'event_tracked' | 'config_replaced';
  /** Override for current time (ISO 8601). */
  now?: string;
}

export interface DecisionTrace {
  campaign_id: string;
  action: string;
  result: 'applied' | 'skipped';
  skip_reason?: SkipReason;
  reason: string;
}

export interface TriggerResult {
  /** ISO 8601. */
  evaluated_at: string;
  trigger: string;
  traces: DecisionTrace[];
  queued_messages: QueuedMessage[];
}

export interface CampaignStateSnapshot {
  /** Flat campaign state rows. */
  campaign_states: CampaignStateRecord[];
  /** Flat queued-message rows. */
  queued_messages: CampaignQueuedMessage[];
  /** Flat trigger history rows for frequency-cap checks. */
  trigger_history: CampaignTriggerHistory[];
  /** ISO 8601. */
  updated_at: string;
}

export interface CampaignStateRecord {
  campaign_id: string;
  triggered: boolean;
  delivery_count: number;
  last_triggered_at?: string;
  recurring_anchor_at?: string;
  recurring_last_scheduled_at?: string;
}

export interface CampaignQueuedMessage {
  message_id: string;
  campaign_id: string;
  execute_at: string;
  trigger_type: TriggerType;
  trigger_event_id?: string;
  created_at: string;
}

export interface CampaignTriggerHistory {
  campaign_id?: string;
  triggered_at: string;
}

// ---------------------------------------------------------------------------
// SDK configuration and dependency interfaces
// ---------------------------------------------------------------------------

export interface ClixConfig {
  /** Campaign config URL (HTTP) or local resource path. */
  endpoint: string;
  /** Optional project identifier added to config fetch headers. */
  projectId?: string;
  /** Optional API key added to config fetch headers. */
  apiKey?: string;
  /** Default: 'warn'. */
  logLevel?: ClixLogLevel;
  extraHeaders?: Record<string, string>;
  /** Optional config fetch timeout override in milliseconds. */
  sessionTimeoutMs?: number;
}

export interface Clock {
  now(): string;
}

export interface LifecycleStateReader {
  getAppState(): 'foreground' | 'background';
  setAppState?(state: 'foreground' | 'background'): void;
  dispose?(): void;
}

export interface Logger {
  debug(msg: string, ...args: unknown[]): void;
  info(msg: string, ...args: unknown[]): void;
  warn(msg: string, ...args: unknown[]): void;
  error(msg: string, ...args: unknown[]): void;
  setLogLevel?(level: ClixLogLevel): void;
}

export interface MessageScheduler {
  schedule(record: QueuedMessage): Promise<void>;
  cancel(id: string): Promise<void>;
  listPending(): Promise<QueuedMessage[]>;
}

export interface CampaignStateRepositoryPort {
  loadSnapshot(now: string): Promise<CampaignStateSnapshot>;
  saveSnapshot(snapshot: CampaignStateSnapshot): Promise<void>;
  clearCampaignState(): Promise<void>;
  appendEvents?(events: Event[], maxEntries?: number): Promise<void>;
  loadEvents?(limit?: number): Promise<Event[]>;
  clearEvents?(): Promise<void>;
}
