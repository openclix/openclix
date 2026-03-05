#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PWD}"
PLATFORM=""
PLAN_FILE=""

usage() {
cat <<'USAGE'
Usage:
  bash skills/openclix-update/scripts/plan_sync.sh \
    --root <target-project-root> \
    [--platform react-native|flutter|ios|android] \
    [--plan <plan-json-path>]

Generates a dry-run plan for OpenClix source sync.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --plan)
      PLAN_FILE="$2"
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

if [[ ! -d "$ROOT" ]]; then
  echo "Target directory does not exist: $ROOT" >&2
  exit 1
fi

ROOT="$(cd "$ROOT" && pwd)"
PLAN_FILE="${PLAN_FILE:-$ROOT/.openclix/openclix-update/openclix-update-plan.json}"
TEMPLATES_ROOT="$(cd "$SCRIPT_DIR/../openclix-init/templates" && pwd)"
NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

for cmd in jq rg; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command missing: $cmd" >&2
    exit 1
  fi
done

normalize_platform() {
  local p="$1"
  case "$p" in
    react-native|rn) echo "react-native" ;;
    flutter|ios|android) echo "$p" ;;
    *) echo "" ;;
  esac
}

extract_marker_positions() {
  local file="$1"
  local start end
  start="$(awk '/OPENCLIX_MANAGED_START/{print NR; exit}' "$file" || true)"
  end="$(awk '/OPENCLIX_MANAGED_END/{print NR; exit}' "$file" || true)"
  printf '%s %s\n' "${start:-0}" "${end:-0}"
}

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

DETECT_SCRIPT="$SCRIPT_DIR/detect_integration.sh"
if [[ ! -x "$DETECT_SCRIPT" ]]; then
  echo "detect_integration.sh is missing: $DETECT_SCRIPT" >&2
  exit 1
fi

if ! DETECT_JSON="$(bash "$DETECT_SCRIPT" --root "$ROOT")"; then
  echo "Failed to detect OpenClix integration for $ROOT" >&2
  exit 1
fi

DETECTED_PLATFORM="$(jq -r '.selected_platform // "unknown"' <<<"$DETECT_JSON")"
if [[ -n "${PLATFORM:-}" ]]; then
  NORMALIZED_PLATFORM="$(normalize_platform "$PLATFORM")"
  if [[ -z "$NORMALIZED_PLATFORM" ]]; then
    echo "Unknown platform: $PLATFORM" >&2
    exit 1
  fi
  PLATFORM="$NORMALIZED_PLATFORM"
elif [[ "$DETECTED_PLATFORM" == "ambiguous" ]]; then
  echo "Platform detection was ambiguous. Re-run with --platform react-native|flutter|ios|android." >&2
  exit 1
elif [[ -z "$DETECTED_PLATFORM" || "$DETECTED_PLATFORM" == "unknown" ]]; then
  echo "Could not infer platform. Re-run with --platform react-native|flutter|ios|android." >&2
  exit 1
else
  PLATFORM="$DETECTED_PLATFORM"
fi

TEMPLATE_DIR="${TEMPLATES_ROOT}/${PLATFORM}"
if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "OpenClix template directory missing: $TEMPLATE_DIR" >&2
  exit 1
fi

mapfile -t PLATFORM_ROOTS < <(jq -r --arg p "$PLATFORM" '.platform_roots[$p][]?' <<<"$DETECT_JSON" | awk 'NF')

