// Example placement: feature event handler for campaign enrollment in JS/TS layer (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/activation-first-value-rescue/openclix.config.json
// Events used: user_signed_up
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

type OpenClixManagerLike = {
  ingestEvent: (event: { name: string; appState: 'foreground' | 'background'; payload?: Record<string, unknown> }) => void;
};

export function triggerActivationFirstValueRescueEntry(openClix: OpenClixManagerLike): void {
  openClix.ingestEvent({
    name: 'user_signed_up',
    appState: 'foreground'
  });
}
