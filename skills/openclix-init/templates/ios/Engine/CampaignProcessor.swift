import Foundation

public struct CampaignDecision {
    public let trace: DecisionTrace
    public let action: CampaignAction
    public let queued_message: QueuedMessage?
    public let scheduled_for: String?

    public init(
        trace: DecisionTrace,
        action: CampaignAction,
        queued_message: QueuedMessage? = nil,
        scheduled_for: String? = nil
    ) {
        self.trace = trace
        self.action = action
        self.queued_message = queued_message
        self.scheduled_for = scheduled_for
    }
}

public enum CampaignAction {
    case trigger
    case skip
}

public struct CampaignProcessorDependencies {
    public let eventConditionProcessor: EventConditionProcessor
    public let scheduleCalculator: ScheduleCalculator
    public let logger: ClixLogger
    public let settings: Settings?

    public init(
        eventConditionProcessor: EventConditionProcessor,
        scheduleCalculator: ScheduleCalculator,
        logger: ClixLogger,
        settings: Settings? = nil
    ) {
        self.eventConditionProcessor = eventConditionProcessor
        self.scheduleCalculator = scheduleCalculator
        self.logger = logger
        self.settings = settings
    }
}

private func createTrace(
    campaign_id: String,
    action: String,
    result: DecisionResult,
    reason: String,
    skip_reason: SkipReason? = nil
) -> DecisionTrace {
    return DecisionTrace(
        campaign_id: campaign_id,
        action: action,
        result: result,
        skip_reason: skip_reason,
        reason: reason
    )
}

private func createSkipDecision(
    campaignId: String,
    reason: String,
    skipReason: SkipReason? = nil
) -> CampaignDecision {
    return CampaignDecision(
        trace: createTrace(
            campaign_id: campaignId,
            action: "skip_campaign",
            result: .skipped,
            reason: reason,
            skip_reason: skipReason
        ),
        action: .skip
    )
}

private struct ExecutionResolution {
    let executeAt: String?
    let scheduledFor: String?
    let triggerEventId: String?
    let reason: String?
    let skipReason: SkipReason?
}

private let dayIndex: [DayOfWeek: Int] = [
    .sunday: 0,
    .monday: 1,
    .tuesday: 2,
    .wednesday: 3,
    .thursday: 4,
    .friday: 5,
    .saturday: 6,
]

private func parseIsoDate(_ value: String?) -> Date? {
    guard let value = value, !value.isEmpty else { return nil }

    let internetFormatter = ISO8601DateFormatter()
    internetFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = internetFormatter.date(from: value) {
        return parsed
    }

    let fallbackFormatter = ISO8601DateFormatter()
    return fallbackFormatter.date(from: value)
}

