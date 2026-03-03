---
name: openclix-init
description: Integrate OpenClix by adding local client code templates into an existing mobile app with minimal edits, strict dependency reuse, and post-integration build verification.
---

# OpenClix Init

## Purpose

This skill adds OpenClix functionality by copying client code into the user project, not by installing an SDK package.  
Use a local-source integration model (shadcn-style): copy, adapt, wire, verify.

## Core Rules

- Detect the real platform first using project files.
- Prioritize minimal edits to existing user code.
- Keep all OpenClix files in a dedicated namespace/directory.
- When creating local planning/report artifacts under `.clix/**`, ensure `.clix/` is listed in `.gitignore` (add it if missing).
- Reuse existing dependencies whenever possible.
- Do not add or update dependencies without explicit user approval.
- Run a build after integration and fix only integration-caused issues.
- Do not use in-memory fallback in production integration paths.

## Platform Detection

Use file evidence in this order:

| Priority | Platform | Required Evidence |
|----------|----------|-------------------|
| 1 | Expo | `app.json` or `app.config.*` with `expo` |
| 2 | React Native | `package.json` with `react-native` and typical `ios/` + `android/` structure |
| 3 | Flutter | `pubspec.yaml` with Flutter SDK |
| 4 | iOS native | `*.xcodeproj` or `*.xcworkspace` or `Package.swift` |
| 5 | Android native | `build.gradle` or `build.gradle.kts` |

If signals conflict, trust concrete file evidence and report the mismatch.

## Template Selection

- Expo / React Native: `templates/react-native/`
- Flutter: `templates/flutter/`
- iOS: `templates/ios/`
- Android: `templates/android/` (package namespace `ai.openclix.*`)

`templates/react-native/` is the canonical reference when platform ports need alignment.

## Integration Workflow

1. Identify platform and current startup/event/lifecycle entry points.
2. Copy the selected template into a dedicated OpenClix area in the user project.
3. Wire only required touchpoints:
   - initialization at app startup
   - event tracking call path
   - foreground/app lifecycle trigger
4. Keep existing architecture and code style intact; avoid broad refactors.
5. Validate against `references/openclix.schema.json` when config/schema changes are involved.

## Adapter Selection Rules

Select adapters using existing dependencies only:

1. Choose concrete adapters at integration time; avoid runtime dependency auto-detection.
2. If the project already has a supported persistent storage dependency, wire that implementation.
3. If notification libraries already exist, wire the matching scheduler adapter.
4. If no compatible dependency exists, fail fast with a clear integration error.
5. Keep degraded in-memory paths out of production template defaults.

React Native / Expo storage selection:

- AsyncStorage project: use `AsyncStorageCampaignStateRepository`.
- MMKV project: use `MmkvCampaignStateRepository`.
- If both exist, prefer the project standard and copy only one storage adapter into the app.
- Inject `campaignStateRepository` explicitly when calling `Clix.initialize(...)`.

React Native / Expo scheduler selection:

- Notifee project: create `new NotifeeScheduler(notifee)`.
- Expo notifications project: create `new ExpoNotificationScheduler(ExpoNotifications)`.
- Inject `messageScheduler` explicitly when calling `Clix.initialize(...)`.

Platform expectations:

- React Native / Expo:
  - Do not use runtime adapter auto-detection in `Clix` core.
  - Select storage/scheduler implementations during integration and inject dependencies explicitly.
  - If compatible implementations are unavailable, initialization must fail with clear instructions.
- Flutter:
  - Use callback-based scheduler adapter for existing notification plugin
  - Require an explicit scheduler and state repository dependency at initialization
- iOS / Android native:
  - Use platform-native implementations by default
  - Do not introduce in-memory/no-op fallback as the default runtime behavior

## Notification Permission and Foreground Setup

Notification permission must be requested before campaign triggers fire. Each platform template includes a permission utility; the integration agent must wire it at the appropriate location in the host app.

