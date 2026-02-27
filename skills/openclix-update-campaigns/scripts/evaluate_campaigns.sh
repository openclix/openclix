#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
IMPACT_FILE=""
CAMPAIGN_METRICS_FILE=""
CONFIG_FILE=""
APP_PROFILE_FILE=""
HISTORY_FILE=""
RECOMMENDATIONS_FILE=""
NEXT_CONFIG_FILE=""
DELIVERY_MODE=""
MODE_FILE=""
NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --impact-metrics) IMPACT_FILE="$2"; shift 2 ;;
    --campaign-metrics) CAMPAIGN_METRICS_FILE="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --app-profile) APP_PROFILE_FILE="$2"; shift 2 ;;
    --history) HISTORY_FILE="$2"; shift 2 ;;
    --recommendations) RECOMMENDATIONS_FILE="$2"; shift 2 ;;
    --next-config) NEXT_CONFIG_FILE="$2"; shift 2 ;;
    --delivery-mode) DELIVERY_MODE="$2"; shift 2 ;;
    --mode-file) MODE_FILE="$2"; shift 2 ;;
    --now) NOW_UTC="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

ROOT="$(cd "$ROOT" && pwd)"
IMPACT_FILE="${IMPACT_FILE:-$ROOT/.clix/analytics/impact-metrics.json}"
CAMPAIGN_METRICS_FILE="${CAMPAIGN_METRICS_FILE:-$ROOT/.clix/analytics/campaign-metrics.json}"
CONFIG_FILE="${CONFIG_FILE:-$ROOT/.clix/campaigns/openclix-config.json}"
APP_PROFILE_FILE="${APP_PROFILE_FILE:-$ROOT/.clix/campaigns/app-profile.json}"
HISTORY_FILE="${HISTORY_FILE:-$ROOT/.clix/campaigns/update-history.json}"
RECOMMENDATIONS_FILE="${RECOMMENDATIONS_FILE:-$ROOT/.clix/campaigns/update-recommendations.json}"
NEXT_CONFIG_FILE="${NEXT_CONFIG_FILE:-$ROOT/.clix/campaigns/openclix-config.next.json}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if [[ ! -f "$IMPACT_FILE" ]]; then
  echo "Missing required input: $IMPACT_FILE" >&2
  echo "Run openclix-analytics first to create impact metrics." >&2
  exit 2
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing required input: $CONFIG_FILE" >&2
  exit 2
fi

mkdir -p "$(dirname "$CAMPAIGN_METRICS_FILE")" "$(dirname "$RECOMMENDATIONS_FILE")" "$(dirname "$NEXT_CONFIG_FILE")" "$(dirname "$HISTORY_FILE")"

if [[ ! -f "$CAMPAIGN_METRICS_FILE" ]]; then
  jq --arg reason "campaign metrics file missing; generate from provider query recipes" '
    {
      status: "insufficient_data",
      provider: null,
      window: { start: null, end: null },
      campaigns: (
        .campaigns | keys | reduce .[] as $id ({}; .[$id] = {
          delivered: 0,
          opened: 0,
          open_rate: 0,
          failed: 0,
          cancelled: 0,
          fail_rate: 0,
          cancel_rate: 0,
          paused_for_days: 0,
          active_low_performance_periods: 0,
          insufficient_data_reasons: [$reason]
        })
      ),
      insufficient_data_reasons: [$reason]
    }
  ' "$CONFIG_FILE" > "$CAMPAIGN_METRICS_FILE"
fi

if [[ -z "$DELIVERY_MODE" ]]; then
  if [[ -n "$MODE_FILE" && -f "$MODE_FILE" ]]; then
    DELIVERY_MODE="$(jq -r '.delivery_mode // empty' "$MODE_FILE")"
  else
    DETECT_SCRIPT="$ROOT/skills/openclix-update-campaigns/scripts/detect_delivery_mode.sh"
    if [[ -x "$DETECT_SCRIPT" ]]; then
      DELIVERY_MODE="$(bash "$DETECT_SCRIPT" --root "$ROOT" | jq -r '.delivery_mode')"
    fi
  fi
