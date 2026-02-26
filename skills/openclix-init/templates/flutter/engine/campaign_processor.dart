import '../models/clix_types.dart';
import '../services/utils.dart';
import 'event_condition_processor.dart';
import 'schedule_calculator.dart';

class CampaignDecision {
  final DecisionTrace trace;
  final String action;
  final QueuedMessage? queuedMessage;
  final String? scheduledFor;

  CampaignDecision({
    required this.trace,
    required this.action,
    this.queuedMessage,
    this.scheduledFor,
  });
}

class CampaignProcessorDependencies {
  final EventConditionProcessor eventConditionProcessor;
  final ScheduleCalculator scheduleCalculator;
  final ClixLogger logger;
  final Settings? settings;

  CampaignProcessorDependencies({
    required this.eventConditionProcessor,
    required this.scheduleCalculator,
    required this.logger,
    this.settings,
  });
}

DecisionTrace createTrace(
  String campaignId,
  String action,
  String result,
  String reason, [
  SkipReason? skipReason,
]) {
  return DecisionTrace(
    campaignId: campaignId,
    action: action,
    result: result,
    skipReason: skipReason,
    reason: reason,
  );
}

CampaignDecision createSkipDecision(
  String campaignId,
  String reason, [
  SkipReason? skipReason,
]) {
  return CampaignDecision(
    action: 'skip',
    trace: createTrace(
      campaignId,
      'skip_campaign',
      'skipped',
      reason,
      skipReason,
    ),
  );
}

class ExecutionResolution {
  final String? executeAt;
  final String? scheduledFor;
  final String? triggerEventId;
  final String? reason;
  final SkipReason? skipReason;

  ExecutionResolution({
    this.executeAt,
    this.scheduledFor,
    this.triggerEventId,
    this.reason,
    this.skipReason,
  });
}

final Map<DayOfWeek, int> dayIndex = {
  DayOfWeek.sunday: 0,
  DayOfWeek.monday: 1,
  DayOfWeek.tuesday: 2,
  DayOfWeek.wednesday: 3,
  DayOfWeek.thursday: 4,
  DayOfWeek.friday: 5,
  DayOfWeek.saturday: 6,
};

DateTime? parseDateTimeMaybe(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return DateTime.parse(value).toUtc();
  } catch (_) {
    return null;
  }
}

DateTime startOfWeek(DateTime dateTime) {
  final normalized = DateTime.utc(dateTime.year, dateTime.month, dateTime.day);
  return normalized.subtract(Duration(days: normalized.weekday % 7));
}

DateTime withTime(DateTime dateTime, int hour, int minute) {
  return DateTime.utc(
    dateTime.year,
    dateTime.month,
    dateTime.day,
    hour,
    minute,
  );
}

