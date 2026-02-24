// Example placement: app startup or feature bootstrap (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/streak-protection-escalation/openclix.config.json
// Events used: replaceConfig
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

import Foundation

func loadstreakProtectionEscalationConfig(openClix: OpenClixManagerLike) throws {
  let configPath = "examples/scenarios/streak-protection-escalation/openclix.config.json"
  let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
  let configJSON = try JSONSerialization.jsonObject(with: data)
  try openClix.replaceConfig(configJSON)
}
