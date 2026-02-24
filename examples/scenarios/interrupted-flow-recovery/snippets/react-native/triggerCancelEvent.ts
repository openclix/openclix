// Example placement: success/completion handler for campaign cancellation in JS/TS layer (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/interrupted-flow-recovery/openclix.config.json
// Events used: critical_flow_completed, critical_flow_restarted
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

type OpenClixManagerLike = {
  ingestEvent: (event: { name: string; appState: 'foreground' | 'background' }) => void;
};

export function triggerInterruptedFlowRecoveryCancel(openClix: OpenClixManagerLike): void {
  openClix.ingestEvent({
    name: 'critical_flow_completed',
    appState: 'foreground',
  });
  // Alternate cancel path in some apps: critical_flow_restarted
}
