#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
AGENT="all"
DELIVERY_MODE="auto"
IMPACT_FILE=""
CAMPAIGN_METRICS_FILE=""
CONFIG_FILE=""
OUTPUT_DIR=""
DRY_RUN=0

EXIT_USAGE=64
EXIT_PREREQ=10
EXIT_NO_PROVIDER=20
EXIT_OPENCLIX_MISSING=21
EXIT_INPUT_MISSING=30
EXIT_MODE_UNKNOWN=31
EXIT_EVALUATOR_FAILED=40

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/retention_ops_automation.sh [options]

Options:
  --root <path>                     Target project root (default: current directory)
  --agent <openclaw|claude-code|codex|all>
                                    Agent prompt set to generate (default: all)
  --delivery-mode <auto|bundle|hosted_http|dual>
                                    Delivery mode for evaluation (default: auto)
  --impact-file <path>              Path to impact-metrics.json
  --campaign-metrics-file <path>    Path to campaign-metrics.json
  --config-file <path>              Path to openclix-config.json
  --output-dir <path>               Output directory (default: .clix/automation)
  --dry-run                         Keep evaluator outputs inside output directory only
  --help                            Show this help

Exit codes:
  0   success
  10  missing prerequisite command/script
  20  no supported product analytics provider detected
  21  OpenClix integration not detected
  30  required input artifacts missing
  31  delivery mode unresolved (unknown)
  40  evaluator execution failed
  64  invalid usage
USAGE
}

