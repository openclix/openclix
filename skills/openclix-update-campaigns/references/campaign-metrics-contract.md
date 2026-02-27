# Campaign Metrics Contract

This file defines `.clix/analytics/campaign-metrics.json` consumed by
`evaluate_campaigns.sh`.

## Required fields

- `status`: `ok` or `insufficient_data`
- `provider`: selected PA provider
- `window.start`, `window.end`: ISO timestamps
- `campaigns`: map keyed by `campaign_id`

## Campaign object fields

- `delivered` (number)
- `opened` (number)
- `open_rate` (number)
- `failed` (number)
- `cancelled` (number)
- `fail_rate` (number)
- `cancel_rate` (number)
- `paused_for_days` (number, optional)
- `active_low_performance_periods` (number, optional)
- `insufficient_data_reasons` (array, optional)

## Example

```json
{
  "status": "ok",
  "provider": "posthog",
  "window": {
    "start": "2026-01-01T00:00:00Z",
    "end": "2026-01-29T00:00:00Z"
  },
  "campaigns": {
    "onboarding-step-1": {
      "delivered": 420,
      "opened": 31,
      "open_rate": 0.0738,
      "failed": 5,
      "cancelled": 102,
      "fail_rate": 0.0119,
      "cancel_rate": 0.2429,
      "paused_for_days": 0,
      "active_low_performance_periods": 1,
      "insufficient_data_reasons": []
    }
  },
  "insufficient_data_reasons": []
}
```

## Notes

- `open_rate` should be `opened / delivered`.
- `fail_rate` should be `failed / delivered`.
- `cancel_rate` should be `cancelled / delivered`.
- When `delivered == 0`, keep rate fields at `0` and include data-quality reason.
