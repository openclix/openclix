# Provider Query Recipes

Use these templates to extract metrics and fill `.clix-analytics/impact-metrics.json`.

## Shared prerequisites

- OpenClix event contract is already wired.
- Events contain required properties from `event-contract.md`.
- `T0` (campaign go-live timestamp) is known.
- Windows follow `impact-metrics-spec.md` defaults unless user overrides.

---

## Firebase Analytics (BigQuery export)

Use BigQuery exported tables (`events_*`).

### Base filter template

```sql
-- Replace placeholders before running.
DECLARE pre_start TIMESTAMP DEFAULT TIMESTAMP('<PRE_START_ISO>');
DECLARE pre_end TIMESTAMP DEFAULT TIMESTAMP('<PRE_END_ISO>');
DECLARE post_start TIMESTAMP DEFAULT TIMESTAMP('<POST_START_ISO>');
DECLARE post_end TIMESTAMP DEFAULT TIMESTAMP('<POST_END_ISO>');

WITH base AS (
  SELECT
    user_pseudo_id,
    event_name,
    TIMESTAMP_MICROS(event_timestamp) AS event_ts,
    (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'openclix_event_name') AS openclix_event_name
  FROM `<PROJECT>.<DATASET>.events_*`
  WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE(pre_start))
                          AND FORMAT_DATE('%Y%m%d', DATE(post_end + INTERVAL 7 DAY))
)
SELECT * FROM base;
```

### Metric extraction guidance

- `notification_open_rate_*`:
  - delivered: `openclix_event_name = 'clix.message.delivered'`
  - opened: `openclix_event_name = 'clix.message.opened'`
- `sessions_per_user_*`:
  - sessions: `event_name = 'session_start'`
  - active users: distinct `user_pseudo_id`
- `d7_retention_*`:
  - cohort anchor: first `session_start` inside period
  - retained: any `session_start` in day-7 bucket

---

## PostHog (HogQL)

Use HogQL in SQL editor.

### Base events query

```sql
SELECT
  distinct_id,
  event,
  timestamp,
  properties.openclix_event_name AS openclix_event_name
FROM events
WHERE timestamp >= toDateTime('<PRE_START_ISO>')
  AND timestamp < toDateTime('<POST_END_PLUS_7D_ISO>');
```

### Metric extraction guidance

- `notification_open_rate`: count `openclix_event_name` opened/delivered per period.
- `sessions_per_user`: `event = 'session_start'` counts and distinct users.
- `d7_retention`: first session per user in period, then day-7 session existence.

---

## Mixpanel

Use Insights/Retention reports and export CSV for deterministic calculation.

### Recommended steps

1. Define periods (`pre`, `post`) from spec.
2. Retention report:
   - Start event: `session_start`
   - Return criteria: `session_start` at day 7
   - Export pre and post cohorts.
3. Insights report:
   - `clix.message.delivered`
   - `clix.message.opened`
   - `session_start`
4. Compute formulas offline and populate JSON contract.

---

## Amplitude

Use Event Segmentation + Retention charts, then export.

### Recommended steps

1. Retention chart:
   - Start: `session_start`
   - Return: `session_start`
   - Interval: day 7
   - Run for pre and post windows.
2. Event Segmentation:
   - `clix.message.delivered`
   - `clix.message.opened`
   - `session_start`
3. Export counts and compute metrics from `impact-metrics-spec.md`.

---

## Report writing checklist

After queries:

1. Write `.clix-analytics/impact-metrics.json` with exact contract keys.
2. Write `.clix-analytics/impact-report.md` including:
   - period boundaries
   - all required metrics
   - sample sizes
   - insufficient-data notes (when applicable)
   - short interpretation focused on D7 retention delta.
