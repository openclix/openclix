// Example placement: success/completion handler for campaign cancellation (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/activation-first-value-rescue/openclix.config.json
// Events used: first_value_completed, onboarding_step_viewed (optional support event, not required for config)
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

fun triggerActivationFirstValueRescueCancel(openClix: OpenClixManagerLike) {
    val event = OpenClixEventLike(
        name = "first_value_completed",
        appState = OpenClixAppStateLike.FOREGROUND
    )
    openClix.ingestEvent(event)
    // Alternate cancel path in some apps: onboarding_step_viewed (optional support event, not required for config)
}
