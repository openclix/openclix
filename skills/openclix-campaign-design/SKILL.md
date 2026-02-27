---
name: openclix-campaign-design
description: Design and iterate OpenClix campaign configurations from product goals and app events. Use this skill when users ask to create, refine, or validate OpenClix local notification campaigns, trigger logic (event/scheduled/recurring), suppression rules (do_not_disturb/frequency_cap), or campaign message content in JSON config files.
---

# OpenClix Campaign Design

Turn campaign goals into schema-valid OpenClix config JSON with minimal ambiguity.
Keep outputs auditable and compatible with the OpenClix runtime contract.
When the user asks for implementation, install the final config JSON into app resources and wire runtime initialization code.

## Workflow

Follow these phases in order.

1. Collect campaign context.
2. Build or refresh an app profile artifact.
3. Design campaign set.
4. Generate or update OpenClix config.
5. Validate and hand off.
6. Install config resource and wire app initialization.

## 1) Collect Campaign Context

Gather only missing facts needed for design decisions:

- app name and platform(s)
- primary retention goals (onboarding, habit, re-engagement, milestone, feature discovery)
- event taxonomy: event names + available property keys
- current campaign config path (if existing)
- existing app resource/file management convention for JSON assets
- startup location where Clix is currently initialized (or should be initialized)
- global constraints: quiet hours, frequency cap expectations, locale/timezone assumptions

If the user already provided enough detail, do not re-ask resolved points.

## 2) Build Or Refresh App Profile Artifact

Before authoring campaigns:

- Read `references/json-schemas.md`.
- Read `references/schemas/app-profile.schema.json`.
- Create or update `.clix-campaigns/app-profile.json`.
- Capture goals, event taxonomy, personalization variables, existing campaigns, and constraints.
- Present the JSON and confirm accuracy before proceeding.

## 3) Design Campaign Set

Before drafting campaigns:

- Read `references/openclix-campaign-playbook.md`.

Design 3-5 campaigns unless the user requests a different count.
Spread campaigns across lifecycle stages or explicit user priorities.

OpenClix modeling rule:

- One campaign delivers one message.
- Model multi-step journeys as multiple related campaign IDs (for example `onboarding-step-1`, `onboarding-step-2`, `onboarding-step-3`).

Trigger selection rule:

- Use `event` for behavior-driven messaging.
- Use `scheduled` for one-time date/time delivery.
- Use `recurring` for repeated cadence.

Suppression and cancellation rule:

- Use `delay_seconds` + `cancel_event` for pending enrollment cancellation when behavior can invalidate intent.
- Use global `settings.do_not_disturb` and `settings.frequency_cap` when needed.

Content rule:

- Use only known personalization keys with `{{key}}` syntax.
- Keep schema-safe limits: title <= 120, body <= 500.
- Prefer concise UX copy (title <= 45, body <= 140) unless user needs longer copy.

## 4) Generate Or Update OpenClix Config

Before writing config:

- Read `references/schemas/openclix.schema.json`.

Write updates in this order:

1. Update the user-specified config path if provided.
2. Otherwise write `.clix-campaigns/openclix-config.json`.

Remote delivery note:

- The same generated config JSON can be uploaded to a web server and served over HTTPS for remote access.
- Use the same schema-valid JSON artifact for both local resource delivery and remote endpoint delivery.
- Public schema reference for external validators: `https://openclix.ai/schemas/openclix.schema.json`.

Guarantee these invariants:

- `"$schema"` is exactly `https://openclix.ai/schemas/openclix.schema.json`.
- `schema_version` is exactly `openclix/config/v1`.
- `config_version` is explicit and traceable.
- Campaign IDs are kebab-case.
- Campaign `type` is `campaign`.
- Campaign `status` is `running` or `paused`.
- Trigger-specific required fields are present.
- No unknown fields are introduced.

When editing existing config, keep diffs minimal and preserve unrelated campaigns.