if [[ ${#PLATFORM_ROOTS[@]} -eq 0 ]]; then
  case "$PLATFORM" in
    react-native)
      PLATFORM_ROOTS=("$ROOT/src/openclix")
      ;;
    flutter)
      PLATFORM_ROOTS=("$ROOT/lib/openclix")
      ;;
    ios)
      PLATFORM_ROOTS=("$ROOT/OpenClix" "$ROOT/Sources/OpenClix")
      while IFS= read -r p; do
        if [[ -n "$p" ]]; then
          PLATFORM_ROOTS+=("$p")
        fi
      done < <(
        find "$ROOT" -type d \( -path '*/Sources/OpenClix' -o -path '*/OpenClix' \) \
          ! -path '*/.git/*' \
          ! -path '*/node_modules/*' \
          ! -path '*/.next/*' \
          ! -path '*/dist/*' \
          ! -path '*/build/*' \
          2>/dev/null || true
      )
      ;;
    android)
      PLATFORM_ROOTS=("$ROOT/app/src/main/kotlin")
      while IFS= read -r p; do
        if [[ -n "$p" ]]; then
          PLATFORM_ROOTS+=("$p")
        fi
      done < <(find "$ROOT/app/src/main/kotlin" -type d -path '*/ai/openclix' 2>/dev/null || true)
      ;;
  esac
fi

