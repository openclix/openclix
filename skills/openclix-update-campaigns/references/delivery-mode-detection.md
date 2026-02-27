# Delivery Mode Detection

Detect how campaign config is delivered at runtime.

## Modes

- `bundle`: config is loaded from in-app resource and applied via `ClixCampaignManager.replaceConfig(...)`.
- `hosted_http`: `ClixConfig.endpoint` points to HTTPS URL and runtime fetches remotely.
- `dual`: hosted endpoint exists with local fallback/load path also present.
- `unknown`: insufficient evidence; require explicit user choice.

## Priority

1. Explicit `--mode` argument.
2. Automatic source-code detection.

## Automatic evidence checks

Look for these signals:

1. HTTP endpoint evidence:
   - `endpoint` assigned to `http://` or `https://`
2. Local bundle evidence:
   - `openclix-config.json` resource load
   - asset/raw/bundle references
3. Replace-config evidence:
   - `ClixCampaignManager.replaceConfig(...)`

## Decision

- `has_http && has_bundle_signal` => `dual`
- `has_http && !has_bundle_signal` => `hosted_http`
- `!has_http && has_bundle_signal` => `bundle`
- otherwise => `unknown`

## Required output

`detect_delivery_mode.sh` returns JSON:

```json
{
  "root": "/abs/path",
  "delivery_mode": "bundle",
  "detection_source": "auto",
  "evidence": {
    "http_endpoint": [],
    "replace_config": ["/abs/path/src/openclix/core/Clix.ts:120:ClixCampaignManager.replaceConfig(...)"],
    "local_config": ["/abs/path/assets/openclix-config.json"]
  }
}
```

If `delivery_mode == unknown`, stop and ask the user to choose one.
