// Example placement: signup completion use-case or controller callback (pseudo-code).
// Adapt to: your plugin initialization and state management architecture.
// Shared config: examples/scenarios/_example-template/openclix.config.json
// Events used: user_signed_up
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

void scheduleTemplateCampaignOnSignup(OpenClixManagerLike openClix) {
  final event = OpenClixEventLike(
    name: 'user_signed_up',
    appState: OpenClixAppStateLike.foreground,
  );
  openClix.ingestEvent(event);
}
