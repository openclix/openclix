// Example placement: feature event handler for campaign enrollment (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/interrupted-flow-recovery/openclix.config.json
// Events used: critical_flow_abandoned
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

import Foundation

func triggerinterruptedFlowRecoveryEntry(openClix: OpenClixManagerLike) {
  let event = OpenClixEventLike(
    name: "critical_flow_abandoned",
    appState: .foreground,
    payload: ["flowKey": "checkout", "flowLabel": "checkout", "intentScore": 80, "resumeDeepLink": "app://checkout/resume"]
  )
  openClix.ingestEvent(event)
}
