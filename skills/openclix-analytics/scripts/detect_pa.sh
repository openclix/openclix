#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$PWD}"
if [[ ! -d "$ROOT" ]]; then
  echo "Target directory does not exist: $ROOT" >&2
  exit 1
fi

ROOT="$(cd "$ROOT" && pwd)"

installed=()
evidence=()
openclix_evidence=()

add_provider() {
  local provider="$1"
  local file="$2"
  local match="$3"
  local entry="$provider|$file|$match"

  local existing_entry
  for existing_entry in "${evidence[@]:-}"; do
    if [[ "$existing_entry" == "$entry" ]]; then
      entry=""
      break
    fi
  done
  if [[ -n "$entry" ]]; then
    evidence+=("$entry")
  fi

  local exists=0
  local item
  for item in "${installed[@]:-}"; do
    if [[ "$item" == "$provider" ]]; then
      exists=1
      break
    fi
  done
  if [[ $exists -eq 0 ]]; then
    installed+=("$provider")
  fi
}

scan_file() {
  local file="$1"
  local base
  base="$(basename "$file")"

  case "$base" in
    package.json)
      grep -qi '"@react-native-firebase/analytics"' "$file" && add_provider "firebase" "$file" "@react-native-firebase/analytics"
      grep -qi '"posthog-react-native"' "$file" && add_provider "posthog" "$file" "posthog-react-native"
      grep -qi '"mixpanel-react-native"' "$file" && add_provider "mixpanel" "$file" "mixpanel-react-native"
      grep -qi '"@amplitude/analytics-react-native"' "$file" && add_provider "amplitude" "$file" "@amplitude/analytics-react-native"
      ;;
    pubspec.yaml)
      grep -qE '^[[:space:]]*firebase_analytics:' "$file" && add_provider "firebase" "$file" "firebase_analytics"
      grep -qE '^[[:space:]]*posthog_flutter:' "$file" && add_provider "posthog" "$file" "posthog_flutter"
      grep -qE '^[[:space:]]*mixpanel_flutter:' "$file" && add_provider "mixpanel" "$file" "mixpanel_flutter"
      grep -qE '^[[:space:]]*amplitude_flutter:' "$file" && add_provider "amplitude" "$file" "amplitude_flutter"
      ;;
    Podfile)
      grep -qE "pod[[:space:]]+['\"]Firebase/Analytics['\"]" "$file" && add_provider "firebase" "$file" "Firebase/Analytics"
      grep -qE "pod[[:space:]]+['\"]PostHog['\"]" "$file" && add_provider "posthog" "$file" "PostHog"
      grep -qE "pod[[:space:]]+['\"]Mixpanel-swift['\"]" "$file" && add_provider "mixpanel" "$file" "Mixpanel-swift"
      grep -qE "pod[[:space:]]+['\"]AmplitudeSwift['\"]" "$file" && add_provider "amplitude" "$file" "AmplitudeSwift"
      ;;
    Package.swift)
      grep -qi "firebase-ios-sdk" "$file" && add_provider "firebase" "$file" "firebase-ios-sdk"
      grep -qi "posthog-ios" "$file" && add_provider "posthog" "$file" "posthog-ios"
      grep -qi "mixpanel-swift" "$file" && add_provider "mixpanel" "$file" "mixpanel-swift"
      grep -qi "Amplitude-Swift" "$file" && add_provider "amplitude" "$file" "Amplitude-Swift"
      ;;
    Package.resolved)
      grep -qi "firebase-ios-sdk" "$file" && add_provider "firebase" "$file" "firebase-ios-sdk"
      grep -qi "posthog-ios" "$file" && add_provider "posthog" "$file" "posthog-ios"
      grep -qi "mixpanel-swift" "$file" && add_provider "mixpanel" "$file" "mixpanel-swift"
      grep -qi "amplitude-swift" "$file" && add_provider "amplitude" "$file" "amplitude-swift"
      ;;
    project.pbxproj)
      grep -qi "github.com/firebase/firebase-ios-sdk" "$file" && add_provider "firebase" "$file" "github.com/firebase/firebase-ios-sdk"
      grep -qi "firebase-ios-sdk" "$file" && add_provider "firebase" "$file" "firebase-ios-sdk"
      grep -qi "github.com/posthog/posthog-ios" "$file" && add_provider "posthog" "$file" "github.com/posthog/posthog-ios"
      grep -qi "posthog-ios" "$file" && add_provider "posthog" "$file" "posthog-ios"
      grep -qi "github.com/mixpanel/mixpanel-swift" "$file" && add_provider "mixpanel" "$file" "github.com/mixpanel/mixpanel-swift"
      grep -qi "mixpanel-swift" "$file" && add_provider "mixpanel" "$file" "mixpanel-swift"
      grep -qi "github.com/amplitude/amplitude-swift" "$file" && add_provider "amplitude" "$file" "github.com/amplitude/amplitude-swift"
      grep -qi "amplitude-swift" "$file" && add_provider "amplitude" "$file" "amplitude-swift"
      ;;
    build.gradle|build.gradle.kts)
      grep -qi "com.google.firebase:firebase-analytics-ktx" "$file" && add_provider "firebase" "$file" "com.google.firebase:firebase-analytics-ktx"
      grep -qi "com.google.firebase:firebase-analytics" "$file" && add_provider "firebase" "$file" "com.google.firebase:firebase-analytics"
      grep -qi "com.posthog:posthog-android" "$file" && add_provider "posthog" "$file" "com.posthog:posthog-android"
      grep -qi "com.mixpanel.android:mixpanel-android" "$file" && add_provider "mixpanel" "$file" "com.mixpanel.android:mixpanel-android"
      grep -qi "com.amplitude:analytics-android" "$file" && add_provider "amplitude" "$file" "com.amplitude:analytics-android"
      ;;
  esac

  return 0
}