class CampaignProcessor {
  CampaignDecision process(
    String campaignId,
    Campaign campaign,
    TriggerContext context,
    CampaignStateSnapshot snapshot,
    CampaignProcessorDependencies dependencies,
  ) {
    final eventConditionProcessor = dependencies.eventConditionProcessor;
    final scheduleCalculator = dependencies.scheduleCalculator;
    final logger = dependencies.logger;
    final settings = dependencies.settings;

    final now = context.now ?? DateTime.now().toUtc().toIso8601String();
    final campaignState = getCampaignState(snapshot, campaignId);

    if (campaign.status != CampaignStatus.running) {
      return createSkipDecision(
        campaignId,
        "Campaign status is '${campaign.status.value}', not 'running'",
        SkipReason.campaignNotRunning,
      );
    }

    if ((campaign.trigger.type == TriggerType.event &&
            context.trigger != 'event_tracked') ||
        (campaign.trigger.type != TriggerType.event &&
            context.trigger == 'event_tracked')) {
      return createSkipDecision(
        campaignId,
        "Trigger type '${campaign.trigger.type.value}' is not eligible for '${context.trigger}'",
      );
    }

    if (campaign.trigger.type != TriggerType.recurring &&
        campaignState?.triggered == true) {
      return createSkipDecision(campaignId, 'Campaign already triggered');
    }

    if (settings?.frequencyCap != null) {
      final maxCount = settings!.frequencyCap!.maxCount;
      final windowSeconds = settings.frequencyCap!.windowSeconds;
      final nowDate = parseDateTimeMaybe(now) ?? DateTime.now().toUtc();
      final windowStart = nowDate
          .subtract(Duration(seconds: windowSeconds))
          .toIso8601String();

      final recentTriggerCount = snapshot.triggerHistory
          .where((history) => history.triggeredAt.compareTo(windowStart) >= 0)
          .length;

      if (recentTriggerCount >= maxCount) {
        return createSkipDecision(
          campaignId,
          'Frequency cap exceeded '
          '($recentTriggerCount/$maxCount within ${windowSeconds}s)',
          SkipReason.campaignFrequencyCapExceeded,
        );
      }
    }

    if (campaign.trigger.type == TriggerType.recurring &&
        hasFuturePendingForCampaign(snapshot, campaignId, now)) {
      return createSkipDecision(
        campaignId,
        'Recurring campaign already has a queued message',
      );
    }

    final resolved = resolveExecutionTime(
      campaign,
      context,
      campaignState,
      now,
      eventConditionProcessor,
    );

    if (resolved.executeAt == null) {
      return createSkipDecision(
        campaignId,
        resolved.reason ?? 'Campaign trigger conditions were not met',
        resolved.skipReason,
      );
    }

    if (hasPendingForCampaignAt(snapshot, campaignId, resolved.executeAt!)) {
      return createSkipDecision(
        campaignId,
        'Duplicate schedule prevented for campaign at ${resolved.executeAt}',
      );
    }

    final scheduleResult = scheduleCalculator.calculate(
      ScheduleInput(
        now: now,
        executeAt: resolved.executeAt,
        doNotDisturb: settings?.doNotDisturb,
      ),
    );

    if (scheduleResult.skipped) {
      return createSkipDecision(
        campaignId,
        'Blocked by do-not-disturb window',
        scheduleResult.skipReason,
      );
    }

    final templateVariables = <String, dynamic>{
      ...(context.event?.properties ?? const {}),
    };

    final renderedTitle = renderTemplate(
      campaign.message.content.title,
      templateVariables,
    );
    final renderedBody = renderTemplate(
      campaign.message.content.body,
      templateVariables,
    );

    final queuedMessage = QueuedMessage(
      id: generateUUID(),
      campaignId: campaignId,
      channelType: campaign.message.channelType,
      status: QueuedMessageStatus.scheduled,
      content: MessageContent(
        title: renderedTitle,
        body: renderedBody,
        imageUrl: campaign.message.content.imageUrl,
        landingUrl: campaign.message.content.landingUrl,
      ),
      triggerEventId: resolved.triggerEventId,
      executeAt: scheduleResult.executeAt,
      createdAt: now,
    );

    logger.debug(
      '[CampaignProcessor] Campaign $campaignId: triggered, scheduled for ${scheduleResult.executeAt}',
    );

    return CampaignDecision(
      action: 'trigger',
      trace: createTrace(
        campaignId,
        'trigger_campaign',
        'applied',
        'Campaign triggered, message scheduled for ${scheduleResult.executeAt}',
      ),
      queuedMessage: queuedMessage,
      scheduledFor: resolved.scheduledFor ?? scheduleResult.executeAt,
    );
  }

