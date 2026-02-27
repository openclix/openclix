import type {
  Campaign,
  TriggerContext,
  CampaignStateSnapshot,
  CampaignStateRecord,
  DecisionTrace,
  QueuedMessage,
  Settings,
  SkipReason,
  Logger,
  DayOfWeek,
  RecurringTriggerConfig,
} from './ClixTypes';
import {
  EventConditionProcessor,
  ScheduleCalculator,
  renderTemplate,
  generateUUID,
} from './CampaignUtils';

export interface CampaignDecision {
  trace: DecisionTrace;
  action: 'trigger' | 'skip';
  queued_message?: QueuedMessage;
  scheduled_for?: string;
}

export interface CampaignProcessorDeps {
  eventConditionProcessor: EventConditionProcessor;
  scheduleCalculator: ScheduleCalculator;
  logger: Logger;
  settings?: Settings;
}

function createTrace(
  campaign_id: string,
  action: string,
  result: 'applied' | 'skipped',
  reason: string,
  skip_reason?: SkipReason,
): DecisionTrace {
  return { campaign_id, action, result, skip_reason, reason };
}

function createSkipDecision(
  campaignId: string,
  reason: string,
  skipReason?: SkipReason,
): CampaignDecision {
  return {
    action: 'skip',
    trace: createTrace(
      campaignId,
      'skip_campaign',
      'skipped',
      reason,
      skipReason,
    ),
  };
}

interface ExecutionResolution {
  execute_at?: string;
  scheduled_for?: string;
  trigger_event_id?: string;
  reason?: string;
  skip_reason?: SkipReason;
}

const DAY_INDEX: Record<DayOfWeek, number> = {
  sunday: 0,
  monday: 1,
  tuesday: 2,
  wednesday: 3,
  thursday: 4,
  friday: 5,
  saturday: 6,
};

function isValidDateValue(value: string | undefined): value is string {
  if (!value) return false;
  return !Number.isNaN(new Date(value).getTime());
}

function startOfWeek(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  copy.setDate(copy.getDate() - copy.getDay());
  return copy;
}

function withTime(base: Date, hour: number, minute: number): Date {
  const copy = new Date(base);
  copy.setHours(hour, minute, 0, 0);
  return copy;
}

