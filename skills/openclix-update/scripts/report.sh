#!/usr/bin/env bash
set -euo pipefail

ROOT="${PWD}"
PLAN_FILE=""
APPLY_FILE=""
OUTPUT_MD=""
OUTPUT_JSON=""

usage() {
cat <<'USAGE'
Usage:
  bash skills/openclix-update/scripts/report.sh \
    --plan <openclix-update-plan.json> \
    [--apply <openclix-update-apply.json>] \
    [--output <openclix-update-report.md>] \
    [--json <openclix-update-report.json>]

Generate JSON + markdown report from update plan/apply artifacts.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$2"
      shift 2
      ;;
    --plan)
      PLAN_FILE="$2"
      shift 2
      ;;
    --apply)
      APPLY_FILE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_MD="$2"
      shift 2
      ;;
    --json)
      OUTPUT_JSON="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PLAN_FILE" ]]; then
  PLAN_FILE="$ROOT/.openclix/openclix-update/openclix-update-plan.json"
fi
if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Plan file missing: $PLAN_FILE" >&2
  exit 1
fi

if [[ ! -d "$ROOT" ]]; then
  echo "Target directory does not exist: $ROOT" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

for cmd in jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command missing: $cmd" >&2
    exit 1
  fi
done

PLAN_DIR="$(cd "$(dirname "$PLAN_FILE")" && pwd)"
OUTPUT_MD="${OUTPUT_MD:-$PLAN_DIR/openclix-update-report.md}"
OUTPUT_JSON="${OUTPUT_JSON:-$PLAN_DIR/openclix-update-report.json}"

if [[ -z "$APPLY_FILE" ]]; then
  APPLY_FILE="$PLAN_DIR/openclix-update-apply.json"
fi
if [[ ! -f "$APPLY_FILE" ]]; then
  APPLY_FILE=""
fi

PLAN_ROOT="$(jq -r '.root // empty' "$PLAN_FILE")"
PLAN_PLATFORM="$(jq -r '.platform // empty' "$PLAN_FILE")"
PLAN_STATUS_CAN_APPLY="$(jq -r '.can_apply // false' "$PLAN_FILE")"
PLAN_TOTAL="$(jq -r '.summary.total // 0' "$PLAN_FILE")"
PLAN_NO_CHANGE="$(jq -r '.summary.no_change // 0' "$PLAN_FILE")"
PLAN_ADD="$(jq -r '[.operations[] | select(.status=="add")] | length' "$PLAN_FILE")"
PLAN_MERGE="$(jq -r '[.operations[] | select(.status=="marker_merge")] | length' "$PLAN_FILE")"
PLAN_CONFLICTS="$(jq -r '[.operations[] | select(.status=="conflict")] | length' "$PLAN_FILE")"
PLAN_CREATED="$(jq -r '.generated_at // ""' "$PLAN_FILE")"

if [[ -n "$APPLY_FILE" ]]; then
  APPLY_MODE="$(jq -r '.mode // "not_applied"' "$APPLY_FILE")"
  APPLY_TOTAL="$(jq -r '.plan_summary.total // 0' "$APPLY_FILE")"
  APPLY_APPLIED="$(jq -r '.summary.applied // 0' "$APPLY_FILE")"
  APPLY_BLOCKED="$(jq -r '.summary.blocked // 0' "$APPLY_FILE")"
  APPLY_SKIPPED="$(jq -r '.summary.skipped // 0' "$APPLY_FILE")"
  APPLY_FAILED="$(jq -r '.summary.failed // 0' "$APPLY_FILE")"
  APPLY_BACKUP="$(jq -r '.backup_root // ""' "$APPLY_FILE")"
  APPLY_DRY="$(jq -r '.dry_run // false' "$APPLY_FILE")"
else
  APPLY_MODE="not_run"
  APPLY_TOTAL=0
  APPLY_APPLIED=0
  APPLY_BLOCKED=0
  APPLY_SKIPPED=0
  APPLY_FAILED=0
  APPLY_BACKUP=""
  APPLY_DRY="false"
fi

if [[ -z "$PLAN_ROOT" ]]; then
  PLAN_ROOT="$ROOT"
fi

TMP_CONFLICTS="$(mktemp)"
TMP_ACTIONS="$(mktemp)"
TMP_BLOCKED="$(mktemp)"
trap 'rm -f "$TMP_CONFLICTS" "$TMP_ACTIONS" "$TMP_BLOCKED"' EXIT

jq -r '.operations[] | select(.status=="conflict") | "- `\(.target_file)`: \(.reason)"' "$PLAN_FILE" > "$TMP_CONFLICTS" || true
jq -r '.operations[] | select(.status=="add" or .status=="marker_merge" or .status=="conflict") | "- `\(.status)`: `\(.relative_path)`"' "$PLAN_FILE" > "$TMP_ACTIONS" || true

