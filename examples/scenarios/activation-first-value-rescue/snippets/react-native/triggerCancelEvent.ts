// Example placement: success/completion handler for campaign cancellation in JS/TS layer (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/activation-first-value-rescue/openclix.config.json
// Events used: first_value_completed, onboarding_step_viewed (optional support event, not required for config)
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

type OpenClixManagerLike = {
  ingestEvent: (event: { name: string; appState: 'foreground' | 'background' }) => void;
};

export function triggerActivationFirstValueRescueCancel(openClix: OpenClixManagerLike): void {
  openClix.ingestEvent({
    name: 'first_value_completed',
    appState: 'foreground',
  });
  // Alternate cancel path in some apps: onboarding_step_viewed (optional support event, not required for config)
}