export class CampaignProcessor {
  process(
    campaignId: string,
    campaign: Campaign,
    context: TriggerContext,
    snapshot: CampaignStateSnapshot,
    dependencies: CampaignProcessorDeps,
  ): CampaignDecision {
    const { eventConditionProcessor, scheduleCalculator, logger, settings } = dependencies;
    const now = context.now ?? new Date().toISOString();
    const campaignState = this.getCampaignState(snapshot, campaignId);

    // 1. Check campaign status
    if (campaign.status !== 'running') {
      return createSkipDecision(
        campaignId,
        `Campaign status is '${campaign.status}', not 'running'`,
        'campaign_not_running',
      );
    }

    if (
      (campaign.trigger.type === 'event' && context.trigger !== 'event_tracked') ||
      (campaign.trigger.type !== 'event' && context.trigger === 'event_tracked')
    ) {
      return createSkipDecision(
        campaignId,
        `Trigger type '${campaign.trigger.type}' is not eligible for '${context.trigger}'`,
      );
    }

    if (
      campaign.trigger.type !== 'recurring' &&
      campaignState?.triggered === true
    ) {
      return createSkipDecision(campaignId, 'Campaign already triggered');
    }

    // Global frequency cap: count all triggered campaigns in the rolling window.
    if (settings?.frequency_cap) {
      const { max_count, window_seconds } = settings.frequency_cap;
      const windowStart = new Date(
        new Date(now).getTime() - window_seconds * 1000,
      ).toISOString();
      const recent = (snapshot.trigger_history ?? []).filter(
        (row) => row.triggered_at >= windowStart,
      );
      const countInWindow = recent.length;
      if (countInWindow >= max_count) {
        return createSkipDecision(
          campaignId,
          `Frequency cap exceeded (${countInWindow}/${max_count} within ${window_seconds}s)`,
          'campaign_frequency_cap_exceeded',
        );
      }
    }

    if (
      campaign.trigger.type === 'recurring' &&
      this.hasFuturePendingForCampaign(snapshot, campaignId, now)
    ) {
      return createSkipDecision(
        campaignId,
        'Recurring campaign already has a queued message',
      );
    }

    const resolved = this.resolveExecutionTime(
      campaign,
      context,
      campaignState,
      now,
      eventConditionProcessor,
    );
    if (!resolved.execute_at) {
      return createSkipDecision(
        campaignId,
        resolved.reason ?? 'Campaign trigger conditions were not met',
        resolved.skip_reason,
      );
    }

    if (this.hasPendingForCampaignAt(snapshot, campaignId, resolved.execute_at)) {
      return createSkipDecision(
        campaignId,
        `Duplicate schedule prevented for campaign at ${resolved.execute_at}`,
      );
    }

    const scheduleResult = scheduleCalculator.calculate({
      now,
      execute_at: resolved.execute_at,
      do_not_disturb: settings?.do_not_disturb,
    });

    if (scheduleResult.skipped) {
      return createSkipDecision(
        campaignId,
        'Blocked by do-not-disturb window',
        scheduleResult.skip_reason,
      );
    }

    // 7. Render message content
    const templateVars: Record<string, unknown> = {
      ...(context.event?.properties ?? {}),
    };

    const renderedTitle = renderTemplate(campaign.message.content.title, templateVars);
    const renderedBody = renderTemplate(campaign.message.content.body, templateVars);

    const queuedMessage: QueuedMessage = {
      id: generateUUID(),
      campaign_id: campaignId,
      channel_type: campaign.message.channel_type,
      status: 'scheduled',
      content: {
        title: renderedTitle,
        body: renderedBody,
        image_url: campaign.message.content.image_url,
        landing_url: campaign.message.content.landing_url,
      },
      trigger_event_id: resolved.trigger_event_id,
      execute_at: scheduleResult.execute_at,
      created_at: now,
    };

    logger.debug(
      `[CampaignProcessor] Campaign ${campaignId}: triggered, scheduled for ${scheduleResult.execute_at}`,
    );

    return {
      action: 'trigger',
      trace: createTrace(
        campaignId,
        'trigger_campaign',
        'applied',
        `Campaign triggered, message scheduled for ${scheduleResult.execute_at}`,
      ),
      queued_message: queuedMessage,
      scheduled_for: resolved.scheduled_for ?? scheduleResult.execute_at,
    };
  }