resolve_path() {
  local base="$1"
  local path="$2"

  if [[ "$path" = /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$base" "$path"
  fi
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf '[error] required command not found: %s\n' "$cmd" >&2
    exit "$EXIT_PREREQ"
  fi
}

write_summary() {
  local status="$1"
  local exit_code="$2"
  local message="$3"

  local installed_providers='[]'
  local selected_provider=''
  local selected_mode_json='null'
  local mode_evidence='null'

  if [[ -f "$PROVIDER_JSON" ]]; then
    installed_providers="$(jq '.installed_providers // []' "$PROVIDER_JSON")"
    selected_provider="$(jq -r '.selected_provider // ""' "$PROVIDER_JSON")"
  fi

  if [[ -n "${SELECTED_MODE:-}" ]]; then
    selected_mode_json="\"${SELECTED_MODE}\""
  fi

  if [[ -f "$MODE_JSON" ]]; then
    mode_evidence="$(jq '.evidence // null' "$MODE_JSON")"
  fi

  jq -n \
    --arg generated_at_utc "$NOW_UTC" \
    --arg status "$status" \
    --arg message "$message" \
    --argjson exit_code "$exit_code" \
    --arg root "$ROOT" \
    --arg agent "$AGENT" \
    --argjson selected_agents "$SELECTED_AGENTS_JSON" \
    --argjson dry_run "$( [[ "$DRY_RUN" -eq 1 ]] && echo true || echo false )" \
    --arg requested_delivery_mode "$DELIVERY_MODE" \
    --argjson selected_delivery_mode "$selected_mode_json" \
    --arg impact_file "$IMPACT_FILE" \
    --arg campaign_metrics_file "$EVAL_CAMPAIGN_METRICS_FILE" \
    --arg config_file "$CONFIG_FILE" \
    --arg output_dir "$OUTPUT_DIR" \
    --arg recommendations_file "$RECOMMENDATIONS_FILE" \
    --arg next_config_file "$NEXT_CONFIG_FILE" \
    --arg history_file "$HISTORY_FILE" \
    --arg provider_detection_file "$PROVIDER_JSON" \
    --arg delivery_mode_file "$MODE_JSON" \
    --argjson installed_providers "$installed_providers" \
    --arg selected_provider "$selected_provider" \
    --argjson delivery_mode_evidence "$mode_evidence" \
    --argjson prompts "$PROMPT_PATHS_JSON" \
    --arg run_summary_file "$RUN_SUMMARY_FILE" \
    '{
      generated_at_utc: $generated_at_utc,
      status: $status,
      exit_code: $exit_code,
      message: $message,
      root: $root,
      dry_run: $dry_run,
      agent_request: $agent,
      selected_agents: $selected_agents,
      delivery_mode: {
        requested: $requested_delivery_mode,
        selected: $selected_delivery_mode,
        evidence: $delivery_mode_evidence
      },
      inputs: {
        impact_file: $impact_file,
        campaign_metrics_file: $campaign_metrics_file,
        config_file: $config_file
      },
      evaluator_outputs: {
        recommendations_file: $recommendations_file,
        next_config_file: $next_config_file,
        history_file: $history_file
      },
      provider_detection: {
        file: $provider_detection_file,
        installed_providers: $installed_providers,
        selected_provider: (if $selected_provider == "" then null else $selected_provider end)
      },
      artifacts: {
        run_summary: $run_summary_file,
        prompts: $prompts,
        delivery_mode_file: $delivery_mode_file
      },
      guardrails: {
        confirmation_gate_required: true,
        openclaw_supply_chain_note: "Treat OpenClaw skills/plugins as untrusted until source-reviewed and sandboxed."
      }
    }' > "$RUN_SUMMARY_FILE"
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

render_template() {
  local template_file="$1"
  local output_file="$2"

  local root_esc impact_esc campaign_esc config_esc mode_esc provider_esc rec_esc next_esc dry_esc
  root_esc="$(escape_sed_replacement "$ROOT")"
  impact_esc="$(escape_sed_replacement "$IMPACT_FILE")"
  campaign_esc="$(escape_sed_replacement "$EVAL_CAMPAIGN_METRICS_FILE")"
  config_esc="$(escape_sed_replacement "$CONFIG_FILE")"
  mode_esc="$(escape_sed_replacement "$SELECTED_MODE")"
  provider_esc="$(escape_sed_replacement "$SELECTED_PROVIDER")"
  rec_esc="$(escape_sed_replacement "$RECOMMENDATIONS_FILE")"
  next_esc="$(escape_sed_replacement "$NEXT_CONFIG_FILE")"
  dry_esc="$( [[ "$DRY_RUN" -eq 1 ]] && echo true || echo false )"

  sed \
    -e "s|{{ROOT}}|${root_esc}|g" \
    -e "s|{{IMPACT_FILE}}|${impact_esc}|g" \
    -e "s|{{CAMPAIGN_METRICS_FILE}}|${campaign_esc}|g" \
    -e "s|{{CONFIG_FILE}}|${config_esc}|g" \
    -e "s|{{DELIVERY_MODE}}|${mode_esc}|g" \
    -e "s|{{SELECTED_PROVIDER}}|${provider_esc}|g" \
    -e "s|{{RECOMMENDATIONS_FILE}}|${rec_esc}|g" \
    -e "s|{{NEXT_CONFIG_FILE}}|${next_esc}|g" \
    -e "s|{{DRY_RUN}}|${dry_esc}|g" \
    "$template_file" > "$output_file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$2"
      shift 2
      ;;
    --agent)
      AGENT="$2"
      shift 2
      ;;
    --delivery-mode)
      DELIVERY_MODE="$2"
      shift 2
      ;;
    --impact-file)
      IMPACT_FILE="$2"
      shift 2
      ;;
    --campaign-metrics-file)
      CAMPAIGN_METRICS_FILE="$2"
      shift 2
      ;;
    --config-file)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf '[error] unknown argument: %s\n' "$1" >&2
      usage >&2
      exit "$EXIT_USAGE"
      ;;
  esac
done

case "$AGENT" in
  openclaw|claude-code|codex|all) ;;
  *)
    printf '[error] invalid --agent value: %s\n' "$AGENT" >&2
    exit "$EXIT_USAGE"
    ;;
esac

case "$DELIVERY_MODE" in
  auto|bundle|hosted_http|dual) ;;
  *)
    printf '[error] invalid --delivery-mode value: %s\n' "$DELIVERY_MODE" >&2
    exit "$EXIT_USAGE"
    ;;
esac

if [[ ! -d "$ROOT" ]]; then
  printf '[error] target root does not exist: %s\n' "$ROOT" >&2
  exit "$EXIT_USAGE"
fi