while IFS= read -r -d '' file; do
  scan_file "$file"
done < <(
  find "$ROOT" \
    -type d \( -name .git -o -name node_modules -o -name .next -o -name out -o -name build -o -name dist -o -name .dart_tool -o -name .gradle \) -prune -o \
    -type f \( -name package.json -o -name pubspec.yaml -o -name Podfile -o -name Package.swift -o -name Package.resolved -o -name project.pbxproj -o -name build.gradle -o -name build.gradle.kts \) -print0
)

if command -v rg >/dev/null 2>&1; then
  while IFS= read -r line; do
    openclix_evidence+=("$line")
  done < <(
    rg -n -S "Clix\.initialize\(|ClixCampaignManager|ai\.openclix|src/openclix/|lib/openclix/" "$ROOT" \
      --glob '!**/.git/**' \
      --glob '!**/node_modules/**' \
      --glob '!**/.next/**' \
      --glob '!**/build/**' \
      --glob '!**/dist/**' \
      --glob '!**/.dart_tool/**' \
      --glob '!**/skills/**' \
      --glob '!**/scripts/**' \
      --glob '!**/docs/**' \
      --glob '!**/README.md' \
      --glob '!**/AGENT.md' \
      --max-count 1 | head -n 20 || true
  )
fi

selected=""
for candidate in firebase posthog mixpanel amplitude; do
  for provider in "${installed[@]:-}"; do
    if [[ "$provider" == "$candidate" ]]; then
      selected="$candidate"
      break 2
    fi
  done
done

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//"/\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

printf '{\n'
printf '  "root": "%s",\n' "$(json_escape "$ROOT")"

printf '  "installed_providers": ['
for i in "${!installed[@]}"; do
  [[ $i -gt 0 ]] && printf ', '
  printf '"%s"' "$(json_escape "${installed[$i]}")"
done
printf '],\n'

if [[ -n "$selected" ]]; then
  printf '  "selected_provider": "%s",\n' "$(json_escape "$selected")"
else
  printf '  "selected_provider": null,\n'
fi

printf '  "priority_order": ["firebase", "posthog", "mixpanel", "amplitude"],\n'

printf '  "evidence": [\n'
for i in "${!evidence[@]}"; do
  IFS='|' read -r provider file match <<<"${evidence[$i]}"
  [[ $i -gt 0 ]] && printf ',\n'
  printf '    {"provider": "%s", "file": "%s", "match": "%s"}' \
    "$(json_escape "$provider")" \
    "$(json_escape "$file")" \
    "$(json_escape "$match")"
done
printf '\n  ],\n'

if [[ ${#openclix_evidence[@]} -gt 0 ]]; then
  printf '  "openclix_detected": true,\n'
else
  printf '  "openclix_detected": false,\n'
fi

printf '  "openclix_evidence": ['
for i in "${!openclix_evidence[@]}"; do
  [[ $i -gt 0 ]] && printf ', '
  printf '"%s"' "$(json_escape "${openclix_evidence[$i]}")"
done
printf ']\n'
printf '}\n'
