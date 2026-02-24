// Example placement: success/completion callback for campaign cancellation (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/streak-protection-escalation/openclix.config.json
// Events used: streak_extended, streak_reset
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

void triggerStreakProtectionEscalationCancel(OpenClixManagerLike openClix) {
  final event = OpenClixEventLike(
    name: 'streak_extended',
    appState: OpenClixAppStateLike.foreground,
  );
  openClix.ingestEvent(event);
  // Alternate cancel path in some apps: streak_reset
}