ROOT="$(cd "$ROOT" && pwd)"
IMPACT_FILE="${IMPACT_FILE:-$ROOT/.clix/analytics/impact-metrics.json}"
CAMPAIGN_METRICS_FILE="${CAMPAIGN_METRICS_FILE:-$ROOT/.clix/analytics/campaign-metrics.json}"
CONFIG_FILE="${CONFIG_FILE:-$ROOT/.clix/campaigns/openclix-config.json}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/.clix/automation}"

IMPACT_FILE="$(resolve_path "$ROOT" "$IMPACT_FILE")"
CAMPAIGN_METRICS_FILE="$(resolve_path "$ROOT" "$CAMPAIGN_METRICS_FILE")"
CONFIG_FILE="$(resolve_path "$ROOT" "$CONFIG_FILE")"
OUTPUT_DIR="$(resolve_path "$ROOT" "$OUTPUT_DIR")"

NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
PROMPTS_DIR="$OUTPUT_DIR/prompts"
EVALUATOR_DIR="$OUTPUT_DIR/evaluator"
RUN_SUMMARY_FILE="$OUTPUT_DIR/run-summary.json"

PROVIDER_JSON="$EVALUATOR_DIR/provider-detection.json"
MODE_JSON="$EVALUATOR_DIR/delivery-mode.json"

RECOMMENDATIONS_FILE="$EVALUATOR_DIR/update-recommendations.json"
NEXT_CONFIG_FILE="$EVALUATOR_DIR/openclix-config.next.json"
HISTORY_FILE="$EVALUATOR_DIR/update-history.json"
EVAL_CAMPAIGN_METRICS_FILE="$CAMPAIGN_METRICS_FILE"

SELECTED_PROVIDER=""
SELECTED_MODE=""
SELECTED_AGENTS_JSON='[]'
PROMPT_PATHS_JSON='{}'

require_command bash
require_command jq
require_command rg

DETECT_PA_SCRIPT="$ROOT/skills/openclix-analytics/scripts/detect_pa.sh"
DETECT_MODE_SCRIPT="$ROOT/skills/openclix-update-campaigns/scripts/detect_delivery_mode.sh"
EVALUATOR_SCRIPT="$ROOT/skills/openclix-update-campaigns/scripts/evaluate_campaigns.sh"
TEMPLATES_DIR="$ROOT/scripts/templates"

for script_path in "$DETECT_PA_SCRIPT" "$DETECT_MODE_SCRIPT" "$EVALUATOR_SCRIPT"; do
  if [[ ! -f "$script_path" ]]; then
    printf '[error] required script missing: %s\n' "$script_path" >&2
    exit "$EXIT_PREREQ"
  fi
done

mkdir -p "$OUTPUT_DIR" "$PROMPTS_DIR" "$EVALUATOR_DIR"

printf '[run] detecting product analytics provider...\n'
bash "$DETECT_PA_SCRIPT" "$ROOT" > "$PROVIDER_JSON"

INSTALLED_COUNT="$(jq '.installed_providers | length' "$PROVIDER_JSON")"
SELECTED_PROVIDER="$(jq -r '.selected_provider // ""' "$PROVIDER_JSON")"
OPENCLIX_DETECTED="$(jq -r '.openclix_detected // false' "$PROVIDER_JSON")"

if [[ "$OPENCLIX_DETECTED" != "true" ]]; then
  write_summary "blocked" "$EXIT_OPENCLIX_MISSING" "OpenClix integration not detected in target root."
  printf '[error] OpenClix integration not detected. Run openclix-init first.\n' >&2
  exit "$EXIT_OPENCLIX_MISSING"
fi

if [[ "$INSTALLED_COUNT" -eq 0 ]]; then
  write_summary "blocked" "$EXIT_NO_PROVIDER" "No supported analytics provider detected."
  printf '[error] no supported analytics provider detected (firebase, posthog, mixpanel, amplitude).\n' >&2
  printf '[hint] run openclix-analytics setup first, then retry.\n' >&2
  exit "$EXIT_NO_PROVIDER"
fi

