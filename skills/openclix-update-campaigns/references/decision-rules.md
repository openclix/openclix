# Decision Rules

Use these rules to produce deterministic campaign actions.

## Defaults

- `apply_mode`: `propose_then_apply`
- `requires_user_confirmation`: `true`
- `minimum_sample`: `delivered >= 200` AND `opened >= 20`
- global trigger: `d7_retention_delta_pp`

## Rule Inputs Per Campaign

- `status` (`running` or `paused`)
- `delivered`
- `opened`
- `open_rate`
- `fail_rate`
- `cancel_rate`
- `paused_for_days` (if paused)
- historical low-performance markers from `update-history.json`

## Rule Outputs

Each campaign gets one action from:

- `pause`
- `resume`
- `update`
- `add`
- `delete`
- `no_change`

## Rule Table

### 1) Pause candidate

Conditions:

- `status == running`
- minimum sample satisfied
- `open_rate < 0.04`
- (`fail_rate > 0.02` OR `cancel_rate > 0.35`)
- low performance repeated (current + previous run)

Output:

- `action = pause`
- patch: replace campaign status to `paused`
- reason codes:
  - `low_open_rate`
  - `high_fail_rate` or `high_cancel_rate`
  - `repeated_low_performance`

### 2) Update candidate

Conditions:

- `status == running`
- minimum sample satisfied
- (`0.04 <= open_rate < 0.08`) OR warning guardrail zones:
  - `0.01 < fail_rate <= 0.02`
  - `0.20 < cancel_rate <= 0.35`

Output:

- `action = update`
- patch type: advisory updates (copy/timing/trigger refinement)
- reason code: `weak_performance_warning`

### 3) Resume candidate

Conditions:

- `status == paused`
- `paused_for_days >= 28`
- global `d7_retention_delta_pp <= -1.0`

Output:

- `action = resume`
- patch: replace campaign status to `running`
- reason codes:
  - `paused_long_enough`
  - `global_retention_decline`

### 4) Delete candidate

Conditions:

- `status == paused`
- `paused_for_days >= 56`
- historical active underperformance count >= 2

Output:

- `action = delete`
- patch: remove campaign object
- reason codes:
  - `paused_too_long`
  - `repeated_active_underperformance`

### 5) Add candidate

Conditions:

- global `d7_retention_delta_pp <= -1.0`
- app profile indicates lifecycle goal gaps not covered by current campaign set

Output:

- `action = add`
- patch: add new draft campaign (safe defaults)
- reason codes:
  - `global_retention_decline`
  - `lifecycle_gap_detected`

## Insufficient Data Policy

If minimum sample is not met for a running campaign:

- `action = no_change`
- reason code: `insufficient_sample`
- include exact shortfall in `metrics_snapshot`

## Conflict Resolution

When multiple rules match for one campaign, priority is:

1. `delete`
2. `pause`
3. `resume`
4. `update`
5. `no_change`
