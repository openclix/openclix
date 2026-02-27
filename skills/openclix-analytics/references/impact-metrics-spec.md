# Impact Metrics Specification (Pre/Post)

Use this spec to decide whether OpenClix campaigns improved retention and engagement.

## Analysis defaults

- North star metric: `7-day retention`
- Supporting metrics:
  - `notification_open_rate`
  - `sessions_per_user`
- Window defaults:
  - `pre`: 28 days before campaign go-live
  - `stabilization_exclusion`: first 7 days after go-live (excluded)
  - `post`: next 28 days after stabilization

### Boundary formulas

Given campaign go-live timestamp `T0`:

- `pre_start = T0 - 28d`
- `pre_end = T0`
- `post_start = T0 + 7d`
- `post_end = T0 + 35d`

## Metric definitions

### 1) d7_retention

For each period:

- Cohort users: users whose first session event falls within the period.
- Retained users: cohort users with at least one session event in day-7 bucket (`first_session_at + [7d, 8d)`).
- Formula:
  - `d7_retention = retained_users / cohort_users`

### 2) notification_open_rate

For each period:

- Opened count: `clix.message.opened` events.
- Delivered count: `clix.message.delivered` events.
- Formula:
  - `notification_open_rate = opened_count / delivered_count`

### 3) sessions_per_user

For each period:

- Session count: `session_start` (or app session equivalent) events.
- Active users: distinct users with at least one session event in period.
- Formula:
  - `sessions_per_user = session_count / active_users`

### Delta field

- `d7_retention_delta_pp = (d7_retention_post - d7_retention_pre) * 100`

## Data quality rules

Return `status: insufficient_data` when any condition fails:

- `cohort_users_pre < 100` or `cohort_users_post < 100`
- `delivered_count_pre < 30` or `delivered_count_post < 30`
- Required events are missing from provider data

When insufficient:

- Keep numeric fields nullable.
- Populate `insufficient_data_reasons` with exact blockers.
- State minimum additional data needed.

## Output contract

Write both files under target project:

- `.clix/analytics/impact-metrics.json`
- `.clix/analytics/impact-report.md`

### impact-metrics.json shape

```json
{
  "status": "ok",
  "provider": "firebase",
  "campaign_live_at": "2026-02-01T00:00:00Z",
  "windows": {
    "pre_start": "2026-01-04T00:00:00Z",
    "pre_end": "2026-02-01T00:00:00Z",
    "post_start": "2026-02-08T00:00:00Z",
    "post_end": "2026-03-08T00:00:00Z"
  },
  "metrics": {
    "d7_retention_pre": 0.182,
    "d7_retention_post": 0.219,
    "d7_retention_delta_pp": 3.7,
    "notification_open_rate_pre": 0.114,
    "notification_open_rate_post": 0.151,
    "sessions_per_user_pre": 3.42,
    "sessions_per_user_post": 3.95
  },
  "samples": {
    "cohort_users_pre": 1402,
    "cohort_users_post": 1511,
    "delivered_count_pre": 953,
    "delivered_count_post": 1222,
    "opened_count_pre": 109,
    "opened_count_post": 185
  },
  "insufficient_data_reasons": []
}
```
