// Example placement: feature event handler for campaign enrollment (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/interrupted-flow-recovery/openclix.config.json
// Events used: critical_flow_abandoned
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

fun triggerInterruptedFlowRecoveryEntry(openClix: OpenClixManagerLike) {
    val event = OpenClixEventLike(
        name = "critical_flow_abandoned",
        appState = OpenClixAppStateLike.FOREGROUND,
        payload = mapOf(
            "flowKey" to "checkout",
            "flowLabel" to "checkout",
            "intentScore" to 80,
            "resumeDeepLink" to "app://checkout/resume"
        )
    )
    openClix.ingestEvent(event)
}
