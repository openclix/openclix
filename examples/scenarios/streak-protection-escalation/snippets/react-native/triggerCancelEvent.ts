// Example placement: success/completion handler for campaign cancellation in JS/TS layer (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/streak-protection-escalation/openclix.config.json
// Events used: streak_extended, streak_reset
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

type OpenClixManagerLike = {
  ingestEvent: (event: { name: string; appState: 'foreground' | 'background' }) => void;
};

export function triggerStreakProtectionEscalationCancel(openClix: OpenClixManagerLike): void {
  openClix.ingestEvent({
    name: 'streak_extended',
    appState: 'foreground',
  });
  // Alternate cancel path in some apps: streak_reset
}
