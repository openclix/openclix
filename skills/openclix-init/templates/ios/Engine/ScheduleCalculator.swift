import Foundation

public struct ScheduleInput {
    public let now: String
    public let execute_at: String?
    public let delay_seconds: Int?
    public let do_not_disturb: DoNotDisturb?

    public init(
        now: String,
        execute_at: String? = nil,
        delay_seconds: Int? = nil,
        do_not_disturb: DoNotDisturb? = nil
    ) {
        self.now = now
        self.execute_at = execute_at
        self.delay_seconds = delay_seconds
        self.do_not_disturb = do_not_disturb
    }
}

public struct ScheduleResult {
    public let execute_at: String
    public let skipped: Bool
    public let skip_reason: SkipReason?

    public init(execute_at: String, skipped: Bool, skip_reason: SkipReason? = nil) {
        self.execute_at = execute_at
        self.skipped = skipped
        self.skip_reason = skip_reason
    }
}

private func isInDoNotDisturbWindow(hour: Int, doNotDisturb: DoNotDisturb) -> Bool {
    let startHour = doNotDisturb.start_hour
    let endHour = doNotDisturb.end_hour

    if startHour <= endHour {
        return hour >= startHour && hour < endHour
    }

    return hour >= startHour || hour < endHour
}

public final class ScheduleCalculator {

    public init() {}

    public func calculate(_ input: ScheduleInput) -> ScheduleResult {
        var executeAtDate: Date

        if let executeAt = input.execute_at,
           let parsedDate = ISO8601DateFormatter().date(from: executeAt) {
            executeAtDate = parsedDate
        } else if let parsedDate = ISO8601DateFormatter().date(from: input.now) {
            executeAtDate = parsedDate
            if input.execute_at == nil,
               let delaySeconds = input.delay_seconds,
               delaySeconds > 0 {
                executeAtDate = parsedDate.addingTimeInterval(Double(delaySeconds))
            }
        } else {
            executeAtDate = Date()
        }

        if let doNotDisturb = input.do_not_disturb {
            let hour = Calendar.current.component(.hour, from: executeAtDate)
            if isInDoNotDisturbWindow(hour: hour, doNotDisturb: doNotDisturb) {
                return ScheduleResult(
                    execute_at: executeAtDate.formattedISO8601(),
                    skipped: true,
                    skip_reason: .campaign_do_not_disturb_blocked
                )
            }
        }

        return ScheduleResult(
            execute_at: executeAtDate.formattedISO8601(),
            skipped: false
        )
    }
}

private extension Date {
    func formattedISO8601() -> String {
        return ISO8601DateFormatter().string(from: self)
    }
}