## 5) Validate And Hand Off

Run structural checks on each output JSON file:

- `jq . <file>`

When a JSON Schema validator is available, validate against:

- `references/schemas/app-profile.schema.json` for app profiles
- `references/schemas/openclix.schema.json` for config files
- `https://openclix.ai/schemas/openclix.schema.json` as the canonical published config schema URL

Preferred command for config validation:

- `npx --yes ajv-cli validate -s https://openclix.ai/schemas/openclix.schema.json -d <config-file>`

Report at handoff:

- output file paths
- campaign IDs and intent
- key assumptions
- unresolved gaps requiring user input

## 6) Install Config Resource And Wire App Initialization

When the user requests code integration, do not stop at JSON generation.
Install the produced config into the app project and wire runtime loading.

Before editing app code:

- Inspect how the target project already stores JSON resources/assets.
- Follow existing conventions for directory, naming, and startup wiring.
- If Clix client is not integrated yet, run `openclix-init` first.

Integration requirements:

1. Copy final config JSON into a resource location consistent with the app:
   - React Native / Expo: existing `assets/` or project resource pattern.
   - Flutter: asset path already used by the app and declared in `pubspec.yaml`.
   - iOS: bundle resource location already used by the app target.
   - Android: existing `assets/` or `res/raw` pattern used by the app.
2. Keep filename stable unless project convention requires a different name.
3. Update app startup code so Clix is initialized and then receives the local config.
4. Load JSON from the resource file, parse into OpenClix `Config`, then call `ClixCampaignManager.replaceConfig(...)`.
5. Run platform build/analysis checks after wiring.

Optional HTTP publishing workflow (when user requests hosted openclix-config.json):

1. Confirm target hosting environment from the user's dev stack (for example Vercel, Netlify, S3/CloudFront, object storage + CDN, or custom backend API).
2. Explain and provide concrete upload/deploy steps tailored to that environment.
3. Ensure the deployed config is reachable through a stable HTTPS URL.
4. Update initialization wiring to use the HTTPS endpoint in `Clix.initialize(...)`.
5. Keep a local resource fallback only if the user asks for dual-path operation.

Critical runtime note:

- `Clix.initialize(...)` auto-fetches config only for HTTP(S) endpoints.
- For in-app resource JSON, always load and apply config explicitly via `ClixCampaignManager.replaceConfig(...)` after initialization.
- If the user asks for hosted config delivery, prefer HTTPS endpoint wiring and verify the URL is accessible.

Completion requirements for implementation tasks:

- resource file path reported
- modified startup/init file paths reported
- confirmation that local resource config is applied at runtime
- when remote publishing is requested, deployed HTTPS config URL and upload method summary reported

## Design Guardrails

- Do not invent event names that conflict with provided taxonomy.
- Prefer explicit condition rules (`field: "name"` and `field: "property"`) over vague matching.
- Default to `connector: "and"`; use `or` only with explicit rationale.
- Include `weekly_rule.days_of_week` whenever recurrence type is `weekly`.
- Use global quiet-hour controls before introducing ad-hoc per-campaign windows.
- Do not rely on non-HTTP endpoints being auto-loaded by `Clix.initialize(...)`.
- For local JSON delivery, always wire explicit resource load + `ClixCampaignManager.replaceConfig(...)`.
- For remote JSON delivery, serve over HTTPS and keep the payload schema-compatible with `openclix/config/v1`.
- When asked, provide environment-specific upload guidance rather than generic hosting advice.
- Keep integration edits minimal and aligned with existing project structure.

## Resources

- `references/json-schemas.md`: planning + config structures and examples.
- `references/openclix-campaign-playbook.md`: trigger strategy and campaign decomposition.
- `references/schemas/app-profile.schema.json`: app profile schema.
- `references/schemas/openclix.schema.json`: canonical OpenClix schema used by this skill.
