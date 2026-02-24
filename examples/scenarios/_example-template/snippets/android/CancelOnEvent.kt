// Example placement: target action completion handler (pseudo-code).
// Adapt to: your analytics/event tracking integration and runtime store.
// Shared config: examples/scenarios/_example-template/openclix.config.json
// Events used: first_action_completed
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

fun cancelTemplateCampaignAfterFirstAction(openClix: OpenClixManagerLike) {
    val event = OpenClixEventLike(
        name = "first_action_completed",
        appState = OpenClixAppStateLike.FOREGROUND
    )
    openClix.ingestEvent(event)
}
