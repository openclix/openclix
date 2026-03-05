#!/usr/bin/env bash
set -euo pipefail

ROOT="${PWD}"
PLAN_FILE=""
OUTPUT_FILE=""
FORCE=0
DRY_RUN=1
ROOT_PROVIDED=0

usage() {
cat <<'USAGE'
Usage:
  bash skills/openclix-update/scripts/apply_sync.sh \
    --plan <openclix-update-plan.json> \
    [--root <target-project-root>] \
    [--output <apply-json-path>] \
    [--force] \
    [--apply]

Generates an apply report and executes updates when --apply is set.
Without --apply, it runs in dry-run mode.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$2"
      ROOT_PROVIDED=1
      shift 2
      ;;
    --plan)
      PLAN_FILE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --apply)
      DRY_RUN=0
      shift
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

if [[ ! -d "$ROOT" ]]; then
  echo "Target directory does not exist: $ROOT" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

if [[ -z "$PLAN_FILE" ]]; then
  PLAN_FILE="$ROOT/.openclix/openclix-update/openclix-update-plan.json"
fi
if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Plan file missing: $PLAN_FILE" >&2
  exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="$(dirname "$PLAN_FILE")/openclix-update-apply.json"
fi

for cmd in jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command missing: $cmd" >&2
    exit 1
  fi
done

if [[ "$ROOT_PROVIDED" -eq 0 ]]; then
  ROOT="$(jq -r '.root // empty' "$PLAN_FILE")"
fi
if [[ -z "$ROOT" ]]; then
  echo "Unable to determine target root from plan." >&2
  exit 1
fi
if [[ ! -d "$ROOT" ]]; then
  echo "Target root from plan is invalid: $ROOT" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

PLAN_DIR="$(dirname "$PLAN_FILE")"
mkdir -p "$PLAN_DIR"
NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
BACKUP_ROOT="$PLAN_DIR/backups/$TIMESTAMP"

if [[ "$DRY_RUN" -eq 0 && "$FORCE" -eq 0 && "$(jq -r '.can_apply // false' "$PLAN_FILE")" == "false" ]]; then
  PLAN_BLOCKED=1
else
  PLAN_BLOCKED=0
fi

file_digest() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    echo ""
  fi
}

ensure_backup_dir() {
  local target="$1"
  local rel
  if [[ "$target" == "$ROOT/"* ]]; then
    rel="${target#$ROOT/}"
  else
    rel="$(basename "$target")"
  fi
  mkdir -p "$BACKUP_ROOT/$(dirname "$rel")"
}

backup_file() {
  local target="$1"
  local rel
  local backup_path="$BACKUP_ROOT"

  if [[ "$target" == "$ROOT/"* ]]; then
    rel="${target#$ROOT/}"
  else
    rel="$(basename "$target")"
  fi

  mkdir -p "$backup_path/$(dirname "$rel")"
  cp -p "$target" "$backup_path/$rel"
  echo "$backup_path/$rel"
}

apply_marker_merge() {
  local template="$1"
  local target="$2"
  local tmp_file
  local start_line
  local end_line

  start_line="$(awk '/OPENCLIX_MANAGED_START/{print NR; exit}' "$target" || true)"
  end_line="$(awk '/OPENCLIX_MANAGED_END/{print NR; exit}' "$target" || true)"

  if [[ -z "$start_line" || -z "$end_line" ]]; then
    return 1
  fi
  if (( start_line <= 0 || end_line <= start_line )); then
    return 1
  fi

  tmp_file="$(mktemp)"
  {
    sed -n "1,$((start_line-1))p" "$target"
    cat "$template"
    sed -n "${end_line},\$p" "$target"
  } > "$tmp_file"
  mv "$tmp_file" "$target"
}

