import '../models/clix_types.dart';

class ScheduleInput {
  final String now;
  final String? executeAt;
  final int? delaySeconds;
  final DoNotDisturb? doNotDisturb;

  ScheduleInput({
    required this.now,
    this.executeAt,
    this.delaySeconds,
    this.doNotDisturb,
  });
}

class ScheduleResult {
  final String executeAt;
  final bool skipped;
  final SkipReason? skipReason;

  ScheduleResult({
    required this.executeAt,
    required this.skipped,
    this.skipReason,
  });
}

bool isInDoNotDisturbWindow(int hour, DoNotDisturb doNotDisturb) {
  final startHour = doNotDisturb.startHour;
  final endHour = doNotDisturb.endHour;

  if (startHour <= endHour) {
    return hour >= startHour && hour < endHour;
  }

  return hour >= startHour || hour < endHour;
}

DateTime parseDateTimeOrNow(String value, DateTime fallback) {
  try {
    return DateTime.parse(value).toUtc();
  } catch (_) {
    return fallback;
  }
}

class ScheduleCalculator {
  ScheduleResult calculate(ScheduleInput input) {
    final now = parseDateTimeOrNow(input.now, DateTime.now().toUtc());

    DateTime executeAt;
    if (input.executeAt != null) {
      executeAt = parseDateTimeOrNow(input.executeAt!, now);
    } else {
      executeAt = now;
      if ((input.delaySeconds ?? 0) > 0) {
        executeAt = executeAt.add(Duration(seconds: input.delaySeconds!));
      }
    }

    if (input.doNotDisturb != null &&
        isInDoNotDisturbWindow(executeAt.hour, input.doNotDisturb!)) {
      return ScheduleResult(
        executeAt: executeAt.toIso8601String(),
        skipped: true,
        skipReason: SkipReason.campaignDoNotDisturbBlocked,
      );
    }

    return ScheduleResult(
      executeAt: executeAt.toIso8601String(),
      skipped: false,
    );
  }
}
