// Example placement: signup success flow or ViewModel action handler (pseudo-code).
// Adapt to: your DI container, event pipeline, and notification scheduler integration.
// Shared config: examples/scenarios/_example-template/openclix.config.json
// Events used: user_signed_up
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

fun scheduleTemplateCampaignOnSignup(openClix: OpenClixManagerLike) {
    val event = OpenClixEventLike(
        name = "user_signed_up",
        appState = OpenClixAppStateLike.FOREGROUND
    )
    openClix.ingestEvent(event)
}
