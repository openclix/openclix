# Retention: Streak Protection Escalation

Protect an at-risk recurring usage streak with escalating reminders that respect urgency, delivery windows, and cancellation when the user recovers or resets.

## What This Example Demonstrates

- Payload-filtered campaign entry (`streakCount`, `hoursRemaining`) to avoid noisy enrollment
- One canonical shared config reused across iOS, Android, Flutter, and React Native snippets
- Campaign/message priorities plus campaign limits (`minSpacingBetweenMessages`, `maxDeliveriesPer24h`)
- Urgency-aware rollover behavior (`drop_if_outside_window` for last chance)
- Immediate cancellation on `streak_extended` or `streak_reset`

## Shared Config File

Canonical config for all platform snippets in this scenario:

- `examples/scenarios/streak-protection-escalation/openclix.config.json`

All snippet files in this directory assume the config above. They intentionally do not duplicate the full JSON config content.

## Event Contract

Required events:

- `streak_risk_detected`: emitted by app logic when a streak is at risk and local orchestration should begin
- `streak_extended`: emitted when user preserves the streak; cancels pending reminders
- `streak_reset`: emitted when the streak is already lost; cancels pending reminders to avoid irrelevant nudges

Payload assumptions for `streak_risk_detected`:

- `streakCount` (integer)
- `hoursRemaining` (integer)
- `coreActionLabel` (string, optional; used for message copy)

Why this is better than a static reminder: OpenClix lets the app enroll only when risk is real, chain urgency over time, enforce spacing and daily caps, and drop outdated “last chance” notifications instead of sending them the next day.

## Platform Snippets Overview

### iOS

- `examples/scenarios/streak-protection-escalation/snippets/ios/bootstrap-config.swift`
- `examples/scenarios/streak-protection-escalation/snippets/ios/trigger-entry-event.swift`
- `examples/scenarios/streak-protection-escalation/snippets/ios/trigger-cancel-event.swift`
- `examples/scenarios/streak-protection-escalation/snippets/ios/foreground-eval-debug.swift`

Copy-paste boundary: adapt to your streak computation pipeline and lifecycle integration points.

### Android

- `examples/scenarios/streak-protection-escalation/snippets/android/BootstrapConfig.kt`
- `examples/scenarios/streak-protection-escalation/snippets/android/TriggerEntryEvent.kt`
- `examples/scenarios/streak-protection-escalation/snippets/android/TriggerCancelEvent.kt`
- `examples/scenarios/streak-protection-escalation/snippets/android/ForegroundEvalDebug.kt`

Copy-paste boundary: adapt to your background worker/app event pipeline and notification adapter.

### Flutter

- `examples/scenarios/streak-protection-escalation/snippets/flutter/bootstrap_config.dart`
- `examples/scenarios/streak-protection-escalation/snippets/flutter/trigger_entry_event.dart`
- `examples/scenarios/streak-protection-escalation/snippets/flutter/trigger_cancel_event.dart`
- `examples/scenarios/streak-protection-escalation/snippets/flutter/foreground_eval_debug.dart`

Copy-paste boundary: adapt to your plugin lifecycle and domain event stream.

### React Native

- `examples/scenarios/streak-protection-escalation/snippets/react-native/bootstrapConfig.ts`
- `examples/scenarios/streak-protection-escalation/snippets/react-native/triggerEntryEvent.ts`
- `examples/scenarios/streak-protection-escalation/snippets/react-native/triggerCancelEvent.ts`
- `examples/scenarios/streak-protection-escalation/snippets/react-native/foregroundEvalDebug.ts`

Copy-paste boundary: adapt to your JS state/event layer and native notification integration.

## Integration Notes

- Load and parse `examples/scenarios/streak-protection-escalation/openclix.config.json` at startup
- Call `replaceConfig(...)` before ingesting streak risk events
- Emit `streak_risk_detected` only after app-side streak logic calculates risk (OpenClix handles orchestration after entry)
- Emit `streak_extended` or `streak_reset` immediately to cancel pending notifications
- Use foreground debug snippets to verify why a message was scheduled, deferred, dropped, or cancelled

## Platform-Specific Caveats

- Ensure your app computes `hoursRemaining` consistently in local time if that payload drives enrollment
- A `drop_if_outside_window` last-chance reminder is intentional and should not be treated as scheduling failure
- Local notification limits still apply; priorities help but do not remove platform caps
- Snippets use placeholder OpenClix runtime APIs and should be adapted to your architecture

## How To Test Manually

- Load the shared config and call `replaceConfig(...)`
- Ingest `streak_risk_detected` with payload `{ streakCount: 7, hoursRemaining: 18, coreActionLabel: "check-in" }`
- Verify first reminder schedules and later reminders chain based on prior delivery
- Ingest `streak_extended` (or `streak_reset`) before the last message
- Confirm pending reminders are cancelled and inspect snapshot/explain output

## What Is Intentionally Omitted

- Streak calculation logic itself (app/domain-owned)
- Persistent history implementation and analytics transport
- Platform notification permission onboarding UX
- End-to-end test apps

## Related Scenarios

- `examples/scenarios/activation-first-value-rescue/README.md`
- `examples/scenarios/interrupted-flow-recovery/README.md`
- `examples/scenarios/_example-template/README.md`
