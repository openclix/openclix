// Example placement: feature event handler for campaign enrollment (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/streak-protection-escalation/openclix.config.json
// Events used: streak_risk_detected
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

fun triggerStreakProtectionEscalationEntry(openClix: OpenClixManagerLike) {
    val event = OpenClixEventLike(
        name = "streak_risk_detected",
        appState = OpenClixAppStateLike.FOREGROUND,
        payload = mapOf(
            "streakCount" to 7,
            "hoursRemaining" to 18,
            "coreActionLabel" to "check-in"
        )
    )
    openClix.ingestEvent(event)
}
