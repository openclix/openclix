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
