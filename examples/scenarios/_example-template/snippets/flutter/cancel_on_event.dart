// Example placement: first action completion callback (pseudo-code).
// Adapt to: your event stream and local notification adapter implementation.
// Shared config: examples/scenarios/_example-template/openclix.config.json
// Events used: first_action_completed
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

void cancelTemplateCampaignAfterFirstAction(OpenClixManagerLike openClix) {
  final event = OpenClixEventLike(
    name: 'first_action_completed',
    appState: OpenClixAppStateLike.foreground,
  );
  openClix.ingestEvent(event);
}
