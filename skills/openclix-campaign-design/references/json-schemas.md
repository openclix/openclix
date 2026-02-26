# JSON Schemas

This skill uses two artifacts:

- `.clix-campaigns/app-profile.json` for planning context
- `.clix-campaigns/openclix-config.json` (or user target path) for executable OpenClix config

For implementation tasks, this skill also produces one integration artifact:

- an in-app resource copy of the final config JSON at a project-convention path

## Strict Schema Files

Formal schema files live in `references/schemas/`:

- `app-profile.schema.json` validates planning inputs before campaign design
- `openclix.schema.json` validates executable OpenClix config

Validate after every major update. Fix schema violations before presenting final config.

## App Profile JSON (Planning)

Use this shape to capture campaign design context:

```json
{
  "app_name": "PulseHabit",
  "platform": "react-native",
  "domain": "habit",
  "summary": "Daily habit tracker with streaks and milestone progress.",
  "goals": [
    "Convert new users to first check-in",
    "Protect active streaks",
    "Re-engage users after inactivity"
  ],
  "core_user_activity": {
    "action": "complete_daily_check_in",
    "success_signal": "weekly_active_days >= 5"
  },
  "event_taxonomy": {
    "events": [
      {
        "name": "user_signup_completed",
        "description": "User finished onboarding",
        "properties": [
          {
            "key": "user_name",
            "type": "string",
            "description": "Display name"
          }
        ]
      },
      {
        "name": "habit_check_in_completed",
        "description": "User completed daily check-in",
        "properties": [
          {
            "key": "streak_days",
            "type": "number",
            "description": "Current streak length"
          }
        ]
      }
    ]
  },
  "personalization_variables": [
    {
      "key": "user_name",
      "source": "event:user_signup_completed.user_name",
      "example": "Alex"
    },
    {
      "key": "streak_days",
      "source": "event:habit_check_in_completed.streak_days",
      "example": 7
    }
  ],
  "existing_campaign_ids": [
    "daily-reminder"
  ],
  "constraints": {
    "do_not_disturb": {
      "start_hour": 22,
      "end_hour": 8
    },
    "frequency_cap": {
      "max_count": 3,
      "window_seconds": 86400
    },
    "timezone_policy": "device_local"
  },
  "campaign_design_brief": [
    {
      "id": "onboarding-step-1",
      "purpose": "Nudge first check-in after signup",
      "target_event": "user_signup_completed",
      "trigger_type": "event"
    }
  ]
}
```

## OpenClix Config JSON (Execution)

`openclix.schema.json` is the source of truth. Key constraints:

- `schema_version` must be `openclix/config/v1`
- campaign keys must be kebab-case
- one campaign has one `message`
- `trigger.type` must be `event`, `scheduled`, or `recurring`
- `status` must be `running` or `paused`
- message content supports `{{key}}` templating

Minimal valid example:

```json
{
  "schema_version": "openclix/config/v1",
  "config_version": "rev-2026-02-26-a",
  "settings": {
    "frequency_cap": {
      "max_count": 3,
      "window_seconds": 86400
    },
    "do_not_disturb": {
      "start_hour": 22,
      "end_hour": 8
    }
  },
  "campaigns": {
    "onboarding-step-1": {
      "name": "Onboarding Step 1",
      "type": "campaign",
      "description": "Nudge the user to complete first check-in.",
      "status": "running",
      "trigger": {
        "type": "event",
        "event": {
          "trigger_event": {
            "connector": "and",
            "conditions": [
              {
                "field": "name",
                "operator": "equal",
                "values": ["user_signup_completed"]
              }
            ]
          },
          "delay_seconds": 7200,
          "cancel_event": {
            "connector": "and",
            "conditions": [
              {
                "field": "name",
                "operator": "equal",
                "values": ["habit_check_in_completed"]
              }
            ]
          }
        }
      },
      "message": {
        "channel_type": "app_push",
        "content": {
          "title": "{{user_name}}, first check-in?",
          "body": "Keep momentum today. One tap and your streak starts."
        }
      }
    }
  }
}
```

## Design-To-Schema Mapping

| Design intent | Schema path |
| --- | --- |
| Global quiet hours | `settings.do_not_disturb` |
| Global message throttle | `settings.frequency_cap` |
| Behavior-triggered campaign | `campaigns.<id>.trigger.event.trigger_event` |
| Cancel pending delayed trigger | `campaigns.<id>.trigger.event.cancel_event` |
| One-time scheduled push | `campaigns.<id>.trigger.scheduled.execute_at` |
| Recurring cadence | `campaigns.<id>.trigger.recurring.rule` |
| Notification copy | `campaigns.<id>.message.content.title/body` |

## Delivery Targets

When the user requests code integration, produce both:

1. Authoring artifact: `.clix-campaigns/openclix-config.json` (or user-specified target)
2. Runtime artifact: app resource JSON copied into the project's existing resource location

Then wire startup logic to load the runtime artifact and apply it through `ClixCampaignManager.replaceConfig(...)`.