{
  echo "# OpenClix Update Report"
  echo ""
  echo "Generated: $PLAN_CREATED"
  echo "Root: $PLAN_ROOT"
  echo "Platform: $PLAN_PLATFORM"
  echo ""
  echo "Plan can be applied automatically: $PLAN_STATUS_CAN_APPLY"
  echo ""
  echo "## Plan summary"
  echo ""
  echo "| Type | Count |"
  echo "| --- | --- |"
  echo "| Total files evaluated | $PLAN_TOTAL |"
  echo "| No-change files | $PLAN_NO_CHANGE |"
  echo "| Files to add | $PLAN_ADD |"
  echo "| Marker-merge updates | $PLAN_MERGE |"
  echo "| Conflicts | $PLAN_CONFLICTS |"
  echo ""
  echo "## Files requiring action"
  echo ""
  if [[ -s "$TMP_ACTIONS" ]]; then
    cat "$TMP_ACTIONS"
  else
    echo "- No file changes planned."
  fi
  echo ""
  echo "## Conflicts"
  echo ""
  if [[ -s "$TMP_CONFLICTS" ]]; then
    cat "$TMP_CONFLICTS"
  else
    echo "- No conflicts."
  fi
  echo ""
  if [[ -n "$APPLY_FILE" ]]; then
    echo "## Apply summary"
    echo ""
    echo "- Apply mode: $APPLY_MODE"
    echo "- Total outcome rows: $APPLY_TOTAL"
    echo "- Applied: $APPLY_APPLIED"
    echo "- Blocked: $APPLY_BLOCKED"
    echo "- Skipped: $APPLY_SKIPPED"
    echo "- Failed: $APPLY_FAILED"
    if [[ -n "$APPLY_BACKUP" ]]; then
      echo "- Backup root: $APPLY_BACKUP"
      echo ""
      echo "### Rollback points"
      echo ""
      echo "- Revert by copying original files from \`$APPLY_BACKUP\` into the target paths."
    fi
  else
    echo "## Apply summary"
    echo ""
    echo "- Apply not run yet."
  fi
  echo ""
  echo "## Next steps"
  echo ""
  echo "1. Run dry-run first: \`apply_sync.sh --plan $PLAN_FILE --root $PLAN_ROOT\`."
  echo "2. Review conflict files in this report."
  echo "3. When approved, run: \`apply_sync.sh --plan $PLAN_FILE --root $PLAN_ROOT --apply\`."
  echo "4. Use \`--force\` only for remaining conflict files after manual review."
  if [[ -n "$APPLY_BACKUP" ]]; then
    echo "5. Rollback point is available at \`$APPLY_BACKUP\`."
  fi
} > "$OUTPUT_MD"

if [[ -n "$APPLY_FILE" ]]; then
  jq -n \
    --arg generated_at "$PLAN_CREATED" \
    --arg plan_file "$PLAN_FILE" \
    --arg apply_file "$APPLY_FILE" \
    --arg root "$PLAN_ROOT" \
    --arg platform "$PLAN_PLATFORM" \
    --arg mode "$APPLY_MODE" \
    --arg dry_run "$APPLY_DRY" \
    --arg backup "$APPLY_BACKUP" \
    --argjson conflicts "$PLAN_CONFLICTS" \
    --argjson can_apply "$PLAN_STATUS_CAN_APPLY" \
    --argjson plan_total "$PLAN_TOTAL" \
    --argjson plan_no_change "$PLAN_NO_CHANGE" \
    --argjson plan_add "$PLAN_ADD" \
    --argjson plan_merge "$PLAN_MERGE" \
    --argjson apply_total "$APPLY_TOTAL" \
    --argjson apply_applied "$APPLY_APPLIED" \
    --argjson apply_blocked "$APPLY_BLOCKED" \
    --argjson apply_skipped "$APPLY_SKIPPED" \
    --argjson apply_failed "$APPLY_FAILED" \
    --arg report_file "$OUTPUT_MD" \
    '{ 
      generated_at: $generated_at,
      plan_file: $plan_file,
      apply_file: $apply_file,
      output_md: $report_file,
      plan: {
        root: $root,
        platform: $platform,
        can_apply: $can_apply,
        summary: {
          total: $plan_total,
          no_change: $plan_no_change,
          add: $plan_add,
          marker_merge: $plan_merge,
          conflicts: $conflicts
        }
      },
      apply: {
        mode: $mode,
        dry_run: ($dry_run == "true"),
        backup_root: $backup,
        summary: {
          total: $apply_total,
          applied: $apply_applied,
          blocked: $apply_blocked,
          skipped: $apply_skipped,
          failed: $apply_failed
        }
      },
      next_steps: [
        "Run dry-run first: apply_sync.sh --plan " + $plan_file + " --root " + $root,
        "Review conflict files in this report.",
        "Apply with confirmation: apply_sync.sh --plan " + $plan_file + " --root " + $root + " --apply",
        "Use --force only after manual review of each conflict."
      ],
      rollback_points: [ if ($backup | length > 0) then [$backup] else [] end ]
    }' > "$OUTPUT_JSON"
else
  jq -n \
    --arg generated_at "$PLAN_CREATED" \
    --arg plan_file "$PLAN_FILE" \
    --arg root "$PLAN_ROOT" \
    --arg platform "$PLAN_PLATFORM" \
    --argjson conflicts "$PLAN_CONFLICTS" \
    --argjson can_apply "$PLAN_STATUS_CAN_APPLY" \
    --argjson plan_total "$PLAN_TOTAL" \
    --argjson plan_no_change "$PLAN_NO_CHANGE" \
    --argjson plan_add "$PLAN_ADD" \
    --argjson plan_merge "$PLAN_MERGE" \
    --arg report_file "$OUTPUT_MD" \
    '{
      generated_at: $generated_at,
      plan_file: $plan_file,
      apply_file: null,
      output_md: $report_file,
      plan: {
        root: $root,
        platform: $platform,
        can_apply: $can_apply,
        summary: {
          total: $plan_total,
          no_change: $plan_no_change,
          add: $plan_add,
          marker_merge: $plan_merge,
          conflicts: $conflicts
        }
      },
      apply: null,
      next_steps: [
        "Run dry-run first: apply_sync.sh --plan " + $plan_file + " --root " + $root,
        "Apply with confirmation: apply_sync.sh --plan " + $plan_file + " --root " + $root + " --apply",
        "Use --force only for conflict files."
      ]
    }' > "$OUTPUT_JSON"
fi

echo "Wrote:"
echo "- $OUTPUT_MD"
echo "- $OUTPUT_JSON"
