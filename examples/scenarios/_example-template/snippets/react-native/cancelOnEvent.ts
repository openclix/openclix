// Example placement: target action completion handler in app JS/TS layer (pseudo-code).
// Adapt to: your event tracking layer and local notification cancellation integration.
// Shared config: examples/scenarios/_example-template/openclix.config.json
// Events used: first_action_completed
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

type OpenClixManagerLike = {
  ingestEvent: (event: { name: string; appState: 'foreground' | 'background' }) => void;
};

export function cancelTemplateCampaignAfterFirstAction(openClix: OpenClixManagerLike): void {
  openClix.ingestEvent({
    name: 'first_action_completed',
    appState: 'foreground',
  });
}
