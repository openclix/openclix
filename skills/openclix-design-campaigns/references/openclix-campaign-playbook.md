# OpenClix Campaign Playbook

Use this guide to turn product goals into robust OpenClix campaigns.

## 1) Pick The Right Trigger Model

Use this matrix:

| Goal shape | Trigger type | Why |
| --- | --- | --- |
| React to user/app behavior | `event` | Executes only when the observed behavior happens |
| Deliver at one known time | `scheduled` | Deterministic one-shot campaign |
| Repeat on a cadence | `recurring` | Handles daily/weekly/hourly loops |

## 2) Decompose Multi-Step Journeys

OpenClix campaigns deliver one message each.
Represent a journey as grouped campaign IDs:

- `onboarding-step-1`
- `onboarding-step-2`
- `onboarding-step-3`

Keep purpose explicit in each campaign description.

## 3) Build Event Conditions Safely

Prefer exact matches first:

- Match event name with `field: "name"` + `operator: "equal"`
- Add property filters with `field: "property"` + `property_name`

Use `connector: "and"` unless explicit alternatives are required.

Example:

```json
{
  "connector": "and",
  "conditions": [
    {
      "field": "name",
      "operator": "equal",
      "values": ["habit_check_in_completed"]
    },
    {
      "field": "property",
      "property_name": "streak_days",
      "operator": "greater_than_or_equal",
      "values": ["3"]
    }
  ]
}
```

## 4) Use Delay And Cancel For Intent Integrity

For nudges that should not fire after success:

- set `delay_seconds` (for example 3600 or 7200)
- add `cancel_event` with the success event condition

This prevents stale reminders from being delivered after the user already completed the target action.

## 5) Set Global Guardrails Early

Before adding many campaigns, define:

- `settings.do_not_disturb` for quiet hours
- `settings.frequency_cap` for fatigue protection

Avoid duplicating these protections per campaign.

Also evaluate campaign-level `frequency_cap` for high-volume triggers.

## 6) Keep Copy Personal But Controlled

Message templates support `{{key}}` placeholders resolved from event payloads.
Use only verified keys from the app profile.

Practical copy defaults:

- title <= 45 chars
- body <= 140 chars

Hard schema limits:

- title <= 120
- body <= 500

Also evaluate optional message fields when relevant:

- `image_url` for rich-notification visuals
- `landing_url` for deep-link routing

## 7) Recurring Pattern Templates

### Daily reminder

```json
{
  "type": "recurring",
  "recurring": {
    "rule": {
      "type": "daily",
      "interval": 1,
      "time_of_day": {
        "hour": 20,
        "minute": 30
      }
    }
  }
}
```

### Weekly reminder

```json
{
  "type": "recurring",
  "recurring": {
    "rule": {
      "type": "weekly",
      "interval": 1,
      "weekly_rule": {
        "days_of_week": ["monday", "wednesday", "friday"]
      },
      "time_of_day": {
        "hour": 19,
        "minute": 0
      }
    }
  }
}
```

## 8) Feature Coverage Pass (Mandatory For New Campaigns)

Before finalizing config, explicitly evaluate all configurable levers in schema:

- global: `settings.frequency_cap`, `settings.do_not_disturb`
- campaign: `frequency_cap`
- event triggers: `delay_seconds`, `cancel_event`
- recurring triggers: `start_at`, `end_at`, `rule.interval`, `weekly_rule.days_of_week`, `time_of_day`
- message: `image_url`, `landing_url`, verified `{{key}}` placeholders

Use all relevant levers. If you skip a lever, document why.

## 9) Final Pre-Handoff Checks

Before presenting output:

- run `jq .` on all JSON outputs
- verify campaign IDs are kebab-case
- verify all trigger-specific required fields exist
- verify unknown fields are absent
- verify every campaign message has both title and body

## 10) Delivery Mode Decision And Runtime Wiring

When the task includes app implementation, complete these steps after config generation.

### A) Inspect Current OpenClix Wiring And Ask For Delivery Mode

Before code changes:

1. Find existing `OpenClix.initialize(...)` call sites and current `OpenClixConfig.endpoint`.
2. Find any existing `OpenClixCampaignManager.replaceConfig(...)` usage.
3. If OpenClix integration is missing, run `openclix-init` first.
4. Ask the user to choose delivery mode unless already specified:
   - Bundle config in app package
   - Host config on user's HTTP server (HTTPS)

### B) Bundle Mode

If user chooses bundle mode:

1. Resolve the runtime path in this order:
   - existing loader path in code (preferred)
   - fallback defaults when loader path does not exist yet:
     - React Native / Expo: `assets/openclix/openclix-config.json`
     - Flutter: `assets/openclix/openclix-config.json` + `pubspec.yaml` registration
     - iOS: `<app-target>/OpenClix/openclix-config.json` + Copy Bundle Resources entry
     - Android: `app/src/main/assets/openclix/openclix-config.json`
2. Copy generated config JSON to that exact path.
3. Keep filename lowercase `openclix-config.json` unless existing code already references a different filename.
4. Set `OpenClixConfig.endpoint` to the same bundled-path identifier used by the app.
5. Initialize OpenClix, then read JSON from that exact bundled path, parse into `Config`, and call `OpenClixCampaignManager.replaceConfig(parsedConfig)`.
6. Verify path parity: copied path, loader reference, and endpoint identifier all match.

Reason: `OpenClix.initialize(...)` auto-loads only HTTP(S) endpoints; non-HTTP endpoints require explicit config replacement.

### C) Hosted HTTP Mode

If user chooses hosted mode:

1. Confirm target hosting environment and deploy access method from the user.
2. Upload generated config JSON and publish through HTTPS.
3. Set `OpenClixConfig.endpoint` to the deployed HTTPS URL.
4. Keep local fallback only when user explicitly requests dual-path behavior.

### D) Minimize Integration Diff

- Update only startup/bootstrapping code paths already used by the app.
- Preserve project logging/error handling style.
- Avoid unnecessary refactors while wiring delivery mode-specific config loading.
