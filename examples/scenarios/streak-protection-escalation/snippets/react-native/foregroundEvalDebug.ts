// Example placement: app foreground hook (AppState) for re-evaluation + debug (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/streak-protection-escalation/openclix.config.json
// Events used: handleAppForeground, getSnapshot, explain
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

type OpenClixManagerLike = {
  handleAppForeground: () => void;
  getSnapshot: () => unknown;
  explain: (args: { campaignId: string; messageId?: string }) => unknown;
};

export function debugStreakProtectionEscalationOnForeground(openClix: OpenClixManagerLike): void {
  openClix.handleAppForeground();
  const snapshot = openClix.getSnapshot();
  console.log('OpenClix snapshot', snapshot);

  const trace = openClix.explain({
    campaignId: 'streak-protection-escalation',
    messageId: 'streak-soft-warning',
  });
  console.log('OpenClix explain trace', trace);
}