  ExecutionResolution resolveExecutionTime(
    Campaign campaign,
    TriggerContext context,
    CampaignStateRecord? campaignState,
    String now,
    EventConditionProcessor eventConditionProcessor,
  ) {
    if (campaign.trigger.type == TriggerType.event) {
      final eventConfiguration = campaign.trigger.event;
      if (eventConfiguration == null) {
        return ExecutionResolution(
          reason: "Trigger type 'event' requires trigger.event configuration",
          skipReason: SkipReason.triggerEventNotMatched,
        );
      }

      if (context.event == null) {
        return ExecutionResolution(
          reason: 'Event trigger requires an event in context',
          skipReason: SkipReason.triggerEventNotMatched,
        );
      }

      final matched = eventConditionProcessor.process(
        eventConfiguration.triggerEvent,
        context.event!,
      );
      if (!matched) {
        return ExecutionResolution(
          reason:
              "Trigger event conditions did not match event '${context.event!.name}'",
          skipReason: SkipReason.triggerEventNotMatched,
        );
      }

      final delaySeconds = eventConfiguration.delaySeconds ?? 0;
      final nowDate = parseDateTimeMaybe(now) ?? DateTime.now().toUtc();
      final executeAt = nowDate
          .add(Duration(seconds: delaySeconds))
          .toIso8601String();

      return ExecutionResolution(
        executeAt: executeAt,
        scheduledFor: executeAt,
        triggerEventId: context.event!.id,
      );
    }

    if (campaign.trigger.type == TriggerType.scheduled) {
      final scheduledConfiguration = campaign.trigger.scheduled;
      final executeAtDate = parseDateTimeMaybe(
        scheduledConfiguration?.executeAt,
      );
      if (scheduledConfiguration == null || executeAtDate == null) {
        return ExecutionResolution(
          reason: 'Scheduled trigger requires a valid execute_at datetime',
        );
      }

      final nowDate = parseDateTimeMaybe(now) ?? DateTime.now().toUtc();
      if (!executeAtDate.isAfter(nowDate)) {
        return ExecutionResolution(
          reason:
              "Scheduled execute_at '${scheduledConfiguration.executeAt}' is already in the past",
        );
      }

      return ExecutionResolution(
        executeAt: scheduledConfiguration.executeAt,
        scheduledFor: scheduledConfiguration.executeAt,
      );
    }

    final recurringConfiguration = campaign.trigger.recurring;
    if (recurringConfiguration == null) {
      return ExecutionResolution(
        reason: 'Recurring trigger requires recurring configuration',
      );
    }

    final nextExecuteAt = computeNextRecurringExecuteAt(
      recurringConfiguration,
      now,
      campaignState?.recurringLastScheduledAt,
      campaignState?.recurringAnchorAt,
    );

    if (nextExecuteAt == null) {
      return ExecutionResolution(
        reason: 'Recurring schedule has no upcoming execution window',
      );
    }

    return ExecutionResolution(
      executeAt: nextExecuteAt,
      scheduledFor: nextExecuteAt,
    );
  }

  String? computeNextRecurringExecuteAt(
    RecurringTriggerConfig recurringConfiguration,
    String now,
    String? lastScheduledAt,
    String? recurringAnchorAt,
  ) {
    final nowDate = parseDateTimeMaybe(now);
    if (nowDate == null) return null;

    final startAtDate = parseDateTimeMaybe(recurringConfiguration.startAt);
    final recurringAnchorDate = parseDateTimeMaybe(recurringAnchorAt);
    final startDate =
        startAtDate ??
        recurringAnchorDate ??
        computeDefaultRecurringAnchorDate(recurringConfiguration, nowDate);

    final endDate = recurringConfiguration.endAt == null
        ? null
        : parseDateTimeMaybe(recurringConfiguration.endAt);
    if (recurringConfiguration.endAt != null && endDate == null) {
      return null;
    }

    final fromDate =
        parseDateTimeMaybe(lastScheduledAt)?.add(const Duration(minutes: 1)) ??
        nowDate;

    final interval = recurringConfiguration.rule.interval < 1
        ? 1
        : recurringConfiguration.rule.interval;

    final next = findNextOccurrence(
      recurringConfiguration,
      startDate,
      fromDate,
      interval,
    );

    if (next == null) return null;
    if (endDate != null && next.isAfter(endDate)) return null;

    return next.toIso8601String();
  }

  DateTime computeDefaultRecurringAnchorDate(
    RecurringTriggerConfig recurringConfiguration,
    DateTime nowDate,
  ) {
    if (recurringConfiguration.rule.type == RecurrenceType.hourly) {
      return DateTime.utc(
        nowDate.year,
        nowDate.month,
        nowDate.day,
        nowDate.hour,
      );
    }

    if (recurringConfiguration.rule.type == RecurrenceType.daily) {
      final timeOfDay = recurringConfiguration.rule.timeOfDay;
      final hour = timeOfDay?.hour ?? nowDate.hour;
      final minute = timeOfDay?.minute ?? nowDate.minute;
      return DateTime.utc(
        nowDate.year,
        nowDate.month,
        nowDate.day,
        hour,
        minute,
      );
    }

    final timeOfDay = recurringConfiguration.rule.timeOfDay;
    final hour = timeOfDay?.hour ?? nowDate.hour;
    final minute = timeOfDay?.minute ?? nowDate.minute;
    final weekAnchor = startOfWeek(nowDate);
    return DateTime.utc(
      weekAnchor.year,
      weekAnchor.month,
      weekAnchor.day,
      hour,
      minute,
    );
  }

