#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PWD}"

usage() {
cat <<'USAGE'
Usage:
  bash skills/openclix-update/scripts/detect_integration.sh [--root <project-root>]

Detects OpenClix integration traces and reports best-effort platform hints.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$2"
      shift 2
      ;;
    --help|-h)
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
NOW_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required for reliable detection" >&2
  exit 1
fi

append_unique() {
  local -n arr="$1"
  local value="$2"
  local existing

  for existing in "${arr[@]:-}"; do
    if [[ "$existing" == "$value" ]]; then
      return 0
    fi
  done
  arr+=("$value")
}

add_platform_candidate() {
  local platform="$1"
  local root="$2"

  case "$platform" in
    react-native)
      append_unique PLATFORM_ROOT_REACT "$root"
      ;;
    flutter)
      append_unique PLATFORM_ROOT_FLUTTER "$root"
      ;;
    ios)
      append_unique PLATFORM_ROOT_IOS "$root"
      ;;
    android)
      append_unique PLATFORM_ROOT_ANDROID "$root"
      ;;
    *)
      return 0
      ;;
  esac

  append_unique PLATFORM_CANDIDATES "$platform"
}

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//"/\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

print_array() {
  local -n arr="$1"
  local i
  printf '['
  for i in "${!arr[@]}"; do
    [[ $i -gt 0 ]] && printf ', '
    printf '"%s"' "$(json_escape "${arr[$i]}")"
  done
  printf ']'
}

PLATFORM_CANDIDATES=()
PLATFORM_ROOT_REACT=()
PLATFORM_ROOT_FLUTTER=()
PLATFORM_ROOT_IOS=()
PLATFORM_ROOT_ANDROID=()

NAMESPACE_PATHS=()
CONFIG_PATHS=()
EVIDENCE=()
ENTRYPOINTS=()

append_namespace_path() {
  local p="$1"
  if [[ -e "$p" ]]; then
    append_unique NAMESPACE_PATHS "$p"
  fi
}

append_config_path() {
  local p="$1"
  if [[ -f "$p" ]]; then
    append_unique CONFIG_PATHS "$p"
  fi
}

while IFS= read -r entry; do
  append_unique EVIDENCE "$entry"

  FILE_PATH="${entry%%:*}"
  if [[ "$FILE_PATH" == *"/src/openclix/"* ]]; then
    add_platform_candidate "react-native" "${FILE_PATH%%/src/openclix/*}/src/openclix"
  elif [[ "$FILE_PATH" == *"/lib/openclix/"* ]]; then
    add_platform_candidate "flutter" "${FILE_PATH%%/lib/openclix/*}/lib/openclix"
  elif [[ "$FILE_PATH" == *"/app/src/main/kotlin/"* && "$FILE_PATH" == *"/ai/openclix/"* ]]; then
    add_platform_candidate "android" "${FILE_PATH%%/app/src/main/kotlin/*}/app/src/main/kotlin"
  elif [[ "$FILE_PATH" == *"/Sources/OpenClix/"* ]]; then
    add_platform_candidate "ios" "${FILE_PATH%%/Sources/OpenClix/*}/Sources/OpenClix"
  elif [[ "$FILE_PATH" == *"/OpenClix/"* ]]; then
    add_platform_candidate "ios" "${FILE_PATH%%/OpenClix/*}/OpenClix"
  fi
done < <(
  rg -n -S "OpenClix\\.initialize\\(|OpenClixCampaignManager|openclix-config|openclix-config\\.json|src/openclix/|lib/openclix/" "$ROOT" \
    --glob '!**/.git/**' \
    --glob '!**/node_modules/**' \
    --glob '!**/.next/**' \
    --glob '!**/build/**' \
    --glob '!**/dist/**' \
    --glob '!**/.dart_tool/**' \
    --glob '!**/.openclix/**' \
    --glob '!**/skills/**' \
    --glob '!**/docs/**' \
    --max-count 120 || true
)

while IFS= read -r entry; do
  append_unique ENTRYPOINTS "$entry"
done < <(
  rg -n -S "OpenClix\\.initialize\\(|OpenClixCampaignManager|OpenClix\\.initialize\\(" "$ROOT" \
    --glob '!**/.git/**' \
    --glob '!**/node_modules/**' \
    --glob '!**/.next/**' \
    --glob '!**/build/**' \
    --glob '!**/dist/**' \
    --glob '!**/.dart_tool/**' \
    --glob '!**/.openclix/**' \
    --glob '!**/skills/**' \
    --glob '!**/docs/**' \
    --max-count 80 || true
)