PLATFORM_ROOT=""
if [[ ${#PLATFORM_ROOTS[@]} -gt 0 ]]; then
  PLATFORM_ROOT="${PLATFORM_ROOTS[0]}"
fi

if [[ -z "$PLATFORM_ROOT" ]]; then
  echo "Could not resolve platform root for $PLATFORM in $ROOT" >&2
  exit 1
fi

if [[ ! -d "$PLATFORM_ROOT" ]]; then
  if [[ "$PLATFORM" == "android" ]]; then
    mkdir -p "$PLATFORM_ROOT"
  else
    echo "Platform root does not exist: $PLATFORM_ROOT" >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "$PLAN_FILE")"
TMP_OPS="$(mktemp)"
trap 'rm -f "$TMP_OPS"' EXIT

mapfile -t TEMPLATE_FILES < <(find "$TEMPLATE_DIR" -type f | sort)

for template_file in "${TEMPLATE_FILES[@]}"; do
  REL_PATH="${template_file#"$TEMPLATE_DIR/"}"
  TARGET_FILE="$PLATFORM_ROOT/$REL_PATH"
  TEMPLATE_LINES="$(wc -l < "$template_file")"
  TEMPLATE_SHA="$(file_digest "$template_file")"
  TARGET_LINES=0
  TARGET_SHA=""
  STATUS="conflict"
  ACTION="replace_blocked"
  REASON="Template differs and no managed merge markers are available."
  CAN_APPLY="false"
  MARKER_PRESENT="false"
  MARKER_START=0
  MARKER_END=0
  DIFF_LINES=0

  if [[ ! -f "$TARGET_FILE" ]]; then
    STATUS="add"
    ACTION="add_file"
    REASON="Missing target file; it will be added from template."
    CAN_APPLY="true"
    DIFF_LINES="$TEMPLATE_LINES"
  else
    TARGET_LINES="$(wc -l < "$TARGET_FILE")"
    TARGET_SHA="$(file_digest "$TARGET_FILE")"
    if cmp -s "$template_file" "$TARGET_FILE"; then
      STATUS="no_change"
      ACTION="skip"
      REASON="Target already matches template."
      CAN_APPLY="true"
      DIFF_LINES=0
    else
      mapfile -t MARKERS < <(extract_marker_positions "$TARGET_FILE")
      if [[ ${#MARKERS[@]} -ge 2 ]]; then
        MARKER_START="${MARKERS[0]}"
        MARKER_END="${MARKERS[1]}"
        if [[ "$MARKER_START" -gt 0 && "$MARKER_END" -gt "$MARKER_START" ]]; then
          MARKER_PRESENT="true"
          STATUS="marker_merge"
          ACTION="marker_merge"
          CAN_APPLY="true"
          REASON="Template drift is isolated with managed markers; template body can be injected."
        fi
      fi
      if diff -u "$TARGET_FILE" "$template_file" >/dev/null 2>&1; then
        DIFF_LINES=0
      else
        DIFF_LINES="$(diff -u "$TARGET_FILE" "$template_file" 2>/dev/null | sed '1,2d' | wc -l || true)"
      fi
    fi
  fi

  jq -n \
    --arg root "$ROOT" \
    --arg platform "$PLATFORM" \
    --arg template_file "$template_file" \
    --arg target_file "$TARGET_FILE" \
    --arg rel_path "$REL_PATH" \
    --arg status "$STATUS" \
    --arg action "$ACTION" \
    --arg reason "$REASON" \
    --argjson template_lines "$TEMPLATE_LINES" \
    --argjson target_lines "$TARGET_LINES" \
    --argjson diff_lines "${DIFF_LINES:-0}" \
    --arg template_sha "${TEMPLATE_SHA:-}" \
    --arg target_sha "${TARGET_SHA:-}" \
    --argjson marker_present "$MARKER_PRESENT" \
    --argjson marker_start "$MARKER_START" \
    --argjson marker_end "$MARKER_END" \
    --argjson can_apply "$CAN_APPLY" \
    '{
      template_file: $template_file,
      target_file: $target_file,
      relative_path: $rel_path,
      platform: $platform,
      status: $status,
      action: $action,
      reason: $reason,
      can_apply: $can_apply,
      markers: {
        present: $marker_present,
        start_line: $marker_start,
        end_line: $marker_end
      },
      metadata: {
        template_lines: $template_lines,
        target_lines: $target_lines,
        diff_lines: $diff_lines,
        template_sha256: $template_sha,
        target_sha256: $target_sha
      }
    }' >> "$TMP_OPS"
  printf '\n' >> "$TMP_OPS"
done

OPS_JSON="$(jq -s '.' "$TMP_OPS")"
SUMMARY_NO_CHANGE="$(jq -r '[.[] | select(.status=="no_change")] | length' <<<"$OPS_JSON")"
SUMMARY_ADD="$(jq -r '[.[] | select(.status=="add")] | length' <<<"$OPS_JSON")"
SUMMARY_MERGE="$(jq -r '[.[] | select(.status=="marker_merge")] | length' <<<"$OPS_JSON")"
SUMMARY_CONFLICT="$(jq -r '[.[] | select(.status=="conflict")] | length' <<<"$OPS_JSON")"
SUMMARY_TOTAL="$(jq -r 'length' <<<"$OPS_JSON")"

CAN_APPLY=$([ "$SUMMARY_CONFLICT" -eq 0 ] && echo true || echo false)

PLAN_JSON="$(jq -n \
  --arg root "$ROOT" \
  --arg platform "$PLATFORM" \
  --arg generated_at "$NOW_UTC" \
  --arg template_dir "$TEMPLATE_DIR" \
  --arg target_root "$PLATFORM_ROOT" \
  --argjson operations "$OPS_JSON" \
  --argjson detection "$DETECT_JSON" \
  --argjson can_apply "$CAN_APPLY" \
  --argjson total "$SUMMARY_TOTAL" \
  --argjson no_change "$SUMMARY_NO_CHANGE" \
  --argjson add "$SUMMARY_ADD" \
  --argjson merge "$SUMMARY_MERGE" \
  --argjson conflict "$SUMMARY_CONFLICT" \
  --arg merge_strategy "marker_aware" \
  '{
    generated_at: $generated_at,
    root: $root,
    platform: $platform,
    template_dir: $template_dir,
    target_root: $target_root,
    strategy: $merge_strategy,
    can_apply: $can_apply,
    integration: $detection,
    summary: {
      total: $total,
      no_change: $no_change,
      add: $add,
      marker_merge: $merge,
      conflicts: $conflict
    },
    operations: $operations,
    conflicts: [ $operations[] | select(.status=="conflict") ]
  }'
)"

printf '%s\n' "$PLAN_JSON" > "$PLAN_FILE"
printf 'Wrote sync plan: %s\n' "$PLAN_FILE"
printf 'Summary: total=%s no_change=%s add=%s marker_merge=%s conflicts=%s\n' \
  "$SUMMARY_TOTAL" "$SUMMARY_NO_CHANGE" "$SUMMARY_ADD" "$SUMMARY_MERGE" "$SUMMARY_CONFLICT"
