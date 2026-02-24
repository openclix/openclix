// Example placement: app startup or feature bootstrap in JS/TS layer (pseudo-code).
// Adapt to: your app architecture, notification integration, and actual OpenClix runtime API names.
// Shared config: examples/scenarios/activation-first-value-rescue/openclix.config.json
// Events used: replaceConfig
// Note: OpenClix APIs shown here are placeholders until the reference SDK is published.

type OpenClixManagerLike = {
  replaceConfig: (config: unknown) => void;
};

export function loadActivationFirstValueRescueConfig(openClix: OpenClixManagerLike, configJsonText: string): void {
  // In a real app, load JSON from bundled assets or embedded config payload.
  const config = JSON.parse(configJsonText);
  openClix.replaceConfig(config);
}