append_namespace_path "$ROOT/.openclix"
append_config_path "$ROOT/.openclix/campaigns/openclix-config.json"
append_config_path "$ROOT/.openclix/campaigns/openclix-config.next.json"

if [[ -d "$ROOT/src/openclix" ]]; then
  add_platform_candidate "react-native" "$ROOT/src/openclix"
  append_namespace_path "$ROOT/src/openclix"
fi
if [[ -d "$ROOT/lib/openclix" ]]; then
  add_platform_candidate "flutter" "$ROOT/lib/openclix"
  append_namespace_path "$ROOT/lib/openclix"
fi
if [[ -d "$ROOT/app/src/main/kotlin/ai/openclix" ]]; then
  add_platform_candidate "android" "$ROOT/app/src/main/kotlin"
  append_namespace_path "$ROOT/app/src/main/kotlin/ai/openclix"
fi
if [[ -d "$ROOT/OpenClix" ]]; then
  add_platform_candidate "ios" "$ROOT/OpenClix"
  append_namespace_path "$ROOT/OpenClix"
fi
if [[ -d "$ROOT/Sources/OpenClix" ]]; then
  add_platform_candidate "ios" "$ROOT/Sources/OpenClix"
  append_namespace_path "$ROOT/Sources/OpenClix"
fi

while IFS= read -r p; do
  add_platform_candidate ios "$p"
done < <(
  find "$ROOT" -type d \( -path '*/Sources/OpenClix' -o -path '*/OpenClix' \) \
    ! -path '*/.git/*' ! -path '*/node_modules/*' ! -path '*/.next/*' ! -path '*/dist/*' ! -path '*/build/*' 2>/dev/null || true
  )

OPENCLIX_DETECTED=0
if [[ ${#NAMESPACE_PATHS[@]} -gt 0 ]] || [[ ${#PLATFORM_CANDIDATES[@]} -gt 0 ]] || [[ ${#ENTRYPOINTS[@]} -gt 0 ]] || [[ ${#CONFIG_PATHS[@]} -gt 0 ]]; then
  OPENCLIX_DETECTED=1
fi

if [[ $OPENCLIX_DETECTED -eq 0 ]]; then
  echo "No OpenClix integration signals found in: $ROOT" >&2
  exit 21
fi

if [[ ${#PLATFORM_CANDIDATES[@]} -eq 0 ]]; then
  PLATFORM=""
  PLATFORM_CONFIDENCE="low"
elif [[ ${#PLATFORM_CANDIDATES[@]} -eq 1 ]]; then
  PLATFORM="${PLATFORM_CANDIDATES[0]}"
  PLATFORM_CONFIDENCE="high"
else
  PLATFORM="ambiguous"
  PLATFORM_CONFIDENCE="low"
fi

print_object() {
  printf '{\n'
  printf '  "generated_at": "%s",\n' "$NOW_UTC"
  printf '  "root": "%s",\n' "$(json_escape "$ROOT")"
  printf '  "integrated": true,\n'
  printf '  "selected_platform": "%s",\n' "$(json_escape "$PLATFORM")"
  printf '  "platform_confidence": "%s",\n' "$(json_escape "$PLATFORM_CONFIDENCE")"
  printf '  "platform_candidates": '
  print_array PLATFORM_CANDIDATES
  printf ',\n'
  printf '  "platform_roots": {\n'
  printf '    "react-native": '
  print_array PLATFORM_ROOT_REACT
  printf ',\n'
  printf '    "flutter": '
  print_array PLATFORM_ROOT_FLUTTER
  printf ',\n'
  printf '    "ios": '
  print_array PLATFORM_ROOT_IOS
  printf ',\n'
  printf '    "android": '
  print_array PLATFORM_ROOT_ANDROID
  printf '\n'
  printf '  },\n'
  printf '  "openclix_namespace": {\n'
  if [[ ${#NAMESPACE_PATHS[@]} -gt 0 ]]; then
    printf '    "present": true,\n'
  else
    printf '    "present": false,\n'
  fi
  printf '    "paths": '
  print_array NAMESPACE_PATHS
  printf '\n  },\n'
  printf '  "openclix_config_paths": '
  print_array CONFIG_PATHS
  printf ',\n'
  printf '  "entrypoint_evidence": '
  print_array ENTRYPOINTS
  printf ',\n'
  printf '  "evidence": '
  print_array EVIDENCE
  printf '\n'
  printf '}\n'
}

print_object
