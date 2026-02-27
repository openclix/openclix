#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
EXPLICIT_MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$2"
      shift 2
      ;;
    --mode)
      EXPLICIT_MODE="$2"
      shift 2
      ;;
    *)
      ROOT="$1"
      shift
      ;;
  esac
done

if [[ ! -d "$ROOT" ]]; then
  echo "Target directory does not exist: $ROOT" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd)"

if [[ -n "$EXPLICIT_MODE" ]]; then
  case "$EXPLICIT_MODE" in
    bundle|hosted_http|dual|unknown) ;;
    *)
      echo "Invalid --mode value: $EXPLICIT_MODE" >&2
      exit 1
      ;;
  esac
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required" >&2
  exit 1
fi

mapfile -t HTTP_ENDPOINT_EVIDENCE < <(
  rg -n -S "endpoint[^\n]*(https?://)|https?://[^\"'[:space:]]*openclix" "$ROOT" \
    --glob '!**/.git/**' \
    --glob '!**/node_modules/**' \
    --glob '!**/.next/**' \
    --glob '!**/build/**' \
    --glob '!**/dist/**' \
    --glob '!**/.dart_tool/**' \
    --glob '!**/skills/**' \
    --glob '!**/docs/**' \
    --glob '!**/README.md' || true
)

mapfile -t REPLACE_CONFIG_EVIDENCE < <(
  rg -n -S "ClixCampaignManager\.replaceConfig\(" "$ROOT" \
    --glob '!**/.git/**' \
    --glob '!**/node_modules/**' \
    --glob '!**/.next/**' \
    --glob '!**/build/**' \
    --glob '!**/dist/**' \
    --glob '!**/.dart_tool/**' \
    --glob '!**/skills/**' \
    --glob '!**/docs/**' \
    --glob '!**/README.md' || true
)

mapfile -t LOCAL_CONFIG_EVIDENCE < <(
  rg -n -S "openclix-config\.json|assets/.+openclix|res/raw|rootBundle\.loadString|Bundle\.main|FileManager.+openclix|endpoint[^\n]*(assets|res/raw|bundle|local)" "$ROOT" \
    --glob '!**/.git/**' \
    --glob '!**/node_modules/**' \
    --glob '!**/.next/**' \
    --glob '!**/build/**' \
    --glob '!**/dist/**' \
    --glob '!**/.dart_tool/**' \
    --glob '!**/skills/**' \
    --glob '!**/docs/**' \
    --glob '!**/README.md' || true
)

HAS_HTTP=0
[[ ${#HTTP_ENDPOINT_EVIDENCE[@]} -gt 0 ]] && HAS_HTTP=1

HAS_BUNDLE_SIGNAL=0
if [[ ${#REPLACE_CONFIG_EVIDENCE[@]} -gt 0 || ${#LOCAL_CONFIG_EVIDENCE[@]} -gt 0 ]]; then
  HAS_BUNDLE_SIGNAL=1
fi

DETECTION_SOURCE="auto"
if [[ -n "$EXPLICIT_MODE" ]]; then
  MODE="$EXPLICIT_MODE"
  DETECTION_SOURCE="explicit"
else
  if [[ $HAS_HTTP -eq 1 && $HAS_BUNDLE_SIGNAL -eq 1 ]]; then
    MODE="dual"
  elif [[ $HAS_HTTP -eq 1 ]]; then
    MODE="hosted_http"
  elif [[ $HAS_BUNDLE_SIGNAL -eq 1 ]]; then
    MODE="bundle"
  else
    MODE="unknown"
  fi
fi

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
  local -n arr=$1
  printf '['
  local i
  for i in "${!arr[@]}"; do
    [[ $i -gt 0 ]] && printf ', '
    printf '"%s"' "$(json_escape "${arr[$i]}")"
  done
  printf ']'
}

printf '{\n'
printf '  "root": "%s",\n' "$(json_escape "$ROOT")"
printf '  "delivery_mode": "%s",\n' "$(json_escape "$MODE")"
printf '  "detection_source": "%s",\n' "$(json_escape "$DETECTION_SOURCE")"
printf '  "evidence": {\n'
printf '    "http_endpoint": '
print_array HTTP_ENDPOINT_EVIDENCE
printf ',\n'
printf '    "replace_config": '
print_array REPLACE_CONFIG_EVIDENCE
printf ',\n'
printf '    "local_config": '
print_array LOCAL_CONFIG_EVIDENCE
printf '\n'
printf '  }\n'
printf '}\n'
