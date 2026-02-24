// Example placement: first action completion callback (pseudo-code).
// Adapt to: your event bus and local notification cancellation hooks.
// Shared config: examples/scenarios/_example-template/openclix.config.json
// Events used: first_action_completed
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

import Foundation

func cancelTemplateCampaignAfterFirstAction(openClix: OpenClixManagerLike) {
  let event = OpenClixEventLike(name: "first_action_completed", appState: .foreground)
  openClix.ingestEvent(event)
}
