#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PLUGIN_MANIFEST="${ROOT_DIR}/.claude-plugin/plugin.json"
MARKETPLACE_MANIFEST="${ROOT_DIR}/.claude-plugin/marketplace.json"
MIN_CLAUDE_CODE_VERSION="${MIN_CLAUDE_CODE_VERSION:-1.0.33}"
SKIP_CLAUDE_VALIDATE=0

usage() {
  cat <<'USAGE'
Usage:
  bash scripts/validate_claude_plugin.sh [options]

Options:
  --skip-claude-validate    Skip `claude plugin validate` execution.
  -h, --help                Show this help.
USAGE
}

fail() {
  printf '[error] %s\n' "$1" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "required command not found: $cmd"
  fi
}

version_ge() {
  local left_raw="${1%%[-+]*}"
  local right_raw="${2%%[-+]*}"
  local left_parts right_parts
  local i

  IFS='.' read -r -a left_parts <<< "$left_raw"
  IFS='.' read -r -a right_parts <<< "$right_raw"

  for i in 0 1 2; do
    local left="${left_parts[$i]:-0}"
    local right="${right_parts[$i]:-0}"

    if (( left > right )); then
      return 0
    fi
    if (( left < right )); then
      return 1
    fi
  done

  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-claude-validate)
      SKIP_CLAUDE_VALIDATE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

require_command jq

[[ -f "$PLUGIN_MANIFEST" ]] || fail "missing plugin manifest: $PLUGIN_MANIFEST"
[[ -f "$MARKETPLACE_MANIFEST" ]] || fail "missing marketplace manifest: $MARKETPLACE_MANIFEST"

jq -e '
  .name == "openclix" and
  (.version | type == "string") and
  (.description | type == "string" and length > 0) and
  (.author | type == "object") and
  (.author.name | type == "string" and length > 0) and
  (.repository == "https://github.com/openclix/openclix") and
  (.license | type == "string" and length > 0) and
  (.keywords | type == "array" and length > 0)
' "$PLUGIN_MANIFEST" >/dev/null || fail "plugin manifest failed required field checks"

jq -e '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+([-.][0-9A-Za-z.-]+)?$")' "$PLUGIN_MANIFEST" >/dev/null || fail "plugin version must be semver-like (x.y.z)"

PLUGIN_VERSION="$(jq -r '.version' "$PLUGIN_MANIFEST")"

jq -e '
  .name == "openclix" and
  (.owner | type == "object") and
  (.owner.name | type == "string" and length > 0) and
  (.metadata | type == "object") and
  (.metadata.version | type == "string" and length > 0) and
  (.plugins | type == "array" and length == 1)
' "$MARKETPLACE_MANIFEST" >/dev/null || fail "marketplace manifest failed top-level checks"

jq -e '
  .plugins[0].name == "openclix" and
  (.plugins[0].version | type == "string") and
  (.plugins[0].source | type == "string") and
  .plugins[0].source == "./"
' "$MARKETPLACE_MANIFEST" >/dev/null || fail "marketplace plugin source/name checks failed"

MARKETPLACE_VERSION="$(jq -r '.metadata.version' "$MARKETPLACE_MANIFEST")"
ENTRY_VERSION="$(jq -r '.plugins[0].version' "$MARKETPLACE_MANIFEST")"

[[ "$PLUGIN_VERSION" == "$MARKETPLACE_VERSION" ]] || fail "version mismatch: plugin.json($PLUGIN_VERSION) != marketplace metadata($MARKETPLACE_VERSION)"
[[ "$PLUGIN_VERSION" == "$ENTRY_VERSION" ]] || fail "version mismatch: plugin.json($PLUGIN_VERSION) != marketplace plugin entry($ENTRY_VERSION)"

if [[ "$SKIP_CLAUDE_VALIDATE" -eq 0 ]]; then
  require_command claude

  INSTALLED_CLAUDE_VERSION="$(claude --version | awk '{print $1}')"
  if ! version_ge "$INSTALLED_CLAUDE_VERSION" "$MIN_CLAUDE_CODE_VERSION"; then
    fail "claude version ${INSTALLED_CLAUDE_VERSION} is below required baseline ${MIN_CLAUDE_CODE_VERSION}"
  fi

  claude plugin validate "$PLUGIN_MANIFEST"
  claude plugin validate "$MARKETPLACE_MANIFEST"
else
  printf '[info] skipping claude plugin validate (flag enabled)\n'
fi

printf '[ok] claude plugin manifests validated\n'