  private resolveExecutionTime(
    campaign: Campaign,
    context: TriggerContext,
    campaignState: CampaignStateRecord | undefined,
    now: string,
    eventConditionProcessor: EventConditionProcessor,
  ): ExecutionResolution {
    if (campaign.trigger.type === 'event') {
      const eventConfig = campaign.trigger.event;
      if (!eventConfig) {
        return {
          reason: "Trigger type 'event' requires trigger.event configuration",
          skip_reason: 'trigger_event_not_matched',
        };
      }
      if (!context.event) {
        return {
          reason: 'Event trigger requires an event in context',
          skip_reason: 'trigger_event_not_matched',
        };
      }
      const matched = eventConditionProcessor.process(
        eventConfig.trigger_event,
        context.event,
      );
      if (!matched) {
        return {
          reason: `Trigger event conditions did not match event '${context.event.name}'`,
          skip_reason: 'trigger_event_not_matched',
        };
      }
      const delaySeconds = eventConfig.delay_seconds ?? 0;
      const executeAt = new Date(new Date(now).getTime() + delaySeconds * 1000).toISOString();
      return {
        execute_at: executeAt,
        scheduled_for: executeAt,
        trigger_event_id: context.event.id,
      };
    }

    if (campaign.trigger.type === 'scheduled') {
      const scheduled = campaign.trigger.scheduled;
      if (!scheduled || !isValidDateValue(scheduled.execute_at)) {
        return { reason: 'Scheduled trigger requires a valid execute_at datetime' };
      }
      const executeAtMs = new Date(scheduled.execute_at).getTime();
      const nowMs = new Date(now).getTime();
      if (executeAtMs <= nowMs) {
        return { reason: `Scheduled execute_at '${scheduled.execute_at}' is already in the past` };
      }
      return {
        execute_at: scheduled.execute_at,
        scheduled_for: scheduled.execute_at,
      };
    }

    const recurring = campaign.trigger.recurring;
    if (!recurring) {
      return { reason: 'Recurring trigger requires recurring configuration' };
    }
    const lastScheduledAt = campaignState?.recurring_last_scheduled_at;
    const recurringAnchorAt = campaignState?.recurring_anchor_at;
    const nextExecuteAt = this.computeNextRecurringExecuteAt(
      recurring,
      now,
      lastScheduledAt,
      recurringAnchorAt,
    );
    if (!nextExecuteAt) {
      return { reason: 'Recurring schedule has no upcoming execution window' };
    }
    return {
      execute_at: nextExecuteAt,
      scheduled_for: nextExecuteAt,
    };
  }

  private computeNextRecurringExecuteAt(
    recurring: RecurringTriggerConfig,
    now: string,
    lastScheduledAt?: string,
    recurringAnchorAt?: string,
  ): string | null {
    const nowDate = new Date(now);
    if (Number.isNaN(nowDate.getTime())) return null;

    const startDate =
      recurring.start_at && isValidDateValue(recurring.start_at)
        ? new Date(recurring.start_at)
        : recurringAnchorAt && isValidDateValue(recurringAnchorAt)
          ? new Date(recurringAnchorAt)
          : this.computeDefaultRecurringAnchorDate(recurring, nowDate);
    if (Number.isNaN(startDate.getTime())) return null;

    const endAtMs = recurring.end_at ? new Date(recurring.end_at).getTime() : Number.POSITIVE_INFINITY;
    if (Number.isNaN(endAtMs)) return null;

    const fromDate =
      lastScheduledAt && isValidDateValue(lastScheduledAt)
        ? new Date(new Date(lastScheduledAt).getTime() + 60_000)
        : nowDate;

    const interval = Math.max(1, recurring.rule.interval);
    const next = this.findNextOccurrence(recurring, startDate, fromDate, interval);
    if (!next) return null;
    if (next.getTime() > endAtMs) return null;
    return next.toISOString();
  }

  private computeDefaultRecurringAnchorDate(
    recurring: RecurringTriggerConfig,
    nowDate: Date,
  ): Date {
    const anchor = new Date(nowDate);
    anchor.setSeconds(0, 0);

    if (recurring.rule.type === 'hourly') {
      anchor.setMinutes(0, 0, 0);
      return anchor;
    }

    if (recurring.rule.type === 'daily') {
      const hour = recurring.rule.time_of_day?.hour ?? nowDate.getHours();
      const minute = recurring.rule.time_of_day?.minute ?? nowDate.getMinutes();
      anchor.setHours(hour, minute, 0, 0);
      return anchor;
    }

    const hour = recurring.rule.time_of_day?.hour ?? nowDate.getHours();
    const minute = recurring.rule.time_of_day?.minute ?? nowDate.getMinutes();
    const weekAnchor = startOfWeek(anchor);
    weekAnchor.setHours(hour, minute, 0, 0);
    return weekAnchor;
  }

