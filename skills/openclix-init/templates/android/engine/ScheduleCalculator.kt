package ai.openclix.engine

import ai.openclix.models.DoNotDisturb
import ai.openclix.models.SkipReason
import java.util.Calendar
import java.util.Date

// Input supports either a precomputed execute_at or now + delay_seconds.
data class ScheduleInput(
    val now: String,
    val execute_at: String? = null,
    val delay_seconds: Int? = null,
    val do_not_disturb: DoNotDisturb? = null
)

data class ScheduleResult(
    val execute_at: String,
    val skipped: Boolean,
    val skip_reason: SkipReason? = null
)

private fun isInDoNotDisturbWindow(hour: Int, doNotDisturb: DoNotDisturb): Boolean {
    val startHour = doNotDisturb.start_hour
    val endHour = doNotDisturb.end_hour
    return if (startHour <= endHour) {
        hour >= startHour && hour < endHour
    } else {
        hour >= startHour || hour < endHour
    }
}

class ScheduleCalculator {

    fun calculate(input: ScheduleInput): ScheduleResult {
        val nowDate = Date(parseIso8601(input.now))
        var executeAtDate = if (input.execute_at != null) {
            Date(parseIso8601(input.execute_at))
        } else {
            nowDate
        }

        val executeAtMillis = executeAtDate.time
        if (executeAtMillis <= 0L) {
            executeAtDate = nowDate
        } else if (input.execute_at == null && input.delay_seconds != null && input.delay_seconds > 0) {
            executeAtDate = Date(executeAtDate.time + input.delay_seconds * 1000L)
        }

        if (input.do_not_disturb != null) {
            val calendar = Calendar.getInstance().apply { time = executeAtDate }
            val hour = calendar.get(Calendar.HOUR_OF_DAY)
            if (isInDoNotDisturbWindow(hour, input.do_not_disturb)) {
                return ScheduleResult(
                    execute_at = toIso8601(executeAtDate.time),
                    skipped = true,
                    skip_reason = SkipReason.CAMPAIGN_DO_NOT_DISTURB_BLOCKED
                )
            }
        }

        return ScheduleResult(
            execute_at = toIso8601(executeAtDate.time),
            skipped = false
        )
    }
}

internal fun parseIso8601(isoString: String): Long {
    return try {
        java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.parse(isoString)?.time ?: System.currentTimeMillis()
    } catch (_: Exception) {
        try {
            java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US).apply {
                timeZone = java.util.TimeZone.getTimeZone("UTC")
            }.parse(isoString)?.time ?: System.currentTimeMillis()
        } catch (_: Exception) {
            System.currentTimeMillis()
        }
    }
}

internal fun toIso8601(epochMilliseconds: Long): String {
    val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
    formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
    return formatter.format(java.util.Date(epochMilliseconds))
}
