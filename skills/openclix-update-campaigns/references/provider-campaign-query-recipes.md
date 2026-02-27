# Provider Campaign Query Recipes

Generate `.clix/analytics/campaign-metrics.json` when it is missing.

## Shared mapping

Use `openclix_campaign_id` (or `campaign_id`) as the campaign key.

Event mapping:

- delivered: `clix.message.delivered`
- opened: `clix.message.opened`
- failed: `clix.message.failed`
- cancelled: `clix.message.cancelled`

Compute:

- `open_rate = opened / delivered`
- `fail_rate = failed / delivered`
- `cancel_rate = cancelled / delivered`

## Firebase (BigQuery export)

```sql
SELECT
  (SELECT ep.value.string_value FROM UNNEST(event_params) ep WHERE ep.key = 'openclix_campaign_id') AS campaign_id,
  COUNTIF((SELECT ep2.value.string_value FROM UNNEST(event_params) ep2 WHERE ep2.key = 'openclix_event_name') = 'clix.message.delivered') AS delivered,
  COUNTIF((SELECT ep2.value.string_value FROM UNNEST(event_params) ep2 WHERE ep2.key = 'openclix_event_name') = 'clix.message.opened') AS opened,
  COUNTIF((SELECT ep2.value.string_value FROM UNNEST(event_params) ep2 WHERE ep2.key = 'openclix_event_name') = 'clix.message.failed') AS failed,
  COUNTIF((SELECT ep2.value.string_value FROM UNNEST(event_params) ep2 WHERE ep2.key = 'openclix_event_name') = 'clix.message.cancelled') AS cancelled
FROM `<PROJECT>.<DATASET>.events_*`
WHERE _TABLE_SUFFIX BETWEEN '<START_YYYYMMDD>' AND '<END_YYYYMMDD>'
GROUP BY campaign_id;
```

## PostHog (HogQL)

```sql
SELECT
  coalesce(properties.openclix_campaign_id, properties.campaign_id) AS campaign_id,
  countIf(properties.openclix_event_name = 'clix.message.delivered') AS delivered,
  countIf(properties.openclix_event_name = 'clix.message.opened') AS opened,
  countIf(properties.openclix_event_name = 'clix.message.failed') AS failed,
  countIf(properties.openclix_event_name = 'clix.message.cancelled') AS cancelled
FROM events
WHERE timestamp >= toDateTime('<START_ISO>')
  AND timestamp < toDateTime('<END_ISO>')
GROUP BY campaign_id;
```

## Mixpanel / Amplitude

1. Build event segmentation grouped by campaign property.
2. Export delivered/opened/failed/cancelled counts.
3. Transform into the contract format from `campaign-metrics-contract.md`.

## Output location

Always write campaign metrics to:

- `.clix/analytics/campaign-metrics.json`

Then run evaluator:

```bash
bash skills/openclix-update-campaigns/scripts/evaluate_campaigns.sh --root <target-project-root>
```