if [[ "$DELIVERY_MODE" == "auto" ]]; then
  printf '[run] detecting config delivery mode...\n'
  bash "$DETECT_MODE_SCRIPT" --root "$ROOT" > "$MODE_JSON"
  SELECTED_MODE="$(jq -r '.delivery_mode // "unknown"' "$MODE_JSON")"
else
  SELECTED_MODE="$DELIVERY_MODE"
  jq -n \
    --arg root "$ROOT" \
    --arg mode "$SELECTED_MODE" \
    '{root: $root, delivery_mode: $mode, detection_source: "explicit", evidence: null}' > "$MODE_JSON"
fi

if [[ "$SELECTED_MODE" == "unknown" ]]; then
  write_summary "blocked" "$EXIT_MODE_UNKNOWN" "Delivery mode could not be detected."
  printf '[error] delivery mode is unknown. Set --delivery-mode bundle|hosted_http|dual.\n' >&2
  exit "$EXIT_MODE_UNKNOWN"
fi

if [[ ! -f "$IMPACT_FILE" ]]; then
  write_summary "blocked" "$EXIT_INPUT_MISSING" "Missing impact metrics input."
  printf '[error] missing required impact metrics: %s\n' "$IMPACT_FILE" >&2
  exit "$EXIT_INPUT_MISSING"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  write_summary "blocked" "$EXIT_INPUT_MISSING" "Missing OpenClix config input."
  printf '[error] missing required OpenClix config: %s\n' "$CONFIG_FILE" >&2
  exit "$EXIT_INPUT_MISSING"
fi

if [[ "$DRY_RUN" -eq 1 || ! -f "$CAMPAIGN_METRICS_FILE" ]]; then
  EVAL_CAMPAIGN_METRICS_FILE="$EVALUATOR_DIR/campaign-metrics.json"
  if [[ -f "$CAMPAIGN_METRICS_FILE" ]]; then
    cp "$CAMPAIGN_METRICS_FILE" "$EVAL_CAMPAIGN_METRICS_FILE"
  fi
fi

printf '[run] evaluating campaign operations...\n'
if ! bash "$EVALUATOR_SCRIPT" \
  --root "$ROOT" \
  --impact-metrics "$IMPACT_FILE" \
  --campaign-metrics "$EVAL_CAMPAIGN_METRICS_FILE" \
  --config "$CONFIG_FILE" \
  --recommendations "$RECOMMENDATIONS_FILE" \
  --next-config "$NEXT_CONFIG_FILE" \
  --history "$HISTORY_FILE" \
  --delivery-mode "$SELECTED_MODE"; then
  write_summary "failed" "$EXIT_EVALUATOR_FAILED" "Campaign evaluator failed."
  printf '[error] campaign evaluator failed. Check input contracts and retry.\n' >&2
  exit "$EXIT_EVALUATOR_FAILED"
fi

case "$AGENT" in
  all)
    SELECTED_AGENTS=("openclaw" "claude-code" "codex")
    ;;
  *)
    SELECTED_AGENTS=("$AGENT")
    ;;
esac

SELECTED_AGENTS_JSON="$(printf '%s\n' "${SELECTED_AGENTS[@]}" | jq -R . | jq -s .)"

for selected_agent in "${SELECTED_AGENTS[@]}"; do
  template_path="$TEMPLATES_DIR/retention-prompt.${selected_agent}.md.tmpl"
  output_path="$PROMPTS_DIR/${selected_agent}.md"

  if [[ ! -f "$template_path" ]]; then
    write_summary "failed" "$EXIT_PREREQ" "Prompt template missing for ${selected_agent}."
    printf '[error] missing prompt template: %s\n' "$template_path" >&2
    exit "$EXIT_PREREQ"
  fi

  render_template "$template_path" "$output_path"
  PROMPT_PATHS_JSON="$(jq --arg key "$selected_agent" --arg value "$output_path" '. + {($key): $value}' <<< "$PROMPT_PATHS_JSON")"
done

write_summary "ok" 0 "Retention ops automation artifacts generated."

printf '[done] run summary: %s\n' "$RUN_SUMMARY_FILE"
printf '[done] prompt directory: %s\n' "$PROMPTS_DIR"
