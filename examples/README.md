# OpenClix Examples

This directory contains repo-local OpenClix example scenarios designed for both humans and AI agents.

## What This Directory Is / Is Not

This directory is:

- A scenario-first example library for local-first OpenClix campaign patterns
- A place for shared config files plus platform-specific code snippets
- A lightweight reference for integration ideas and conventions

This directory is not:

- A set of fully working sample apps
- A replacement for API/reference documentation
- A place for Mintlify website docs content

## Shared Config Across Platforms

Each scenario includes exactly one canonical config file at:

- `examples/scenarios/<scenario-slug>/openclix.config.json`

That file is shared by iOS, Android, Flutter, and React Native snippets in the same scenario. Platform snippets should demonstrate loading/parsing/integration differences only and must not fork or duplicate the full config JSON.

## Scenario Catalog

`examples/catalog.json` is the machine-readable source of truth for scenario discovery.

| Scenario | Status | Shared Config | Platforms | Notes |
| --- | --- | --- | --- | --- |
| `_example-template` | `template` | `yes` | iOS, Android, Flutter, React Native | Structural template for future scenarios |
| `activation-first-value-rescue` | `ready` | `yes` | iOS, Android, Flutter, React Native | Chained delivery-based escalation, cancellation on success, jitter, dedupe |
| `streak-protection-escalation` | `ready` | `yes` | iOS, Android, Flutter, React Native | Payload-filtered entry, urgency windows, spacing limits, drop vs defer behavior |
| `interrupted-flow-recovery` | `ready` | `yes` | iOS, Android, Flutter, React Native | Branching follow-ups (`opened` vs `delivered`), deep links/actions, message-state suppression |

These scenarios are intentionally designed to showcase OpenClix orchestration features (cancellation, chaining, filtering, limits, and explainability), not just static delayed reminders.

## How To Use Snippets Safely

- Treat snippets as copy/adapt references, not drop-in production code
- Read the scenario `README.md` first for event assumptions and placement guidance
- Keep your app's permission flow, scheduling limits, and runtime stores aligned with your architecture
- Use the shared scenario config as the canonical behavior definition

## Validation Notes

- Config schema path: `schemas/openclix-campaign-config.schema.json`
- Each scenario config (`openclix.config.json`) should validate against the schema above
- `examples/catalog.json` and `scenario.meta.json` are intended to be machine-readable and stable for tooling

## Contribution And Editing Conventions

- Add new examples under `examples/scenarios/<scenario-slug>/`
- Keep one canonical `openclix.config.json` per scenario
- Update both `examples/catalog.json` and the scenario's `scenario.meta.json`
- Follow the section order in `examples/templates/scenario.README.template.md`
- Keep snippets focused on one behavior per file (schedule, cancel, ingest, foreground-eval)
