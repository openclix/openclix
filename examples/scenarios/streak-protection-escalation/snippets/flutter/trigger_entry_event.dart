// Example placement: feature event callback for campaign enrollment (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/streak-protection-escalation/openclix.config.json
// Events used: streak_risk_detected
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

void triggerStreakProtectionEscalationEntry(OpenClixManagerLike openClix) {
  final event = OpenClixEventLike(
    name: 'streak_risk_detected',
    appState: OpenClixAppStateLike.foreground,
    payload: {
      'streakCount': 7,
      'hoursRemaining': 18,
      'coreActionLabel': 'check-in',
    },
  );
  openClix.ingestEvent(event);
}