private func toIsoString(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

private func startOfWeek(_ date: Date) -> Date {
    var calendar = Calendar.current
    calendar.timeZone = .current

    let weekday = calendar.component(.weekday, from: date)
    let daysSinceSunday = weekday - 1
    let midnight = calendar.startOfDay(for: date)
    return calendar.date(byAdding: .day, value: -daysSinceSunday, to: midnight) ?? midnight
}

private func withTime(_ base: Date, hour: Int, minute: Int) -> Date {
    var calendar = Calendar.current
    calendar.timeZone = .current

    var components = calendar.dateComponents([.year, .month, .day], from: base)
    components.hour = hour
    components.minute = minute
    components.second = 0
    components.nanosecond = 0
    return calendar.date(from: components) ?? base
}

private func decodeJsonValue(_ value: JsonValue) -> Any {
    switch value {
    case .string(let text):
        return text
    case .number(let number):
        return number
    case .bool(let value):
        return value
    case .null:
        return NSNull()
    case .array(let values):
        return values.map { decodeJsonValue($0) }
    case .object(let values):
        return values.mapValues { decodeJsonValue($0) }
    }
}

public final class CampaignProcessor {

    public init() {}

    public func process(
        campaignId: String,
        campaign: Campaign,
        context: TriggerContext,
        snapshot: CampaignStateSnapshot,
        dependencies: CampaignProcessorDependencies
    ) -> CampaignDecision {
        let eventConditionProcessor = dependencies.eventConditionProcessor
        let scheduleCalculator = dependencies.scheduleCalculator
        let logger = dependencies.logger
        let settings = dependencies.settings
        let now = context.now ?? toIsoString(Date())
        let nowDate = parseIsoDate(now) ?? Date()

        let campaignState = getCampaignState(snapshot: snapshot, campaignId: campaignId)

        if campaign.status != .running {
            return createSkipDecision(
                campaignId: campaignId,
                reason: "Campaign status is '\(campaign.status.rawValue)', not 'running'",
                skipReason: .campaign_not_running
            )
        }

        if (campaign.trigger.type == .event && context.trigger != .event_tracked)
            || (campaign.trigger.type != .event && context.trigger == .event_tracked) {
            return createSkipDecision(
                campaignId: campaignId,
                reason: "Trigger type '\(campaign.trigger.type.rawValue)' is not eligible for '\(context.trigger.rawValue)'"
            )
        }

        if campaign.trigger.type != .recurring,
           campaignState?.triggered == true {
            return createSkipDecision(
                campaignId: campaignId,
                reason: "Campaign already triggered"
            )
        }

        if let frequencyCap = settings?.frequency_cap {
            let windowStartDate = nowDate.addingTimeInterval(-Double(frequencyCap.window_seconds))
            let countInWindow = snapshot.trigger_history.reduce(into: 0) { partial, row in
                guard let triggeredAtDate = parseIsoDate(row.triggered_at) else { return }
                if triggeredAtDate >= windowStartDate {
                    partial += 1
                }
            }

            if countInWindow >= frequencyCap.max_count {
                return createSkipDecision(
                    campaignId: campaignId,
                    reason: "Frequency cap exceeded (\(countInWindow)/\(frequencyCap.max_count) within \(frequencyCap.window_seconds)s)",
                    skipReason: .campaign_frequency_cap_exceeded
                )
            }
        }

        if campaign.trigger.type == .recurring,
           hasFuturePendingForCampaign(
                snapshot: snapshot,
                campaignId: campaignId,
                now: now
           ) {
            return createSkipDecision(
                campaignId: campaignId,
                reason: "Recurring campaign already has a queued message"
            )
        }

        let resolved = resolveExecutionTime(
            campaign: campaign,
            context: context,
            campaignState: campaignState,
            now: now,
            nowDate: nowDate,
            eventConditionProcessor: eventConditionProcessor
        )

        guard let executeAt = resolved.executeAt else {
            return createSkipDecision(
                campaignId: campaignId,
                reason: resolved.reason ?? "Campaign trigger conditions were not met",
                skipReason: resolved.skipReason
            )
        }

        if hasPendingForCampaignAt(
            snapshot: snapshot,
            campaignId: campaignId,
            executeAt: executeAt
        ) {
            return createSkipDecision(
                campaignId: campaignId,
                reason: "Duplicate schedule prevented for campaign at \(executeAt)"
            )
        }

        let scheduleResult = scheduleCalculator.calculate(
            ScheduleInput(
                now: now,
                execute_at: executeAt,
                do_not_disturb: settings?.do_not_disturb
            )
        )

        if scheduleResult.skipped {
            return createSkipDecision(
                campaignId: campaignId,
                reason: "Blocked by do-not-disturb window",
                skipReason: scheduleResult.skip_reason
            )
        }

        var templateVariables: [String: Any] = [:]
        if let eventProperties = context.event?.properties {
            for (key, value) in eventProperties {
                templateVariables[key] = decodeJsonValue(value)
            }
        }

        let renderedTitle = renderTemplate(campaign.message.content.title, variables: templateVariables)
        let renderedBody = renderTemplate(campaign.message.content.body, variables: templateVariables)

        let queuedMessage = QueuedMessage(
            id: generateUUID(),
            campaign_id: campaignId,
            channel_type: campaign.message.channel_type,
            status: .scheduled,
            content: QueuedMessageContent(
                title: renderedTitle,
                body: renderedBody,
                image_url: campaign.message.content.image_url,
                landing_url: campaign.message.content.landing_url
            ),
            trigger_event_id: resolved.triggerEventId,
            execute_at: scheduleResult.execute_at,
            created_at: now
        )

        logger.debug(
            "[CampaignProcessor] Campaign \(campaignId): triggered, scheduled for \(scheduleResult.execute_at)"
        )

        return CampaignDecision(
            trace: createTrace(
                campaign_id: campaignId,
                action: "trigger_campaign",
                result: .applied,
                reason: "Campaign triggered, message scheduled for \(scheduleResult.execute_at)"
            ),
            action: .trigger,
            queued_message: queuedMessage,
            scheduled_for: resolved.scheduledFor ?? scheduleResult.execute_at
        )
    }

    private func resolveExecutionTime(
        campaign: Campaign,
        context: TriggerContext,
        campaignState: CampaignStateRecord?,
        now: String,
        nowDate: Date,
        eventConditionProcessor: EventConditionProcessor
    ) -> ExecutionResolution {
        if campaign.trigger.type == .event {
            guard let eventConfig = campaign.trigger.event else {
                return ExecutionResolution(
                    executeAt: nil,
                    scheduledFor: nil,
                    triggerEventId: nil,
                    reason: "Trigger type 'event' requires trigger.event configuration",
                    skipReason: .trigger_event_not_matched
                )
            }

            guard let event = context.event else {
                return ExecutionResolution(
                    executeAt: nil,
                    scheduledFor: nil,
                    triggerEventId: nil,
                    reason: "Event trigger requires an event in context",
                    skipReason: .trigger_event_not_matched
                )
            }

            let matched = eventConditionProcessor.process(
                group: eventConfig.trigger_event,
                event: event
            )

            if !matched {
                return ExecutionResolution(
                    executeAt: nil,
                    scheduledFor: nil,
                    triggerEventId: nil,
                    reason: "Trigger event conditions did not match event '\(event.name)'",
                    skipReason: .trigger_event_not_matched
                )
            }

            let delaySeconds = eventConfig.delay_seconds ?? 0
            let executeAtDate = nowDate.addingTimeInterval(Double(delaySeconds))
            let executeAt = toIsoString(executeAtDate)

            return ExecutionResolution(
                executeAt: executeAt,
                scheduledFor: executeAt,
                triggerEventId: event.id,
                reason: nil,
                skipReason: nil
            )
        }

        if campaign.trigger.type == .scheduled {
            guard let scheduled = campaign.trigger.scheduled,
                  let executeAtDate = parseIsoDate(scheduled.execute_at) else {
                return ExecutionResolution(
                    executeAt: nil,
                    scheduledFor: nil,
                    triggerEventId: nil,
                    reason: "Scheduled trigger requires a valid execute_at datetime",
                    skipReason: nil
                )
            }

            if executeAtDate <= nowDate {
                return ExecutionResolution(
                    executeAt: nil,
                    scheduledFor: nil,
                    triggerEventId: nil,
                    reason: "Scheduled execute_at '\(scheduled.execute_at)' is already in the past",
                    skipReason: nil
                )
            }

            return ExecutionResolution(
                executeAt: scheduled.execute_at,
                scheduledFor: scheduled.execute_at,
                triggerEventId: nil,
                reason: nil,
                skipReason: nil
            )
        }

        guard let recurring = campaign.trigger.recurring else {
            return ExecutionResolution(
                executeAt: nil,
                scheduledFor: nil,
                triggerEventId: nil,
                reason: "Recurring trigger requires recurring configuration",
                skipReason: nil
            )
        }

        let nextExecuteAt = computeNextRecurringExecuteAt(
            recurring: recurring,
            now: now,
            lastScheduledAt: campaignState?.recurring_last_scheduled_at,
            recurringAnchorAt: campaignState?.recurring_anchor_at
        )

        guard let nextExecuteAt else {
            return ExecutionResolution(
                executeAt: nil,
                scheduledFor: nil,
                triggerEventId: nil,
                reason: "Recurring schedule has no upcoming execution window",
                skipReason: nil
            )
        }

        return ExecutionResolution(
            executeAt: nextExecuteAt,
            scheduledFor: nextExecuteAt,
            triggerEventId: nil,
            reason: nil,
            skipReason: nil
        )
    }

    private func computeNextRecurringExecuteAt(
        recurring: RecurringTriggerConfig,
        now: String,
        lastScheduledAt: String?,
        recurringAnchorAt: String?
    ) -> String? {
        guard let nowDate = parseIsoDate(now) else { return nil }

        let startDate: Date
        if let recurringStartDate = parseIsoDate(recurring.start_at) {
            startDate = recurringStartDate
        } else if let anchorDate = parseIsoDate(recurringAnchorAt) {
            startDate = anchorDate
        } else {
            startDate = computeDefaultRecurringAnchorDate(recurring: recurring, nowDate: nowDate)
        }

        let endDate: Date?
        if recurring.end_at != nil {
            endDate = parseIsoDate(recurring.end_at)
            if endDate == nil {
                return nil
            }
        } else {
            endDate = nil
        }

        let fromDate: Date
        if let lastScheduledDate = parseIsoDate(lastScheduledAt) {
            fromDate = lastScheduledDate.addingTimeInterval(60)
        } else {
            fromDate = nowDate
        }

        let interval = max(1, recurring.rule.interval)
        guard let nextOccurrence = findNextOccurrence(
            recurring: recurring,
            startDate: startDate,
            fromDate: fromDate,
            interval: interval
        ) else {
            return nil
        }

        if let endDate, nextOccurrence > endDate {
            return nil
        }

        return toIsoString(nextOccurrence)
    }

    private func computeDefaultRecurringAnchorDate(
        recurring: RecurringTriggerConfig,
        nowDate: Date
    ) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = .current

        var anchor = nowDate
        if recurring.rule.type == .hourly {
            anchor = calendar.date(bySettingHour: calendar.component(.hour, from: nowDate), minute: 0, second: 0, of: nowDate) ?? nowDate
            return anchor
        }

        if recurring.rule.type == .daily {
            let hour = recurring.rule.time_of_day?.hour ?? calendar.component(.hour, from: nowDate)
            let minute = recurring.rule.time_of_day?.minute ?? calendar.component(.minute, from: nowDate)
            anchor = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: nowDate) ?? nowDate
            return anchor
        }

        let hour = recurring.rule.time_of_day?.hour ?? calendar.component(.hour, from: nowDate)
        let minute = recurring.rule.time_of_day?.minute ?? calendar.component(.minute, from: nowDate)
        let weekAnchor = startOfWeek(nowDate)
        return withTime(weekAnchor, hour: hour, minute: minute)
    }

    private func findNextOccurrence(
        recurring: RecurringTriggerConfig,
        startDate: Date,
        fromDate: Date,
        interval: Int
    ) -> Date? {
        let daySeconds: TimeInterval = 24 * 60 * 60

        if recurring.rule.type == .hourly {
            let baseTime = startDate.timeIntervalSince1970
            let fromTime = max(fromDate.timeIntervalSince1970, baseTime)
            let intervalSeconds = Double(interval * 60 * 60)
            let steps = ceil((fromTime - baseTime) / intervalSeconds)
            let normalizedSteps = max(0, Int(steps))
            return Date(timeIntervalSince1970: baseTime + Double(normalizedSteps) * intervalSeconds)
        }

        if recurring.rule.type == .daily {
            let hour = recurring.rule.time_of_day?.hour ?? Calendar.current.component(.hour, from: startDate)
            let minute = recurring.rule.time_of_day?.minute ?? Calendar.current.component(.minute, from: startDate)

            var candidate = withTime(startDate, hour: hour, minute: minute)
            if candidate < fromDate {
                let deltaDays = Int(floor(fromDate.timeIntervalSince(candidate) / daySeconds))
                let steps = max(0, deltaDays / interval)
                candidate = candidate.addingTimeInterval(Double(steps * interval) * daySeconds)

                while candidate < fromDate {
                    candidate = candidate.addingTimeInterval(Double(interval) * daySeconds)
                }
            }

            return candidate
        }

        if recurring.rule.type == .weekly {
            let daysOfWeek = recurring.rule.weekly_rule?.days_of_week ?? []
            if daysOfWeek.isEmpty { return nil }

            let allowedDays = Array(Set(daysOfWeek.compactMap { dayIndex[$0] })).sorted()
            let hour = recurring.rule.time_of_day?.hour ?? Calendar.current.component(.hour, from: startDate)
            let minute = recurring.rule.time_of_day?.minute ?? Calendar.current.component(.minute, from: startDate)
            let weekSeconds: TimeInterval = 7 * daySeconds
            let anchorWeekStart = startOfWeek(startDate)
            let fromWeekStart = startOfWeek(fromDate)
            let rawWeekDifference = Int(
                floor(fromWeekStart.timeIntervalSince(anchorWeekStart) / weekSeconds)
            )
            let baselineWeekDifference = max(0, rawWeekDifference)
            let remainder = baselineWeekDifference % interval
            var alignedWeekDifference =
                remainder == 0
                ? baselineWeekDifference
                : baselineWeekDifference + (interval - remainder)

            var calendar = Calendar.current
            calendar.timeZone = .current

            for _ in 0..<2 {
                guard let weekStart = calendar.date(
                    byAdding: .day,
                    value: alignedWeekDifference * 7,
                    to: anchorWeekStart
                ) else {
                    alignedWeekDifference += interval
                    continue
                }

                var earliestCandidate: Date?

                for allowedDay in allowedDays {
                    guard let candidateDay = calendar.date(
                        byAdding: .day,
                        value: allowedDay,
                        to: weekStart
                    ) else {
                        continue
                    }

                    let candidate = withTime(candidateDay, hour: hour, minute: minute)
                    if candidate < startDate || candidate < fromDate {
                        continue
                    }

                    if earliestCandidate == nil || candidate < earliestCandidate! {
                        earliestCandidate = candidate
                    }
                }

                if let earliestCandidate {
                    return earliestCandidate
                }

                alignedWeekDifference += interval
            }

            return nil
        }

        return nil
    }

    private func hasPendingForCampaignAt(
        snapshot: CampaignStateSnapshot,
        campaignId: String,
        executeAt: String
    ) -> Bool {
        return snapshot.queued_messages.contains {
            $0.campaign_id == campaignId && $0.execute_at == executeAt
        }
    }

    private func hasFuturePendingForCampaign(
        snapshot: CampaignStateSnapshot,
        campaignId: String,
        now: String
    ) -> Bool {
        let nowDate = parseIsoDate(now)

        for pending in snapshot.queued_messages where pending.campaign_id == campaignId {
            guard let executeAtDate = parseIsoDate(pending.execute_at) else {
                return true
            }

            if let nowDate, executeAtDate >= nowDate {
                return true
            }

            if nowDate == nil {
                return true
            }
        }

        return false
    }

    private func getCampaignState(
        snapshot: CampaignStateSnapshot,
        campaignId: String
    ) -> CampaignStateRecord? {
        return snapshot.campaign_states.first { $0.campaign_id == campaignId }
    }
}
