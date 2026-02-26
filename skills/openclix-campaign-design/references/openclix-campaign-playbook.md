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

## 6) Keep Copy Personal But Controlled

Message templates support `{{key}}` placeholders resolved from event payloads.
Use only verified keys from the app profile.

Practical copy defaults:

- title <= 45 chars
- body <= 140 chars

Hard schema limits:

- title <= 120
- body <= 500

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

## 8) Final Pre-Handoff Checks

Before presenting output:

- run `jq .` on all JSON outputs
- verify campaign IDs are kebab-case
- verify all trigger-specific required fields exist
- verify unknown fields are absent
- verify every campaign message has both title and body

## 9) Resource Installation And Runtime Wiring

When the task includes app implementation, complete these steps after config generation.

### A) Pick Resource Path From Existing Project Convention

Inspect existing JSON/resource usage first, then follow it:

- React Native / Expo: existing `assets/` or app-level resource folder.
- Flutter: existing asset folder pattern and `pubspec.yaml` declaration style.
- iOS: existing app target bundle resource groups.
- Android: existing `app/src/main/assets` or `res/raw` usage.

Do not invent a parallel resource strategy if the app already has one.

### B) Apply Config At Runtime (Local Resource Path)

For local config JSON, use this sequence:

1. Initialize Clix.
2. Read JSON from bundled resource file.
3. Parse into OpenClix `Config`.
4. Call `ClixCampaignManager.replaceConfig(parsedConfig)`.

Reason: `Clix.initialize(...)` auto-loads only HTTP(S) endpoints; non-HTTP endpoints require explicit config replacement.

### C) Minimize Integration Diff

- Update only startup/bootstrapping code paths already used by the app.
- Preserve project logging/error handling style.
- Avoid unnecessary refactors while wiring resource load + config replacement.