### React Native / Expo — Permission

- **Notifee projects:** Import `requestNotifeePermission` from `infrastructure/NotifeeNotificationSetup`. Call it at app startup (e.g. in `App.tsx` or a startup hook) passing the Notifee adapter. No foreground handler is needed — Notifee handles foreground display natively via `presentationOptions`.
- **Expo projects:** Import `requestExpoPermission` and `setupExpoForegroundHandler` from `infrastructure/ExpoNotificationSetup`. Call `setupExpoForegroundHandler` once during initialization, then call `requestExpoPermission` at app startup.

### iOS — Permission and Foreground Display

1. **Permission:** Call `await NotificationPermission.request()` at app startup (e.g. in `application(_:didFinishLaunchingWithOptions:)` or a SwiftUI `.task` modifier). This calls `UNUserNotificationCenter.requestAuthorization`.
2. **Foreground display:** iOS suppresses notification banners when the app is active. The template provides `ForegroundNotificationHandler.handleWillPresent(notification:completionHandler:)` as a static method.
   - **Critical:** iOS allows only ONE `UNUserNotificationCenterDelegate` per app. Do NOT assign `ForegroundNotificationHandler` as the delegate. Instead, set the app's existing delegate (usually `AppDelegate`) as `UNUserNotificationCenter.current().delegate = self`, and call the static method from the delegate's `willPresent` implementation.

### Android — Permission

1. **Manifest:** Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />` to `AndroidManifest.xml`.
2. **Runtime request:** On API 33+ (Android 13), call `NotificationPermission.shouldRequestPermission(context)` at startup. If it returns `true`, use the Activity's `requestPermissions()` or `ActivityResultLauncher` to request `NotificationPermission.getPermissionString()`.
3. Android does NOT need foreground display setup — `NotificationManager.notify()` always displays regardless of app state.

### Flutter — Permission and Foreground Display

The `NotificationPermission` class in `notification/notification_permission.dart` accepts callbacks. Wire the host app's notification plugin:

1. Provide a `requestPermission` callback that calls the plugin's permission request API.
2. Provide a `checkPermissionStatus` callback that checks current status.
3. Optionally provide a `setupForegroundHandler` callback to configure foreground display (required for iOS, not needed for Android).
4. Call `permission.request()` at app startup before campaign triggers fire.
5. Call `permission.setupForeground()` during initialization if the handler is provided.

## Directory and Namespace Policy

OpenClix files must stay grouped in a dedicated location:

- React Native / Expo: `src/openclix/`
- Flutter: `lib/openclix/`
- iOS: `OpenClix/` or `Sources/OpenClix/`
- Android: `app/src/main/kotlin/ai/openclix/` with `ai.openclix.*` packages

## Dependency Policy

Before changing dependencies:

1. Check what the selected template expects.
2. Check what the user project already has.
3. Prefer existing project libraries or platform APIs.
4. If replacement is possible, adapt template code instead of adding dependencies.
5. If no safe replacement exists, ask for approval before any dependency add/update.

Never run package-manager install/update commands without approval.

## Build Verification

After wiring, run platform-appropriate build/analysis commands based on detected project structure.
Prefer project-native commands first (existing scripts, Gradle tasks, Xcode scheme, Flutter workflow).

If unclear, use common fallback commands:

- React Native / Expo: `npx tsc --noEmit`
- Android: `./gradlew assembleDebug`
- iOS: `xcodebuild -scheme <scheme> build` or `swift build`
- Flutter: `flutter analyze`

If build fails, apply minimal targeted fixes and retry. Stop only on hard blockers.

## Completion Checklist

- OpenClix code added under dedicated namespace/directory.
- Existing app code changes are minimal and localized.
- No unapproved dependency additions or upgrades.
- Adapter wiring prefers existing dependencies and fails fast when unavailable.
- Build verification executed.
- Any remaining blockers clearly reported.
