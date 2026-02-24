# Recovery: Interrupted High-Intent Flow

Recover users who abandon a high-intent flow (checkout, booking, application, setup, upload) with contextual follow-ups that branch on engagement and cancel on restart/completion.

## What This Example Demonstrates

- Contextual entry using `critical_flow_abandoned` with payload filters (`intentScore`)
- One canonical shared config reused across iOS, Android, Flutter, and React Native snippets
- Deep link + action buttons in local notifications
- Branch-like sequencing using `message_opened` and `message_delivered` triggers from the same first message
- `message_state` cancellation conditions to reduce redundant follow-ups
- Cooldown, dedupe, and explain/debug-friendly recovery flow

## Shared Config File

Canonical config for all platform snippets in this scenario:

- `examples/scenarios/interrupted-flow-recovery/openclix.config.json`

All snippet files in this directory assume the config above. They intentionally do not duplicate the full JSON config content.

## Event Contract

Required events:

- `critical_flow_abandoned`: emitted when a high-intent flow is exited/abandoned and recovery should begin
- `critical_flow_restarted`: emitted when user returns to the flow; cancels pending reminders
- `critical_flow_completed`: emitted when user finishes the flow; cancels pending reminders

Payload assumptions for `critical_flow_abandoned`:

- `flowKey` (string)
- `flowLabel` (string)
- `intentScore` (integer; config uses this for entry filtering)
- `resumeDeepLink` (string URI-reference, optional app-provided context)

Why this is better than a static reminder: OpenClix can branch follow-ups based on engagement with the first notification (opened vs only delivered), use cancellation rules, and suppress redundant closeout messages using message-state conditions.

## Platform Snippets Overview

### iOS

- `examples/scenarios/interrupted-flow-recovery/snippets/ios/bootstrap-config.swift`
- `examples/scenarios/interrupted-flow-recovery/snippets/ios/trigger-entry-event.swift`
- `examples/scenarios/interrupted-flow-recovery/snippets/ios/trigger-cancel-event.swift`
- `examples/scenarios/interrupted-flow-recovery/snippets/ios/foreground-eval-debug.swift`

Copy-paste boundary: adapt to your flow controller lifecycle and notification action handling.

### Android

- `examples/scenarios/interrupted-flow-recovery/snippets/android/BootstrapConfig.kt`
- `examples/scenarios/interrupted-flow-recovery/snippets/android/TriggerEntryEvent.kt`
- `examples/scenarios/interrupted-flow-recovery/snippets/android/TriggerCancelEvent.kt`
- `examples/scenarios/interrupted-flow-recovery/snippets/android/ForegroundEvalDebug.kt`

Copy-paste boundary: adapt to your navigation/deep-link layer and app event orchestration.

### Flutter

- `examples/scenarios/interrupted-flow-recovery/snippets/flutter/bootstrap_config.dart`
- `examples/scenarios/interrupted-flow-recovery/snippets/flutter/trigger_entry_event.dart`
- `examples/scenarios/interrupted-flow-recovery/snippets/flutter/trigger_cancel_event.dart`
- `examples/scenarios/interrupted-flow-recovery/snippets/flutter/foreground_eval_debug.dart`

Copy-paste boundary: adapt to your route restoration and notification action integration.

### React Native

- `examples/scenarios/interrupted-flow-recovery/snippets/react-native/bootstrapConfig.ts`
- `examples/scenarios/interrupted-flow-recovery/snippets/react-native/triggerEntryEvent.ts`
- `examples/scenarios/interrupted-flow-recovery/snippets/react-native/triggerCancelEvent.ts`
- `examples/scenarios/interrupted-flow-recovery/snippets/react-native/foregroundEvalDebug.ts`

Copy-paste boundary: adapt to your JS navigation, deep-link handling, and native notification bridge.

## Integration Notes

- Load and parse `examples/scenarios/interrupted-flow-recovery/openclix.config.json` during startup/feature bootstrap
- Call `replaceConfig(...)` before ingesting `critical_flow_abandoned`
- Include flow context in event payloads (`flowKey`, `flowLabel`, `intentScore`) so entry filtering and copy are meaningful
- Emit `critical_flow_restarted` and `critical_flow_completed` from navigation or completion hooks to stop stale reminders
- Use `handleAppForeground(...)`, `getSnapshot(...)`, and `explain(...)` while tuning branch behavior and collision avoidance

## Platform-Specific Caveats

- Notification action handling varies by platform; snippets demonstrate intent, not production wiring
- If your app does not compute `intentScore`, remove or adjust the payload filter in config
- Message-opened triggered follow-ups require your runtime integration to emit/ingest opened events consistently
- Snippets use placeholder OpenClix runtime APIs and must be adapted to real integration points

## How To Test Manually

- Load the shared config and call `replaceConfig(...)`
- Ingest `critical_flow_abandoned` with payload such as `{ flowKey: "checkout", flowLabel: "checkout", intentScore: 80, resumeDeepLink: "app://checkout/resume" }`
- Confirm `resume-flow-reminder` schedules with jitter/window behavior
- Simulate either notification open (`message_opened`) or no open path and inspect resulting branch scheduling
- Ingest `critical_flow_completed` (or `critical_flow_restarted`) and verify pending cancellations
- Run foreground re-evaluation and inspect `explain(...)` output for skipped/scheduled/cancelled reasons

## What Is Intentionally Omitted

- Production notification action callbacks and navigation router setup
- Server-side checkout/booking state synchronization
- Full event schema typing and validation layers
- End-to-end runnable app implementations

## Related Scenarios

- `examples/scenarios/activation-first-value-rescue/README.md`
- `examples/scenarios/streak-protection-escalation/README.md`
- `examples/scenarios/_example-template/README.md`
