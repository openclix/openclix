// Example placement: signup completion handler or onboarding coordinator (pseudo-code).
// Adapt to: your app lifecycle, local notification service, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/_example-template/openclix.config.json
// Events used: user_signed_up
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

import Foundation

func scheduleTemplateCampaignOnSignup(openClix: OpenClixManagerLike) {
  let event = OpenClixEventLike(name: "user_signed_up", appState: .foreground)
  openClix.ingestEvent(event)
}
