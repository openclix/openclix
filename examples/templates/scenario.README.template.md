# <Scenario Title>

One-line summary of the use case and user outcome.

## What This Example Demonstrates

- Primary behavior (for example: onboarding nudge after signup)
- Shared config reuse across iOS, Android, Flutter, and React Native
- Where to place scheduling/cancellation hooks in a real app

## Shared Config File

Canonical config for all platform snippets in this scenario:

- `examples/scenarios/<scenario-slug>/openclix.config.json`

Do not duplicate the full config JSON in platform snippets. Platform files should only show loading/parsing and integration code.

## Event Contract

Events used by this scenario (names and payload assumptions):

- `example_event_name`: describe when it is emitted and any relevant payload keys
- `example_cancel_event`: describe cancellation trigger semantics

## Platform Snippets Overview

### iOS

- `examples/scenarios/<scenario-slug>/snippets/ios/<file>.swift`

Copy-paste boundary: adapt to your app's notification manager, lifecycle hooks, and event pipeline.

### Android

- `examples/scenarios/<scenario-slug>/snippets/android/<file>.kt`

Copy-paste boundary: adapt to your app's DI container, lifecycle observers, and scheduler implementation.

### Flutter

- `examples/scenarios/<scenario-slug>/snippets/flutter/<file>.dart`

Copy-paste boundary: adapt to your plugin setup and state management architecture.

### React Native

- `examples/scenarios/<scenario-slug>/snippets/react-native/<file>.ts`

Copy-paste boundary: adapt to your native bridge or JS integration layer.

## Integration Notes

- Where to load config in app startup
- Where to call `replaceConfig(...)` or equivalent in your integration
- Where to ingest events and trigger foreground evaluation
- Where to wire manual cancellation hooks if applicable

## Platform-Specific Caveats

- Notification permission timing and UX
- Quiet hours and local notification limits (for example iOS pending cap)
- App foreground/background eligibility behavior
- Platform scheduler constraints and process restarts

## How To Test Manually

- Emit the entry event
- Confirm campaign enrollment and scheduled message creation
- Emit the cancel event and verify pending message cancellation
- Inspect debug/explain output when available

## What Is Intentionally Omitted

- Full app scaffolding
- Persistence layer implementation
- Production analytics/event instrumentation details
- Production-ready error handling and retries

## Related Scenarios

- Add links here when additional scenarios exist
