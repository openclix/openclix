// Example placement: signup success handler in app JS/TS layer (pseudo-code).
// Adapt to: your notification library integration and native bridge bindings.
// Shared config: examples/scenarios/_example-template/openclix.config.json
// Events used: user_signed_up
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

type OpenClixManagerLike = {
  ingestEvent: (event: { name: string; appState: 'foreground' | 'background' }) => void;
};

export function scheduleTemplateCampaignOnSignup(openClix: OpenClixManagerLike): void {
  openClix.ingestEvent({
    name: 'user_signed_up',
    appState: 'foreground',
  });
}
