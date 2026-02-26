#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATES_DIR="${ROOT_DIR}/templates"

TARGET_PLATFORM="${1:-all}"
FAILURE_COUNT=0
WARNING_COUNT=0

print_info() {
  printf '[verify] %s\n' "$1"
}

print_warn() {
  printf '[warn] %s\n' "$1"
  WARNING_COUNT=$((WARNING_COUNT + 1))
}

print_fail() {
  printf '[fail] %s\n' "$1"
  FAILURE_COUNT=$((FAILURE_COUNT + 1))
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

run_common_checks() {
  local platform_name="$1"
  local platform_dir="$2"
  local token

  print_info "${platform_name}: running common checks"

  if rg -n 'event_ingested|ingest' "${platform_dir}" >/dev/null; then
    print_fail "${platform_name}: forbidden ingest keyword found"
    rg -n 'event_ingested|ingest' "${platform_dir}" || true
  fi

  if ! rg -n 'event_tracked' "${platform_dir}" >/dev/null; then
    print_fail "${platform_name}: event_tracked is missing"
  fi

  for token in campaign_states queued_messages trigger_history updated_at; do
    if ! rg -n "${token}" "${platform_dir}" >/dev/null; then
      print_fail "${platform_name}: flat campaign-state key '${token}' is missing"
    fi
  done

  for token in scheduled recurring cancel_event do_not_disturb frequency_cap; do
    if ! rg -n "${token}" "${platform_dir}" >/dev/null; then
      print_fail "${platform_name}: trigger/settings token '${token}' is missing"
    fi
  done

}

find_android_jar() {
  local search_root
  for search_root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "${HOME}/Library/Android/sdk"; do
    if [[ -n "${search_root}" && -d "${search_root}/platforms" ]]; then
      find "${search_root}/platforms" -name android.jar 2>/dev/null | sort -V | tail -n 1
      return 0
    fi
  done
  return 1
}

find_coroutines_jar() {
  local gradle_cache="${HOME}/.gradle/caches/modules-2/files-2.1/org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm"
  if [[ -d "${gradle_cache}" ]]; then
    find "${gradle_cache}" -name '*.jar' 2>/dev/null | sort -V | tail -n 1
    return 0
  fi
  return 1
}

verify_android_template() {
  local template_dir="${TEMPLATES_DIR}/android"
  local android_jar=''
  local coroutines_jar=''
  local output_dir=''
  local compile_log=''
  local -a kotlin_sources=()

  run_common_checks 'android' "${template_dir}"

  if ! has_command kotlinc; then
    print_warn 'android: kotlinc not found, skipped Kotlin compile check'
    return 0
  fi

  if ! android_jar="$(find_android_jar)"; then
    print_warn 'android: android.jar not found (ANDROID_HOME/ANDROID_SDK_ROOT), skipped Kotlin compile check'
    return 0
  fi

  if ! coroutines_jar="$(find_coroutines_jar)"; then
    print_warn 'android: kotlinx-coroutines-core-jvm jar not found in Gradle cache, skipped Kotlin compile check'
    return 0
  fi

  mapfile -t kotlin_sources < <(find "${template_dir}" -name '*.kt' | sort)
  if [[ ${#kotlin_sources[@]} -eq 0 ]]; then
    print_fail 'android: no Kotlin source files found'
    return 0
  fi

  output_dir="$(mktemp -d)"
  compile_log="$(mktemp)"
  if kotlinc "${kotlin_sources[@]}" -classpath "${android_jar}:${coroutines_jar}" -d "${output_dir}/openclix-android-template.jar" >"${compile_log}" 2>&1; then
    print_info 'android: Kotlin compile check passed'
  else
    print_fail 'android: Kotlin compile check failed'
    cat "${compile_log}"
  fi

  rm -rf "${output_dir}"
  rm -f "${compile_log}"
}

verify_ios_template() {
  local template_dir="${TEMPLATES_DIR}/ios"
  local compile_log=''
  local -a swift_sources=()

  run_common_checks 'ios' "${template_dir}"

  if ! has_command xcrun; then
    print_warn 'ios: xcrun not found, skipped Swift typecheck'
    return 0
  fi

  mapfile -t swift_sources < <(find "${template_dir}" -name '*.swift' | sort)
  if [[ ${#swift_sources[@]} -eq 0 ]]; then
    print_fail 'ios: no Swift source files found'
    return 0
  fi

  compile_log="$(mktemp)"
  if xcrun swiftc -typecheck -module-name OpenClixTemplate "${swift_sources[@]}" >"${compile_log}" 2>&1; then
    print_info 'ios: Swift typecheck passed'
  else
    print_fail 'ios: Swift typecheck failed'
    cat "${compile_log}"
  fi

  rm -f "${compile_log}"
}

verify_flutter_template() {
  local template_dir="${TEMPLATES_DIR}/flutter"
  local workspace_dir=''
  local pubspec_path=''
  local main_path=''
  local pubget_log=''
  local analyze_log=''

  run_common_checks 'flutter' "${template_dir}"

  if ! has_command flutter; then
    print_warn 'flutter: flutter command not found, skipped flutter analyze'
    return 0
  fi

  workspace_dir="$(mktemp -d)"
  pubspec_path="${workspace_dir}/pubspec.yaml"
  main_path="${workspace_dir}/lib/main.dart"
  pubget_log="$(mktemp)"
  analyze_log="$(mktemp)"

  mkdir -p "${workspace_dir}/lib/openclix"
  cp -R "${template_dir}/." "${workspace_dir}/lib/openclix/"

  cat >"${pubspec_path}" <<'EOF'
name: openclix_template_verify
description: Verification package for OpenClix Flutter template.
publish_to: none
version: 0.0.1

environment:
  sdk: ">=3.4.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_local_notifications: ^19.0.0
EOF

  cat >"${main_path}" <<'EOF'
void main() {}
EOF

  if (cd "${workspace_dir}" && flutter pub get >"${pubget_log}" 2>&1); then
    print_info 'flutter: flutter pub get passed'
  else
    print_fail 'flutter: flutter pub get failed'
    cat "${pubget_log}"
    rm -rf "${workspace_dir}"
    rm -f "${pubget_log}" "${analyze_log}"
    return 0
  fi

  if (cd "${workspace_dir}" && flutter analyze >"${analyze_log}" 2>&1); then
    print_info 'flutter: flutter analyze passed'
  else
    print_fail 'flutter: flutter analyze failed'
    cat "${analyze_log}"
  fi

  rm -rf "${workspace_dir}"
  rm -f "${pubget_log}" "${analyze_log}"
}

run_target() {
  case "${TARGET_PLATFORM}" in
    android)
      verify_android_template
      ;;
    ios)
      verify_ios_template
      ;;
    flutter)
      verify_flutter_template
      ;;
    all)
      verify_android_template
      verify_ios_template
      verify_flutter_template
      ;;
    *)
      print_fail "Unsupported target '${TARGET_PLATFORM}'. Use one of: android, ios, flutter, all."
      ;;
  esac
}

run_target

print_info "Completed with ${FAILURE_COUNT} failure(s), ${WARNING_COUNT} warning(s)"
if [[ "${FAILURE_COUNT}" -gt 0 ]]; then
  exit 1
fi
