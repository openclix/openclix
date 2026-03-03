#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCHEMA_PATH="${ROOT_DIR}/skills/openclix-init/references/openclix.schema.json"

CONFIG_FILE="${1:-}"
FAILURE_COUNT=0
WARNING_COUNT=0

print_info() {
  printf '[validate] %s\n' "$1"
}

print_warn() {
  printf '[validate] WARN: %s\n' "$1"
  WARNING_COUNT=$((WARNING_COUNT + 1))
}

print_fail() {
  printf '[validate] FAIL: %s\n' "$1"
  FAILURE_COUNT=$((FAILURE_COUNT + 1))
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

if [[ -z "${CONFIG_FILE}" ]]; then
  echo "Usage: $0 <path-to-config.json>"
  exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  print_fail "File not found: ${CONFIG_FILE}"
  exit 1
fi

if [[ ! -f "${SCHEMA_PATH}" ]]; then
  print_fail "Schema not found: ${SCHEMA_PATH}"
  exit 1
fi

# --- 1. JSON syntax ---
print_info "Checking JSON syntax"
if ! jq . "${CONFIG_FILE}" >/dev/null 2>&1; then
  print_fail "Invalid JSON syntax in ${CONFIG_FILE}"
  jq . "${CONFIG_FILE}" 2>&1 || true
  exit 1
fi
print_info "JSON syntax OK"

# --- 2. Schema validation via ajv-cli ---
print_info "Checking schema validation via ajv-cli"
if has_command npx; then
  ajv_log="$(mktemp)"
  if npx --yes -p ajv-cli -p ajv-formats ajv validate --spec=draft2020 -c ajv-formats -s "${SCHEMA_PATH}" -d "${CONFIG_FILE}" >"${ajv_log}" 2>&1; then
    print_info "Schema validation passed"
  else
    print_fail "Schema validation failed"
    cat "${ajv_log}"
  fi
  rm -f "${ajv_log}"
else
  print_warn "npx not available, skipping ajv-cli schema validation"
fi

# --- 3. Structural spot-checks ---
print_info "Running structural spot-checks"

# 3a. $schema value
if ! jq -e '."$schema" == "https://openclix.ai/schemas/openclix.schema.json"' "${CONFIG_FILE}" >/dev/null 2>&1; then
  print_fail "\$schema must be exactly \"https://openclix.ai/schemas/openclix.schema.json\""
fi

# 3b. schema_version value
if ! jq -e '.schema_version == "openclix/config/v1"' "${CONFIG_FILE}" >/dev/null 2>&1; then
  print_fail "schema_version must be exactly \"openclix/config/v1\""
fi

# 3c. All campaign keys are kebab-case
non_kebab_keys="$(jq -r '.campaigns | keys[] | select(test("^[a-z0-9]+(-[a-z0-9]+)*$") | not)' "${CONFIG_FILE}" 2>/dev/null || true)"
if [[ -n "${non_kebab_keys}" ]]; then
  print_fail "Non-kebab-case campaign key(s) found: ${non_kebab_keys}"
fi

# 3d. Every campaign has type: "campaign"
bad_type_keys="$(jq -r '.campaigns | to_entries[] | select(.value.type != "campaign") | .key' "${CONFIG_FILE}" 2>/dev/null || true)"
if [[ -n "${bad_type_keys}" ]]; then
  print_fail "Campaign(s) missing type: \"campaign\": ${bad_type_keys}"
fi

# 3e. Each trigger.type has its matching sub-object key
mismatched_triggers="$(jq -r '
  .campaigns | to_entries[] |
  select(
    .value.trigger.type as $t |
    .value.trigger[$t] == null
  ) | .key
' "${CONFIG_FILE}" 2>/dev/null || true)"
if [[ -n "${mismatched_triggers}" ]]; then
  print_fail "Campaign(s) with trigger.type missing matching sub-object: ${mismatched_triggers}"
fi

# --- Summary ---
print_info "Completed with ${FAILURE_COUNT} failure(s), ${WARNING_COUNT} warning(s)"
if [[ "${FAILURE_COUNT}" -gt 0 ]]; then
  exit 1
fi
