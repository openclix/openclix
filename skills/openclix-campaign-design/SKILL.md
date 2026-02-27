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
5. Validate artifact outputs.
6. Inspect existing Clix integration and choose delivery mode.
7. Execute selected delivery path and hand off.

Repository hygiene rule:

- Before writing outputs under `.clix/**`, ensure `.clix/` is listed in `.gitignore` (add it if missing).

## 1) Collect Campaign Context

Gather only missing facts needed for design decisions:

- app name and platform(s)
- primary retention goals (onboarding, habit, re-engagement, milestone, feature discovery)
- event taxonomy: event names + available property keys
- current campaign config path (if existing)
- existing app resource/file management convention for JSON assets
- startup location where Clix is currently initialized (or should be initialized)
- user-owned HTTP server/deployment target for hosted config (if remote serving is expected)
- global constraints: quiet hours, frequency cap expectations, locale/timezone assumptions

If the user already provided enough detail, do not re-ask resolved points.

## 2) Build Or Refresh App Profile Artifact

Before authoring campaigns:

- Read `references/json-schemas.md`.
- Read `references/schemas/app-profile.schema.json`.
- Create or update `.clix/campaigns/app-profile.json`.
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
2. Otherwise write `.clix/campaigns/openclix-config.json`.

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

## 5) Validate Artifact Outputs

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

## 6) Inspect Existing Clix Integration And Choose Delivery Mode

After generating config JSON, inspect existing Clix integration code before delivery decisions.

Inspection checklist:

- Locate `Clix.initialize(...)` call sites and current `ClixConfig.endpoint` usage.
- Locate any existing `ClixCampaignManager.replaceConfig(...)` usage.
- Confirm project resource conventions used by current startup wiring.
- If Clix client integration is missing, run `openclix-init` first and use its detected platform/startup/resource conventions.

Decision gate (mandatory unless user already specified mode):

- Ask the user which delivery mode to use:
  1. Bundle config in the app package.
  2. Upload to the user's existing HTTP server and serve over HTTPS.
- Do not assume delivery mode when the user has not chosen one.

## 7) Execute Selected Delivery Path And Hand Off

### A) Bundle In-App (Local Resource Delivery)

When the user chooses bundle mode:

1. Use platform/startup/resource information discovered from existing code and `openclix-init` outputs.
2. Copy `.clix/campaigns/openclix-config.json` into the app resource location used by that project:
   - React Native / Expo: existing `assets/` or project resource pattern.
   - Flutter: existing asset path and `pubspec.yaml` convention.
   - iOS: existing app target bundle resource location.
   - Android: existing `assets/` or `res/raw` pattern.
3. Keep filename stable unless project convention requires a different name.
4. Set `ClixConfig.endpoint` to the bundled config path identifier used by the project.
5. Update startup code to load JSON from that same bundled path, parse `Config`, then call `ClixCampaignManager.replaceConfig(...)` after initialization.
6. Run platform build/analysis checks after wiring.

### B) Hosted HTTP Delivery (User-Owned Server)

When the user chooses HTTP mode:

1. Confirm user-owned hosting target and deploy access method (for example Vercel, Netlify, S3/CloudFront, object storage + CDN, or custom backend API).
2. Upload/deploy `.clix/campaigns/openclix-config.json` to that environment.
3. Verify the deployed config is reachable at a stable HTTPS URL.
4. Set `ClixConfig.endpoint` to the deployed HTTPS URL.
5. Keep local bundled fallback only if the user explicitly requests dual-path operation.
6. Run platform build/analysis checks after wiring.

Critical runtime note:

- `Clix.initialize(...)` auto-fetches config only for HTTP(S) endpoints.
- For in-app resource JSON, always load and apply config explicitly via `ClixCampaignManager.replaceConfig(...)` after initialization.
- For hosted delivery, always use HTTPS and verify the URL is accessible.

Completion requirements for implementation tasks:

- selected delivery mode reported
- source config path and applied runtime config path/URL reported
- `ClixConfig.endpoint` value/location updated and reported
- resource file path reported for bundle mode
- modified startup/init file paths reported
- confirmation that local resource config is applied at runtime
- for hosted mode, deployed HTTPS config URL and upload method summary reported

## Design Guardrails

- Do not invent event names that conflict with provided taxonomy.
- Prefer explicit condition rules (`field: "name"` and `field: "property"`) over vague matching.
- Default to `connector: "and"`; use `or` only with explicit rationale.
- Include `weekly_rule.days_of_week` whenever recurrence type is `weekly`.
- Use global quiet-hour controls before introducing ad-hoc per-campaign windows.
- After config generation, inspect existing Clix wiring and ask the user to choose bundle vs hosted delivery if not already specified.
- Reuse project facts discovered by `openclix-init` when selecting resource path and startup patch points.
- Do not rely on non-HTTP endpoints being auto-loaded by `Clix.initialize(...)`.
- For local JSON delivery, always set `ClixConfig.endpoint` to the chosen bundled path and wire explicit resource load + `ClixCampaignManager.replaceConfig(...)`.
- For remote JSON delivery, set `ClixConfig.endpoint` to HTTPS URL and keep the payload schema-compatible with `openclix/config/v1`.
- When asked, provide environment-specific upload guidance rather than generic hosting advice.
- Keep integration edits minimal and aligned with existing project structure.

## Resources

- `references/json-schemas.md`: planning + config structures and examples.
- `references/openclix-campaign-playbook.md`: trigger strategy and campaign decomposition.
- `references/schemas/app-profile.schema.json`: app profile schema.
- `references/schemas/openclix.schema.json`: canonical OpenClix schema used by this skill.