fi
DELIVERY_MODE="${DELIVERY_MODE:-unknown}"

if [[ ! -f "$HISTORY_FILE" ]]; then
  printf '{"version":"v1","runs":[]}\n' > "$HISTORY_FILE"
fi

GLOBAL_D7_DELTA="$(jq -r '.metrics.d7_retention_delta_pp // .d7_retention_delta_pp // 0' "$IMPACT_FILE")"
LIFECYCLE_GAP_DETECTED=0
LIFECYCLE_GAP_DETAILS='null'

if [[ -f "$APP_PROFILE_FILE" ]]; then
  if LIFECYCLE_GAP_DETAILS="$(jq -n --slurpfile app "$APP_PROFILE_FILE" --slurpfile cfg "$CONFIG_FILE" '
    def lifecycle_stages($text):
      ($text // "" | tostring | ascii_downcase) as $t
      | [
          (if ($t | test("onboarding")) then "onboarding" else empty end),
          (if ($t | test("re[- ]?engage|reengagement|reactivat|win[- ]?back")) then "re-engagement" else empty end),
          (if ($t | test("habit|streak|daily|weekly|routine")) then "habit" else empty end),
          (if ($t | test("milestone|achievement|level|progress")) then "milestone" else empty end),
          (if ($t | test("feature[ _-]?discover|adoption|activation")) then "feature-discovery" else empty end)
        ];
    ($app[0] // {}) as $app_profile
    | ($cfg[0] // {}) as $config
    | ($config.campaigns // {}) as $campaigns
    | ([
        ($app_profile.goals // [])[]? | lifecycle_stages(.)[]
      ] + [
        ($app_profile.campaign_design_brief // [])[]? | lifecycle_stages(.id)[]
      ] + [
        ($app_profile.campaign_design_brief // [])[]? | lifecycle_stages(.purpose)[]
      ]) | unique as $desired_stages
    | ([
        ($campaigns | to_entries[]? | (.key + " " + (.value.name // "") + " " + (.value.description // "")))
        | lifecycle_stages(.)[]
      ] | unique) as $covered_stages
    | ([
        ($app_profile.campaign_design_brief // [])[]?
        | .id? as $id
        | select(($id | type) == "string" and (($campaigns | has($id)) | not))
        | $id
      ] | unique) as $missing_brief_ids
    | (($desired_stages - $covered_stages) | unique) as $missing_goal_stages
    | {
        lifecycle_gap_detected: ((($missing_brief_ids | length) > 0) or (($missing_goal_stages | length) > 0)),
        missing_brief_ids: $missing_brief_ids,
        missing_goal_stages: $missing_goal_stages,
        desired_stages: $desired_stages,
        covered_stages: $covered_stages
      }' 2>/dev/null)"; then
    if [[ "$(jq -r '.lifecycle_gap_detected // false' <<< "$LIFECYCLE_GAP_DETAILS")" == "true" ]]; then
      LIFECYCLE_GAP_DETECTED=1
    fi
  else
    LIFECYCLE_GAP_DETAILS='null'
  fi
fi

TMP_ACTIONS="$(mktemp)"
TMP_RUN_CAMPAIGNS="$(mktemp)"
trap 'rm -f "$TMP_ACTIONS" "$TMP_RUN_CAMPAIGNS"' EXIT

mapfile -t CAMPAIGN_IDS < <(jq -r '.campaigns | keys[]' "$CONFIG_FILE")

for CAMPAIGN_ID in "${CAMPAIGN_IDS[@]}"; do
  STATUS="$(jq -r --arg id "$CAMPAIGN_ID" '.campaigns[$id].status // "running"' "$CONFIG_FILE")"

  DELIVERED="$(jq -r --arg id "$CAMPAIGN_ID" '.campaigns[$id].delivered // 0' "$CAMPAIGN_METRICS_FILE")"
  OPENED="$(jq -r --arg id "$CAMPAIGN_ID" '.campaigns[$id].opened // 0' "$CAMPAIGN_METRICS_FILE")"
  OPEN_RATE="$(jq -r --arg id "$CAMPAIGN_ID" '.campaigns[$id].open_rate // (if (.campaigns[$id].delivered // 0) > 0 then ((.campaigns[$id].opened // 0) / (.campaigns[$id].delivered // 0)) else 0 end)' "$CAMPAIGN_METRICS_FILE")"
  FAIL_RATE="$(jq -r --arg id "$CAMPAIGN_ID" '.campaigns[$id].fail_rate // (if (.campaigns[$id].delivered // 0) > 0 then ((.campaigns[$id].failed // 0) / (.campaigns[$id].delivered // 0)) else 0 end)' "$CAMPAIGN_METRICS_FILE")"
  CANCEL_RATE="$(jq -r --arg id "$CAMPAIGN_ID" '.campaigns[$id].cancel_rate // (if (.campaigns[$id].delivered // 0) > 0 then ((.campaigns[$id].cancelled // 0) / (.campaigns[$id].delivered // 0)) else 0 end)' "$CAMPAIGN_METRICS_FILE")"
  PAUSED_FOR_DAYS="$(jq -r --arg id "$CAMPAIGN_ID" '.campaigns[$id].paused_for_days // 0' "$CAMPAIGN_METRICS_FILE")"
  ACTIVE_LOW_PERIODS="$(jq -r --arg id "$CAMPAIGN_ID" '.campaigns[$id].active_low_performance_periods // 0' "$CAMPAIGN_METRICS_FILE")"

  SAMPLE_SUFFICIENT=0
  if [[ "$DELIVERED" -ge 200 && "$OPENED" -ge 20 ]]; then
    SAMPLE_SUFFICIENT=1
  fi

  LOW_PERF_CURRENT=0
  HIGH_FAIL=0
  HIGH_CANCEL=0
  if awk "BEGIN { exit !($FAIL_RATE > 0.02) }"; then HIGH_FAIL=1; fi
  if awk "BEGIN { exit !($CANCEL_RATE > 0.35) }"; then HIGH_CANCEL=1; fi
  if awk "BEGIN { exit !($OPEN_RATE < 0.04) }" && [[ $HIGH_FAIL -eq 1 || $HIGH_CANCEL -eq 1 ]]; then
    LOW_PERF_CURRENT=1
  fi

  PREV_LOW_COUNT="$(jq -r --arg id "$CAMPAIGN_ID" '[.runs[-1:][]? | .campaigns[$id].low_performance_when_running // false | select(.)] | length' "$HISTORY_FILE")"
  REPEATED_LOW=0
  if [[ "$LOW_PERF_CURRENT" -eq 1 && "$PREV_LOW_COUNT" -ge 1 ]]; then
    REPEATED_LOW=1
  fi

  ACTION="no_change"
  REASONS='[]'
  PATCH='null'

  if [[ "$STATUS" == "running" ]]; then
    if [[ "$SAMPLE_SUFFICIENT" -eq 1 ]]; then
      if [[ "$REPEATED_LOW" -eq 1 ]]; then
        ACTION="pause"
        REASONS='["low_open_rate","repeated_low_performance"]'
        if [[ "$HIGH_FAIL" -eq 1 ]]; then
          REASONS='["low_open_rate","high_fail_rate","repeated_low_performance"]'
        fi
        if [[ "$HIGH_CANCEL" -eq 1 ]]; then
          REASONS='["low_open_rate","high_cancel_rate","repeated_low_performance"]'
        fi
        PATCH="$(jq -n --arg id "$CAMPAIGN_ID" '{op:"replace", path:("/campaigns/"+$id+"/status"), value:"paused"}')"
      else
        UPDATE_WARNING=0
        if awk "BEGIN { exit !(($OPEN_RATE >= 0.04 && $OPEN_RATE < 0.08) || ($FAIL_RATE > 0.01 && $FAIL_RATE <= 0.02) || ($CANCEL_RATE > 0.20 && $CANCEL_RATE <= 0.35)) }"; then
          UPDATE_WARNING=1
        fi
        if [[ "$UPDATE_WARNING" -eq 1 ]]; then
          ACTION="update"
          REASONS='["weak_performance_warning"]'
          PATCH="$(jq -n --arg id "$CAMPAIGN_ID" '{op:"advice", campaign_id:$id, changes:[{"path":"message.content","suggestion":"refresh copy and tighten value proposition"},{"path":"trigger.event.delay_seconds","suggestion":"re-test send timing"},{"path":"trigger.event.trigger_event","suggestion":"narrow event condition"}]}')"
        fi
      fi
    else
      ACTION="no_change"
      REASONS='["insufficient_sample"]'
    fi
  elif [[ "$STATUS" == "paused" ]]; then
    if [[ "$PAUSED_FOR_DAYS" -ge 56 && "$ACTIVE_LOW_PERIODS" -ge 2 ]]; then
      ACTION="delete"
      REASONS='["paused_too_long","repeated_active_underperformance"]'
      PATCH="$(jq -n --arg id "$CAMPAIGN_ID" '{op:"remove", path:("/campaigns/"+$id)}')"
    elif [[ "$PAUSED_FOR_DAYS" -ge 28 ]] && awk "BEGIN { exit !($GLOBAL_D7_DELTA <= -1.0) }"; then
      ACTION="resume"
      REASONS='["paused_long_enough","global_retention_decline"]'
      PATCH="$(jq -n --arg id "$CAMPAIGN_ID" '{op:"replace", path:("/campaigns/"+$id+"/status"), value:"running"}')"
    fi
  fi

  jq -n \
    --arg campaign_id "$CAMPAIGN_ID" \
    --arg action "$ACTION" \
    --argjson reason_codes "$REASONS" \
    --argjson delivered "$DELIVERED" \
    --argjson opened "$OPENED" \
    --argjson open_rate "$OPEN_RATE" \
    --argjson fail_rate "$FAIL_RATE" \
    --argjson cancel_rate "$CANCEL_RATE" \
    --argjson sample_sufficient "$SAMPLE_SUFFICIENT" \
    --argjson proposed_patch "$PATCH" \
    '{
      campaign_id: $campaign_id,
      action: $action,
      reason_codes: $reason_codes,
      metrics_snapshot: {
        delivered: $delivered,
        opened: $opened,
        open_rate: $open_rate,
        fail_rate: $fail_rate,
        cancel_rate: $cancel_rate,
        sample_sufficient: ($sample_sufficient == 1)
      },
      proposed_patch: $proposed_patch
    }' >> "$TMP_ACTIONS"

  jq -n \
    --arg id "$CAMPAIGN_ID" \
    --arg status "$STATUS" \
    --argjson low "$LOW_PERF_CURRENT" \
    --argjson sample "$SAMPLE_SUFFICIENT" \
    --argjson paused_days "$PAUSED_FOR_DAYS" \
    '{
      key: $id,
      value: {
        status: $status,
        low_performance_when_running: (($status == "running") and ($low == 1)),
        sample_sufficient: ($sample == 1),
        paused_for_days: $paused_days
      }
    }' >> "$TMP_RUN_CAMPAIGNS"
done

if [[ -f "$APP_PROFILE_FILE" && "$LIFECYCLE_GAP_DETECTED" -eq 1 ]] && awk "BEGIN { exit !($GLOBAL_D7_DELTA <= -1.0) }"; then
  ADD_ACTION_JSON="$(jq -n \
    --arg id "reengagement-recovery-1" \
    --argjson lifecycle_gap "$LIFECYCLE_GAP_DETAILS" \
    '{
      campaign_id: $id,
      action: "add",
      reason_codes: ["global_retention_decline","lifecycle_gap_detected"],
      metrics_snapshot: {
        lifecycle_gap_signal: $lifecycle_gap
      },
      proposed_patch: {
        op: "add",
        path: ("/campaigns/" + $id),
        value: {
          name: "Re-engagement Recovery 1",
          type: "campaign",
          description: "Generated from retention decline + lifecycle gap signal.",
          status: "paused",
          trigger: {
            type: "event",
            event: {
              trigger_event: {
                connector: "and",
                conditions: [
                  {
                    field: "name",
                    operator: "equal",
                    values: ["replace_with_event_name"]
                  }
                ]
              },
              delay_seconds: 3600
            }
          },
          message: {
            channel_type: "app_push",
            content: {
              title: "Need a quick restart?",
              body: "Come back now and continue your key flow."
            }
          }
        }
      }
    }')"
  printf '%s\n' "$ADD_ACTION_JSON" >> "$TMP_ACTIONS"
fi

ACTIONS_JSON="$(jq -s '.' "$TMP_ACTIONS")"
RUN_CAMPAIGNS_MAP="$(jq -s 'from_entries' "$TMP_RUN_CAMPAIGNS")"

jq \
  --arg now "$NOW_UTC" \
  --arg delivery_mode "$DELIVERY_MODE" \
  --argjson actions "$ACTIONS_JSON" \
  --argjson global_d7 "$GLOBAL_D7_DELTA" \
  '{
    generated_at: $now,
    apply_mode: "propose_then_apply",
    requires_user_confirmation: true,
    delivery_mode: $delivery_mode,
    global_metrics: {
      d7_retention_delta_pp: $global_d7
    },
    actions: $actions
  }' "$IMPACT_FILE" > "$RECOMMENDATIONS_FILE"

cp "$CONFIG_FILE" "$NEXT_CONFIG_FILE"

while IFS= read -r ACTION_ROW; do
  ACTION_KIND="$(jq -r '.action' <<<"$ACTION_ROW")"
  CAMPAIGN_ID="$(jq -r '.campaign_id' <<<"$ACTION_ROW")"

  case "$ACTION_KIND" in
    pause)
      jq --arg id "$CAMPAIGN_ID" '.campaigns[$id].status = "paused"' "$NEXT_CONFIG_FILE" > "$NEXT_CONFIG_FILE.tmp"
      mv "$NEXT_CONFIG_FILE.tmp" "$NEXT_CONFIG_FILE"
      ;;
    resume)
      jq --arg id "$CAMPAIGN_ID" '.campaigns[$id].status = "running"' "$NEXT_CONFIG_FILE" > "$NEXT_CONFIG_FILE.tmp"
      mv "$NEXT_CONFIG_FILE.tmp" "$NEXT_CONFIG_FILE"
      ;;
    delete)
      jq --arg id "$CAMPAIGN_ID" 'del(.campaigns[$id])' "$NEXT_CONFIG_FILE" > "$NEXT_CONFIG_FILE.tmp"
      mv "$NEXT_CONFIG_FILE.tmp" "$NEXT_CONFIG_FILE"
      ;;
    add)
      jq --arg id "$CAMPAIGN_ID" --argjson value "$(jq -c '.proposed_patch.value' <<<"$ACTION_ROW")" '.campaigns[$id] = $value' "$NEXT_CONFIG_FILE" > "$NEXT_CONFIG_FILE.tmp"
      mv "$NEXT_CONFIG_FILE.tmp" "$NEXT_CONFIG_FILE"
      ;;
    update|no_change)
      ;;
  esac
done < <(jq -c '.actions[]' "$RECOMMENDATIONS_FILE")

RUN_ENTRY="$(jq -n \
  --arg evaluated_at "$NOW_UTC" \
  --argjson d7 "$GLOBAL_D7_DELTA" \
  --argjson campaigns "$RUN_CAMPAIGNS_MAP" \
  '{
    evaluated_at: $evaluated_at,
    global: { d7_retention_delta_pp: $d7 },
    campaigns: $campaigns
  }')"

jq --argjson run "$RUN_ENTRY" '
  .version = "v1"
  | .runs = (((.runs // []) + [$run]) | if length > 100 then .[length-100:] else . end)
' "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

printf 'Wrote:\n'
printf '  - %s\n' "$RECOMMENDATIONS_FILE"
printf '  - %s\n' "$NEXT_CONFIG_FILE"
printf '  - %s\n' "$HISTORY_FILE"
