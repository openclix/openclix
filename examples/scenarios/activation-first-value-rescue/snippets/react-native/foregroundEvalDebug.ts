// Example placement: app foreground hook (AppState) for re-evaluation + debug (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/activation-first-value-rescue/openclix.config.json
// Events used: handleAppForeground, getSnapshot, explain
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

type OpenClixManagerLike = {
  handleAppForeground: () => void;
  getSnapshot: () => unknown;
  explain: (args: { campaignId: string; messageId?: string }) => unknown;
};

export function debugActivationFirstValueRescueOnForeground(openClix: OpenClixManagerLike): void {
  openClix.handleAppForeground();
  const snapshot = openClix.getSnapshot();
  console.log('OpenClix snapshot', snapshot);

  const trace = openClix.explain({
    campaignId: 'activation-first-value-rescue',
    messageId: 'gentle-first-value-nudge',
  });
  console.log('OpenClix explain trace', trace);
}