  private findNextOccurrence(
    recurring: RecurringTriggerConfig,
    startDate: Date,
    fromDate: Date,
    interval: number,
  ): Date | null {
    const rule = recurring.rule;

    if (rule.type === 'hourly') {
      const baseMs = startDate.getTime();
      const fromMs = Math.max(fromDate.getTime(), baseMs);
      const intervalMs = interval * 60 * 60 * 1000;
      const steps = Math.ceil((fromMs - baseMs) / intervalMs);
      return new Date(baseMs + Math.max(0, steps) * intervalMs);
    }

    if (rule.type === 'daily') {
      const hour = rule.time_of_day?.hour ?? startDate.getHours();
      const minute = rule.time_of_day?.minute ?? startDate.getMinutes();
      const anchor = withTime(startDate, hour, minute);
      let candidate = new Date(anchor);
      if (candidate < fromDate) {
        const dayMs = 24 * 60 * 60 * 1000;
        const deltaDays = Math.floor((fromDate.getTime() - candidate.getTime()) / dayMs);
        const steps = Math.floor(deltaDays / interval);
        candidate = new Date(candidate.getTime() + steps * interval * dayMs);
        while (candidate < fromDate) {
          candidate = new Date(candidate.getTime() + interval * dayMs);
        }
      }
      return candidate;
    }

    if (rule.type === 'weekly') {
      const days = rule.weekly_rule?.days_of_week ?? [];
      if (days.length === 0) return null;
      const allowed = [...new Set(days.map((day) => DAY_INDEX[day]))].sort(
        (a, b) => a - b,
      );
      const hour = rule.time_of_day?.hour ?? startDate.getHours();
      const minute = rule.time_of_day?.minute ?? startDate.getMinutes();
      const weekMs = 7 * 24 * 60 * 60 * 1000;
      const anchorWeekStartMs = startOfWeek(startDate).getTime();
      const fromWeekStartMs = startOfWeek(fromDate).getTime();
      const rawWeekDiff = Math.floor((fromWeekStartMs - anchorWeekStartMs) / weekMs);
      const baselineWeekDiff = Math.max(0, rawWeekDiff);
      const remainder = baselineWeekDiff % interval;
      let alignedWeekDiff =
        remainder === 0
          ? baselineWeekDiff
          : baselineWeekDiff + (interval - remainder);

      for (let attempt = 0; attempt < 2; attempt += 1) {
        const weekStart = new Date(anchorWeekStartMs + alignedWeekDiff * weekMs);
        let earliestCandidate: Date | null = null;

        for (const dayIndex of allowed) {
          const candidate = new Date(weekStart);
          candidate.setDate(weekStart.getDate() + dayIndex);
          candidate.setHours(hour, minute, 0, 0);

          if (candidate < startDate || candidate < fromDate) continue;
          if (!earliestCandidate || candidate < earliestCandidate) {
            earliestCandidate = candidate;
          }
        }

        if (earliestCandidate) return earliestCandidate;
        alignedWeekDiff += interval;
      }

      return null;
    }

    return null;
  }

  private hasPendingForCampaignAt(
    snapshot: CampaignStateSnapshot,
    campaignId: string,
    executeAt: string,
  ): boolean {
    for (const pending of snapshot.queued_messages) {
      if (pending.campaign_id === campaignId && pending.execute_at === executeAt) {
        return true;
      }
    }
    return false;
  }

  private hasFuturePendingForCampaign(
    snapshot: CampaignStateSnapshot,
    campaignId: string,
    now: string,
  ): boolean {
    const nowMs = new Date(now).getTime();
    for (const pending of snapshot.queued_messages) {
      if (pending.campaign_id !== campaignId) continue;
      const executeAtMs = new Date(pending.execute_at).getTime();
      if (Number.isNaN(executeAtMs)) return true;
      if (!Number.isNaN(nowMs) && executeAtMs >= nowMs) return true;
    }
    return false;
  }

  private getCampaignState(
    snapshot: CampaignStateSnapshot,
    campaignId: string,
  ): CampaignStateRecord | undefined {
    return snapshot.campaign_states.find((state) => state.campaign_id === campaignId);
  }
}
