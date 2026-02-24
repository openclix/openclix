// Example placement: feature event callback for campaign enrollment (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/activation-first-value-rescue/openclix.config.json
// Events used: user_signed_up
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

void triggerActivationFirstValueRescueEntry(OpenClixManagerLike openClix) {
  final event = OpenClixEventLike(
    name: 'user_signed_up',
    appState: OpenClixAppStateLike.foreground,
  );
  openClix.ingestEvent(event);
}
