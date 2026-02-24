// Example placement: app startup or feature bootstrap (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/activation-first-value-rescue/openclix.config.json
// Events used: replaceConfig
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

import Foundation

func loadactivationFirstValueRescueConfig(openClix: OpenClixManagerLike) throws {
  let configPath = "examples/scenarios/activation-first-value-rescue/openclix.config.json"
  let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
  let configJSON = try JSONSerialization.jsonObject(with: data)
  try openClix.replaceConfig(configJSON)
}
