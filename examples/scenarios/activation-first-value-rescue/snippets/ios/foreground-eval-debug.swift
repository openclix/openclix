// Example placement: scene/app foreground lifecycle callback for re-evaluation + debug (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/activation-first-value-rescue/openclix.config.json
// Events used: handleAppForeground, getSnapshot, explain
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

import Foundation

func debugactivationFirstValueRescueOnForeground(openClix: OpenClixManagerLike) {
  openClix.handleAppForeground()
  let snapshot = openClix.getSnapshot()
  print("OpenClix snapshot:", snapshot)

  let trace = openClix.explain(
    campaignId: "activation-first-value-rescue",
    messageId: "gentle-first-value-nudge"
  )
  print("OpenClix explain trace:", trace)
}
