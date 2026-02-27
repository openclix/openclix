# OpenClix Analytics Event Contract

This contract defines what must be forwarded to the selected PA provider.

## Event naming

- Keep canonical OpenClix event names.
- System events:
  - `clix.message.scheduled`
  - `clix.message.delivered`
  - `clix.message.opened`
  - `clix.message.cancelled`
  - `clix.message.failed`
- App events: use original app event name from `Clix.trackEvent(name, ...)`.

## Required properties

All forwarded events must include these properties.

| Key | Type | Source |
| --- | --- | --- |
| `openclix_source` | string | Constant `"openclix"` |
| `openclix_event_name` | string | Canonical event name before provider transforms |
| `openclix_source_type` | string | `app` or `system` |
| `openclix_platform` | string | `expo`, `react-native`, `flutter`, `ios`, `android` |
| `openclix_campaign_id` | string \| null | `properties.campaign_id` when present |
| `openclix_queued_message_id` | string \| null | `properties.queued_message_id` when present |
| `openclix_channel_type` | string \| null | `properties.channel_type` when present |
| `openclix_analysis_period` | string | `pre` or `post` |
| `openclix_campaign_active` | string | `"true"` or `"false"` |

Keep existing event properties and merge these fields on top.

## Firebase event-name normalization

Firebase event naming constraints require a provider-specific transform.

- Only for Firebase transport, transform canonical name to a valid Firebase event key.
- Preserve canonical name in `openclix_event_name`.

Reference transform:

1. Lowercase name.
2. Replace characters outside `[a-z0-9_]` with `_`.
3. Prefix with `oc_` if first char is not a letter.
4. Trim to provider max length.

## Forwarding points (must wire both)

- App event path (`trackEvent`) forwarding.
- System event path (`trackSystemEvent`) forwarding.

Do not wire only one path.

## Example payload

```json
{
  "event_name": "clix.message.opened",
  "properties": {
    "campaign_id": "onboarding-step-1",
    "queued_message_id": "5ef3f3b2-9bb2-4fbe-95f3-2901f4fba0f2",
    "channel_type": "app_push",
    "openclix_source": "openclix",
    "openclix_event_name": "clix.message.opened",
    "openclix_source_type": "system",
    "openclix_platform": "react-native",
    "openclix_campaign_id": "onboarding-step-1",
    "openclix_queued_message_id": "5ef3f3b2-9bb2-4fbe-95f3-2901f4fba0f2",
    "openclix_channel_type": "app_push",
    "openclix_analysis_period": "post",
    "openclix_campaign_active": "true"
  }
}
```
