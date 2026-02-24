# Example Template (Structure Only)

Structural template showing how one OpenClix config file can be shared across iOS, Android, Flutter, and React Native snippets.

## What This Example Demonstrates

- Scenario-first organization for cross-platform examples
- One canonical OpenClix config shared across all platform snippets
- Separate snippet files for scheduling and cancellation behaviors
- README and metadata conventions for human + AI discoverability

## Shared Config File

Canonical config for all platform snippets in this scenario:

- `examples/scenarios/_example-template/openclix.config.json`

All snippet files in this directory assume the config above. They intentionally do not duplicate the full JSON config content.

## Event Contract

This template uses placeholder events to demonstrate shape only.

- `user_signed_up`: emitted when a user completes signup; starts campaign enrollment
- `first_action_completed`: emitted when user completes the target action; cancels pending campaign messages

Payload assumptions (template only): payload may include user identifiers or onboarding attributes, but no payload fields are required by this template config.

## Platform Snippets Overview

### iOS

- `examples/scenarios/_example-template/snippets/ios/schedule-on-entry.swift`
- `examples/scenarios/_example-template/snippets/ios/cancel-on-event.swift`

Copy-paste boundary: adapt to your app lifecycle hooks (`AppDelegate` / scene lifecycle), local notification scheduler, and actual OpenClix runtime API names.

### Android

- `examples/scenarios/_example-template/snippets/android/ScheduleOnEntry.kt`
- `examples/scenarios/_example-template/snippets/android/CancelOnEvent.kt`

Copy-paste boundary: adapt to your dependency injection setup, `Application`/`Activity` event wiring, and local notification scheduling implementation.

### Flutter

- `examples/scenarios/_example-template/snippets/flutter/schedule_on_entry.dart`
- `examples/scenarios/_example-template/snippets/flutter/cancel_on_event.dart`

Copy-paste boundary: adapt to your plugin initialization, app lifecycle observer, and event stream/state management architecture.

### React Native

- `examples/scenarios/_example-template/snippets/react-native/scheduleOnEntry.ts`
- `examples/scenarios/_example-template/snippets/react-native/cancelOnEvent.ts`

Copy-paste boundary: adapt to your JS integration layer and any native module/bridge used for local notifications.

## Integration Notes

- Load and parse `examples/scenarios/_example-template/openclix.config.json` at app startup (or bundle/embed an equivalent app-local path in production)
- Call `replaceConfig(...)` (or equivalent) after parsing the shared config
- Ingest `user_signed_up` when the signup flow completes
- Ingest `first_action_completed` to cancel the remaining campaign messages
- Run foreground evaluation on app foreground and tracked events when supported by your runtime integration

## Platform-Specific Caveats

- Request notification permission at a value moment, not on first launch
- Respect quiet hours and delivery windows defined in the shared config
- iOS commonly limits pending local notifications (often ~64); keep scheduler overflow behavior explicit
- Foreground/background eligibility is part of the config and should be honored consistently across platforms
- These snippets use placeholder API names because the reference SDK/runtime is not finalized in this repo yet

## How To Test Manually

- Load the shared config into your app integration
- Emit `user_signed_up`
- Confirm a local notification is scheduled within the delivery window (or deferred)
- Emit `first_action_completed` before delivery
- Confirm pending message cancellation and inspect any debug/explain output available in your integration

## What Is Intentionally Omitted

- Full app projects and build files
- Production persistence stores and event history implementations
- Real notification permission UI flows
- End-to-end tests and CI automation for example execution

## Related Scenarios

- Future scenarios (to be added): onboarding-first-action, streak-protection, re-engagement-inactive-user, feature-discovery-nudge
