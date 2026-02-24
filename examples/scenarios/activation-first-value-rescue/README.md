# Activation: First Value Rescue

Rescue new signups who have not reached their first meaningful product outcome with a bounded, escalating sequence that cancels immediately on success.

## What This Example Demonstrates

- Multi-step activation recovery (not a single static reminder)
- One canonical OpenClix config shared across iOS, Android, Flutter, and React Native snippets
- Chained messages via `message_delivered` triggers
- Foreground scheduling/cancellation eligibility and debug/explain checks
- Quiet hours, delivery windows, jitter, and dedupe/cooldown controls

## Shared Config File

Canonical config for all platform snippets in this scenario:

- `examples/scenarios/activation-first-value-rescue/openclix.config.json`

All snippet files in this directory assume the config above. They intentionally do not duplicate the full JSON config content.

## Event Contract

This scenario uses app-level activation events:

- `user_signed_up`: emitted after account creation/signup completion; starts campaign enrollment
- `first_value_completed`: emitted when the user finishes the first meaningful action; cancels pending messages
- `onboarding_step_viewed` (optional): supporting analytics event you may already emit (not required by config)

Payload assumptions:

- No payload fields are required for enrollment/cancellation
- Optional personalization variables may be supplied by your runtime/template resolver, such as `userName` and `goalLabel`

Why this is better than a static reminder: the sequence escalates based on prior message delivery, respects windows/quiet hours, and cancels immediately on success instead of blasting fixed delays regardless of user progress.

## Platform Snippets Overview

### iOS

- `examples/scenarios/activation-first-value-rescue/snippets/ios/bootstrap-config.swift`
- `examples/scenarios/activation-first-value-rescue/snippets/ios/trigger-entry-event.swift`
- `examples/scenarios/activation-first-value-rescue/snippets/ios/trigger-cancel-event.swift`
- `examples/scenarios/activation-first-value-rescue/snippets/ios/foreground-eval-debug.swift`

Copy-paste boundary: adapt to your app lifecycle, bundled config loading, and local notification scheduling services.

### Android

- `examples/scenarios/activation-first-value-rescue/snippets/android/BootstrapConfig.kt`
- `examples/scenarios/activation-first-value-rescue/snippets/android/TriggerEntryEvent.kt`
- `examples/scenarios/activation-first-value-rescue/snippets/android/TriggerCancelEvent.kt`
- `examples/scenarios/activation-first-value-rescue/snippets/android/ForegroundEvalDebug.kt`

Copy-paste boundary: adapt to your DI container, app/Activity event wiring, and scheduler implementation.

### Flutter

- `examples/scenarios/activation-first-value-rescue/snippets/flutter/bootstrap_config.dart`
- `examples/scenarios/activation-first-value-rescue/snippets/flutter/trigger_entry_event.dart`
- `examples/scenarios/activation-first-value-rescue/snippets/flutter/trigger_cancel_event.dart`
- `examples/scenarios/activation-first-value-rescue/snippets/flutter/foreground_eval_debug.dart`

Copy-paste boundary: adapt to your plugin setup and state management/event bus choices.

### React Native

- `examples/scenarios/activation-first-value-rescue/snippets/react-native/bootstrapConfig.ts`
- `examples/scenarios/activation-first-value-rescue/snippets/react-native/triggerEntryEvent.ts`
- `examples/scenarios/activation-first-value-rescue/snippets/react-native/triggerCancelEvent.ts`
- `examples/scenarios/activation-first-value-rescue/snippets/react-native/foregroundEvalDebug.ts`

Copy-paste boundary: adapt to your JS integration layer and local notification/native-bridge implementation.

## Integration Notes

- Load and parse `examples/scenarios/activation-first-value-rescue/openclix.config.json` during app startup or feature bootstrap
- Call `replaceConfig(...)` after parsing the shared config
- Ingest `user_signed_up` at signup success
- Ingest `first_value_completed` as soon as the first core action succeeds
- Run `handleAppForeground(...)` on app foreground and use `explain(...)` when validating scheduling/cancellation decisions

## Platform-Specific Caveats

- Request notification permission after the app has shown value, not on first launch
- Respect quiet hours and the `10-21` first-message delivery window from config
- iOS pending local notification limits can force overflow behavior decisions
- Snippets use placeholder OpenClix runtime APIs because the OSS runtime interface is still evolving in this repo

## How To Test Manually

- Load the shared config and verify `replaceConfig(...)` succeeds
- Emit `user_signed_up`
- Confirm `gentle-first-value-nudge` is scheduled (or deferred) with jitter/window behavior
- Emit `first_value_completed` before later messages fire
- Confirm pending messages are cancelled and inspect `explain(...)` / snapshot output for reason traces

## What Is Intentionally Omitted

- Full app project scaffolding and build setup
- Persistence/event store implementations
- Production analytics mapping details
- End-to-end automated test harnesses

## Related Scenarios

- `examples/scenarios/streak-protection-escalation/README.md`
- `examples/scenarios/interrupted-flow-recovery/README.md`
- `examples/scenarios/_example-template/README.md`
