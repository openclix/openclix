# Provider Detection Matrix

Use these checks to detect installed product analytics (PA) providers.
Only use concrete file evidence.

## Priority

1. `firebase`
2. `posthog`
3. `mixpanel`
4. `amplitude`

When multiple are detected, select exactly one by this priority.

## File classes to scan

- JavaScript/TypeScript manifests: `package.json`
- Flutter manifests: `pubspec.yaml`
- iOS manifests: `Podfile`, `Package.swift`
- iOS Xcode SPM manifests (no `Package.swift` case): `Package.resolved`, `project.pbxproj`
- Android manifests: `build.gradle`, `build.gradle.kts`

Ignore generated/vendor folders: `.git`, `node_modules`, `.next`, `build`, `dist`, `.dart_tool`, `.gradle`.

## Evidence patterns

### Firebase

- `@react-native-firebase/analytics` (RN/Expo)
- `firebase_analytics` (Flutter)
- `Firebase/Analytics` (CocoaPods)
- `firebase-ios-sdk` with Analytics product (SwiftPM)
- `github.com/firebase/firebase-ios-sdk` (Xcode `project.pbxproj`)
- `com.google.firebase:firebase-analytics`
- `com.google.firebase:firebase-analytics-ktx`

### PostHog

- `posthog-react-native`
- `posthog_flutter`
- `PostHog` (CocoaPods)
- `posthog-ios` (SwiftPM)
- `github.com/posthog/posthog-ios` (Xcode `project.pbxproj`)
- `com.posthog:posthog-android`

### Mixpanel

- `mixpanel-react-native`
- `mixpanel_flutter`
- `Mixpanel-swift` (CocoaPods/SwiftPM)
- `github.com/mixpanel/mixpanel-swift` (Xcode `project.pbxproj`)
- `com.mixpanel.android:mixpanel-android`

### Amplitude

- `@amplitude/analytics-react-native`
- `amplitude_flutter`
- `AmplitudeSwift` (CocoaPods/SwiftPM)
- `Amplitude-Swift` (SwiftPM)
- `github.com/amplitude/amplitude-swift` (Xcode `project.pbxproj`)
- `com.amplitude:analytics-android`

## OpenClix presence check

OpenClix is considered integrated when at least one strong signal exists in app code:

- `Clix.initialize(`
- `ClixCampaignManager`
- `ai.openclix`
- `src/openclix/` or `lib/openclix/` namespace usage

If missing, stop and run `openclix-init` first.

## Script output contract

`skills/openclix-analytics/scripts/detect_pa.sh` emits JSON:

```json
{
  "root": "/abs/path",
  "installed_providers": ["firebase", "mixpanel"],
  "selected_provider": "firebase",
  "priority_order": ["firebase", "posthog", "mixpanel", "amplitude"],
  "evidence": [
    {
      "provider": "firebase",
      "file": "/abs/path/package.json",
      "match": "@react-native-firebase/analytics"
    }
  ],
  "openclix_detected": true,
  "openclix_evidence": [
    "/abs/path/src/openclix/core/Clix.ts:109:Clix.initialize("
  ]
}
```

Use this JSON as the sole branching input in the skill workflow.
