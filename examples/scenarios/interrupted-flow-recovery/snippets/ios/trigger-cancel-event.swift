// Example placement: success/completion handler for campaign cancellation (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/interrupted-flow-recovery/openclix.config.json
// Events used: critical_flow_completed, critical_flow_restarted
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

import Foundation

func triggerinterruptedFlowRecoveryCancel(openClix: OpenClixManagerLike) {
  let event = OpenClixEventLike(name: "critical_flow_completed", appState: .foreground)
  openClix.ingestEvent(event)
  // Alternate cancel path in some apps: critical_flow_restarted
}