ensure_valid_target_file() {
  local target="$1"
  if [[ ! -f "$target" ]]; then
    return 1
  fi
  if [[ ! -s "$target" ]]; then
    return 1
  fi
  if [[ "$target" == *.json ]] && ! jq -e . "$target" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

append_ndjson() {
  local file="$1"
  local obj="$2"
  printf '%s\n' "$obj" >> "$file"
}

TMP_APPLIED="$(mktemp)"
TMP_BLOCKED="$(mktemp)"
TMP_SKIPPED="$(mktemp)"
TMP_FAILED="$(mktemp)"
trap 'rm -f "$TMP_APPLIED" "$TMP_BLOCKED" "$TMP_SKIPPED" "$TMP_FAILED"' EXIT

OP_INDEX=0
APPLIED_COUNT=0
BLOCKED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

if [[ "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$BACKUP_ROOT"
fi

while IFS= read -r op; do
  OP_INDEX=$((OP_INDEX + 1))
  STATUS="$(jq -r '.status // empty' <<<"$op")"
  TEMPLATE_FILE="$(jq -r '.template_file // empty' <<<"$op")"
  TARGET_FILE="$(jq -r '.target_file // empty' <<<"$op")"
  REL_PATH="$(jq -r '.relative_path // empty' <<<"$op")"
  REASON="$(jq -r '.reason // empty' <<<"$op")"

  if [[ "$STATUS" == "no_change" ]]; then
    append_ndjson "$TMP_SKIPPED" "$(jq -n \
      --arg target "$TARGET_FILE" \
      --arg rel "$REL_PATH" \
      --arg reason "$REASON" \
      '{status:"skipped",target_file:$target,relative_path:$rel,mode:"noop",reason:$reason,backup_file:null}')"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  if [[ "$STATUS" != "add" && "$STATUS" != "marker_merge" && "$STATUS" != "conflict" ]]; then
    append_ndjson "$TMP_FAILED" "$(jq -n \
      --arg target "$TARGET_FILE" \
      --arg rel "$REL_PATH" \
      --arg status "$STATUS" \
      --arg reason "Unknown plan action: $STATUS" \
      '{status:"failed",target_file:$target,relative_path:$rel,reason:$reason,backup_file:null}')"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  if [[ "$STATUS" == "conflict" && "$FORCE" -eq 0 ]]; then
    append_ndjson "$TMP_BLOCKED" "$(jq -n \
      --arg target "$TARGET_FILE" \
      --arg rel "$REL_PATH" \
      --arg reason "$REASON" \
      '{status:"blocked",target_file:$target,relative_path:$rel,reason:$reason,backup_file:null}')"
    BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
    continue
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    append_ndjson "$TMP_APPLIED" "$(jq -n \
      --arg target "$TARGET_FILE" \
      --arg template "$TEMPLATE_FILE" \
      --arg rel "$REL_PATH" \
      --arg mode "$STATUS" \
      --arg reason "$REASON" \
      '{status:"planned",target_file:$target,template_file:$template,relative_path:$rel,mode:$mode,reason:$reason,backup_file:null}')"
    APPLIED_COUNT=$((APPLIED_COUNT + 1))
    continue
  fi

  mkdir -p "$(dirname "$TARGET_FILE")"
  BACKUP_PATH="null"
  if [[ -f "$TARGET_FILE" ]]; then
    BACKUP_PATH="$(backup_file "$TARGET_FILE")"
  fi

  if [[ "$STATUS" == "marker_merge" ]]; then
    if ! apply_marker_merge "$TEMPLATE_FILE" "$TARGET_FILE"; then
      append_ndjson "$TMP_FAILED" "$(jq -n \
        --arg target "$TARGET_FILE" \
        --arg rel "$REL_PATH" \
        --arg backup "$BACKUP_PATH" \
        '{status:"failed",target_file:$target,relative_path:$rel,reason:"Marker merge failed; verify OPENCLIX_MANAGED_START/END markers.",backup_file:$backup}')"
      FAILED_COUNT=$((FAILED_COUNT + 1))
      continue
    fi
  else
    cp -p "$TEMPLATE_FILE" "$TARGET_FILE"
  fi

  if ! ensure_valid_target_file "$TARGET_FILE"; then
    append_ndjson "$TMP_FAILED" "$(jq -n \
      --arg target "$TARGET_FILE" \
      --arg rel "$REL_PATH" \
      --arg backup "$BACKUP_PATH" \
      '{status:"failed",target_file:$target,relative_path:$rel,reason:"Post-apply validation failed",backup_file:$backup}')"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  POST_SHA="$(file_digest "$TARGET_FILE")"
  MODE="added"
  if [[ "$STATUS" == "marker_merge" ]]; then
    MODE="merged"
  elif [[ "$STATUS" == "conflict" ]]; then
    MODE="replaced"
  fi

  append_ndjson "$TMP_APPLIED" "$(jq -n \
    --arg target "$TARGET_FILE" \
    --arg template "$TEMPLATE_FILE" \
    --arg rel "$REL_PATH" \
    --arg mode "$MODE" \
    --arg backup "$BACKUP_PATH" \
    --arg post_sha "$POST_SHA" \
    '{status:"applied",target_file:$target,template_file:$template,relative_path:$rel,mode:$mode,reason:null,backup_file:$backup,sha256:$post_sha}')"
  APPLIED_COUNT=$((APPLIED_COUNT + 1))
done < <(jq -c '.operations[]' "$PLAN_FILE")

APPLIED_JSON="$(jq -s '.' "$TMP_APPLIED")"
BLOCKED_JSON="$(jq -s '.' "$TMP_BLOCKED")"
SKIPPED_JSON="$(jq -s '.' "$TMP_SKIPPED")"
FAILED_JSON="$(jq -s '.' "$TMP_FAILED")"

PLAN_SUMMARY_TOTAL="$(jq -r '.summary.total // 0' "$PLAN_FILE")"
PLAN_SUMMARY_NO_CHANGE="$(jq -r '.summary.no_change // 0' "$PLAN_FILE")"
PLAN_CAN_APPLY="$(jq -r '.can_apply // false' "$PLAN_FILE")"
PLAN_TOTAL="$(jq -r '.summary.total // 0' "$PLAN_FILE")"

if [[ "$DRY_RUN" -eq 1 ]]; then
  EXEC_MODE="dry_run"
else
  if [[ "$FORCE" -eq 1 ]]; then
    EXEC_MODE="force"
  else
    EXEC_MODE="normal"
  fi
fi

APPLY_JSON="$(jq -n \
  --arg generated_at "$NOW_UTC" \
  --arg root "$ROOT" \
  --arg plan "$PLAN_FILE" \
  --arg mode "$EXEC_MODE" \
  --arg backup_root "$BACKUP_ROOT" \
  --argjson plan_total "$PLAN_TOTAL" \
  --argjson no_change "$PLAN_SUMMARY_NO_CHANGE" \
  --argjson can_apply "$PLAN_CAN_APPLY" \
  --argjson can_plan_apply "$PLAN_BLOCKED" \
  --argjson applied "$APPLIED_COUNT" \
  --argjson blocked "$BLOCKED_COUNT" \
  --argjson skipped "$SKIPPED_COUNT" \
  --argjson failed "$FAILED_COUNT" \
  --argjson applied_rows "$APPLIED_JSON" \
  --argjson blocked_rows "$BLOCKED_JSON" \
  --argjson skipped_rows "$SKIPPED_JSON" \
  --argjson failed_rows "$FAILED_JSON" \
  '{
    generated_at: $generated_at,
    root: $root,
    plan_file: $plan,
    mode: $mode,
    can_apply: $can_apply,
    plan_blocked: ($can_plan_apply == 1),
    dry_run: ($mode == "dry_run"),
    backup_root: (if $mode == "dry_run" then null else $backup_root end),
    plan_summary: {
      total: $plan_total,
      no_change: $no_change
    },
    summary: {
      applied: $applied,
      blocked: $blocked,
      skipped: $skipped,
      failed: $failed
    },
    applied: $applied_rows,
    blocked: $blocked_rows,
    skipped: $skipped_rows,
    failed: $failed_rows
  }')"

printf '%s\n' "$APPLY_JSON" > "$OUTPUT_FILE"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'Dry-run complete. No files were modified.\n'
  printf 'Report: %s\n' "$OUTPUT_FILE"
  printf 'Summary: applied=%s blocked=%s skipped=%s failed=%s\n' "$APPLIED_COUNT" "$BLOCKED_COUNT" "$SKIPPED_COUNT" "$FAILED_COUNT"
  exit 0
fi

if [[ "$FAILED_COUNT" -gt 0 ]]; then
  echo "apply_sync completed with failures. Review $OUTPUT_FILE for details." >&2
  exit 1
fi

if [[ "$BLOCKED_COUNT" -gt 0 && "$FORCE" -eq 0 ]]; then
  echo "apply_sync blocked by conflicts. Re-run with --apply --force for explicit overwrite." >&2
  exit 2
fi

printf 'Applied: %s\n' "$OUTPUT_FILE"
printf 'Backups: %s\n' "$BACKUP_ROOT"
printf 'Summary: applied=%s skipped=%s failed=%s\n' "$APPLIED_COUNT" "$SKIPPED_COUNT" "$FAILED_COUNT"