  DateTime? findNextOccurrence(
    RecurringTriggerConfig recurringConfiguration,
    DateTime startDate,
    DateTime fromDate,
    int interval,
  ) {
    final rule = recurringConfiguration.rule;

    if (rule.type == RecurrenceType.hourly) {
      final baseMilliseconds = startDate.millisecondsSinceEpoch;
      final fromMilliseconds =
          fromDate.millisecondsSinceEpoch > baseMilliseconds
          ? fromDate.millisecondsSinceEpoch
          : baseMilliseconds;
      final intervalMilliseconds = interval * 60 * 60 * 1000;
      final steps =
          ((fromMilliseconds - baseMilliseconds) / intervalMilliseconds).ceil();
      return DateTime.fromMillisecondsSinceEpoch(
        baseMilliseconds + (steps < 0 ? 0 : steps) * intervalMilliseconds,
        isUtc: true,
      );
    }

    if (rule.type == RecurrenceType.daily) {
      final hour = rule.timeOfDay?.hour ?? startDate.hour;
      final minute = rule.timeOfDay?.minute ?? startDate.minute;

      var candidate = withTime(startDate, hour, minute);
      if (candidate.isBefore(fromDate)) {
        final deltaDays = fromDate.difference(candidate).inDays;
        final steps = (deltaDays / interval).floor();
        candidate = candidate.add(Duration(days: steps * interval));

        while (candidate.isBefore(fromDate)) {
          candidate = candidate.add(Duration(days: interval));
        }
      }

      return candidate;
    }

    if (rule.type == RecurrenceType.weekly) {
      final days = rule.weeklyRule?.daysOfWeek ?? const <DayOfWeek>[];
      if (days.isEmpty) return null;

      final allowedDays = days.map((day) => dayIndex[day]!).toSet();
      final hour = rule.timeOfDay?.hour ?? startDate.hour;
      final minute = rule.timeOfDay?.minute ?? startDate.minute;
      final anchorWeekStart = startOfWeek(startDate).millisecondsSinceEpoch;

      final cursor = DateTime.utc(fromDate.year, fromDate.month, fromDate.day);

      for (var offset = 0; offset < 732; offset += 1) {
        final candidateDay = cursor.add(Duration(days: offset));
        final candidate = DateTime.utc(
          candidateDay.year,
          candidateDay.month,
          candidateDay.day,
          hour,
          minute,
        );

        if (candidate.isBefore(fromDate)) continue;

        final candidateDayIndex = candidate.weekday % 7;
        if (!allowedDays.contains(candidateDayIndex)) continue;

        final candidateWeekStart = startOfWeek(
          candidate,
        ).millisecondsSinceEpoch;
        final weekDiff =
            ((candidateWeekStart - anchorWeekStart) / (7 * 24 * 60 * 60 * 1000))
                .floor();

        if (weekDiff >= 0 && weekDiff % interval == 0) {
          return candidate;
        }
      }

      return null;
    }

    return null;
  }

  bool hasPendingForCampaignAt(
    CampaignStateSnapshot snapshot,
    String campaignId,
    String executeAt,
  ) {
    return snapshot.queuedMessages.any(
      (pending) =>
          pending.campaignId == campaignId && pending.executeAt == executeAt,
    );
  }

  bool hasFuturePendingForCampaign(
    CampaignStateSnapshot snapshot,
    String campaignId,
    String now,
  ) {
    final nowDate = parseDateTimeMaybe(now);

    for (final pending in snapshot.queuedMessages) {
      if (pending.campaignId != campaignId) continue;

      final executeAtDate = parseDateTimeMaybe(pending.executeAt);
      if (executeAtDate == null) return true;
      if (nowDate == null || !executeAtDate.isBefore(nowDate)) {
        return true;
      }
    }

    return false;
  }

  CampaignStateRecord? getCampaignState(
    CampaignStateSnapshot snapshot,
    String campaignId,
  ) {
    for (final state in snapshot.campaignStates) {
      if (state.campaignId == campaignId) {
        return state;
      }
    }
    return null;
  }
}
