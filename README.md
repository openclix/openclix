
<p align="center">
<img alt="Event Flyer - dark" src="https://github.com/user-attachments/assets/90bd137c-d7d4-4806-befb-94b45e005718#gh-dark-mode-only">
<img alt="Event Flyer - light" src="https://github.com/user-attachments/assets/be5ab0e3-1d3d-4e17-b13a-67d2622f1a38#gh-light-mode-only">
</p>


# OpenClix

Open-source, agent-friendly foundation for config-driven, on-device mobile engagement logic.

Most teams do not reach retention experiments because they get blocked by push infrastructure setup, SDK integration, and delivery pipeline overhead before they can test user behavior changes.

OpenClix is a practical, local-first foundation for mobile engagement logic that runs on-device. It is designed to be readable, auditable, forkable, and easy for humans and AI agents to extend through explicit interfaces and clear edit points. If you are building apps with your own agent workflows, OpenClix is intended to be a strong reference source for how to structure engagement logic so agents can safely read, modify, and evolve it. Configuration starts from local files first, with remote config adapters planned as an optional later phase.

## Project Status

| Area | Status | Notes |
| --- | --- | --- |
| Core project spec / direction | Defined | Scope, use cases, and architecture direction are documented. |
| Reference SDK / engine implementation | In progress | The main OSS implementation is the focus of the next phase. |
| Local config-first runtime model | Planned (Phase 1) | Start with local config files in-app before adding remote config adapters. |
| Remote config adapters | Optional next phase | Remote config is intended as an extension, not a requirement. |
| Hosted control plane | Not required | Local-first path does not require a Clix-hosted control plane. |

## Why OpenClix Exists

Builders often hit the same early retention blocker: remote push stacks come with certs, servers, tokens, and delivery infrastructure before you can validate whether a reminder or nudge even improves outcomes.

OpenClix is meant to remove that blocker so teams can start with a low-friction path:

1. Copy the reference implementation
2. Connect local config (then optional remote config later) and event hooks
3. Define triggers and rules
4. Ship local engagement flows

## What OpenClix Is (and Is Not)

OpenClix is:

- An open-source reference project for mobile engagement logic
- A local-first foundation for notifications and in-app messaging hooks
- Adapter-friendly architecture for config and analytics providers
- An agent-friendly codebase shape with explicit edit points and legible structure

OpenClix is not:

- A full hosted engagement platform
- A requirement to stand up APNS/FCM delivery infrastructure first for local-first flows
- A requirement to use remote config from day one
- A requirement to use a Clix-hosted control plane or proprietary backend

## Why It Is Agent-Friendly

OpenClix is designed so teams using their own agents to build apps can treat it as a reference project, not a black box SDK.

- Legible structure: clear boundaries and edit points make agent-generated changes easier to review
- Explicit interfaces and schemas: behavior is easier to extend without hidden coupling
- Repo-local contracts: canonical JSON schemas live in `schemas/` (separate from website docs content)
- Auditable logic: retention and messaging rules live in plain code/config rather than opaque vendor systems
- Safe iteration loops: teams can diff, test, and refine agent-assisted changes in a fork they control

## Core Capabilities

Target capabilities (reference vision / planned direction):

- Local notifications and in-app messaging hooks
- Config-driven behavior running on-device (local config first)
- Readable rule engine with explicit eligibility and suppression reasons
- Optional adapter patterns for remote config and analytics providers
- Forkable and auditable architecture
- Clear edit points for AI-agent-assisted iteration

## Configuration Model (Local-First, Remote Optional)

OpenClix is planned to ship in phases:

1. Phase 1: Local config file in the app (defaults, rules, templates, suppression settings)
2. Phase 2: Optional remote config wiring to update the same rule model without changing core execution
3. Phase 3: Additional adapters/integrations as needed

This keeps the core rule engine and scheduling behavior stable while letting teams adopt remote config only when they need it.

## Examples (Shared Config + Cross-Platform Snippets)

The repo includes a scenario-first examples library under `examples/` with:

- One canonical OpenClix config file per scenario
- Platform-specific snippets for iOS, Android, Flutter, and React Native
- Machine-readable example metadata for AI-agent discovery (`examples/catalog.json`)

This directory is separate from Mintlify docs and is intended for lightweight integration references, not full sample apps.

## Use Cases

- Onboarding Nudges: Guide setup completion and first-session progress without building push backend infrastructure first.
- Re-Engagement Reminders: Trigger nudges after inactivity windows using local rules and tune timing/copy via config updates.
- Streak Maintenance: Keep habits alive with quiet hours, cooldowns, and simple deterministic eligibility checks.
- Milestone Messages: Celebrate progress thresholds and test variants through config updates.
- Feature Discovery Prompts: Surface next-best actions after key events or screen visits using local notifications and in-app hooks.

## Conceptual Flow

```text
local config file (optional remote config later) -> app event -> rule evaluation -> schedule/show message -> debug reason
```

Observability goals:

- What event happened
- What rule matched
- Why a message fired (or was suppressed)

## Implementation Focus (Current Phase)

This repository is intended to become the main open-source OpenClix project. The core SDK / reference engine implementation is not fully published here yet, so this README focuses on the intended architecture and product direction.

The near-term implementation focus is:

- Local config-first rule model and scheduling runtime
- On-device eligibility/suppression evaluation
- Debuggable execution traces and reason outputs
- Stable interfaces that can later be wired to remote config providers

## Integration Direction (Adapter Patterns)

These are planned adapter-pattern directions (not required for the first implementation phase):

- Firebase Remote Config: Use as a config input source while keeping rule evaluation and scheduling in-app.
- PostHog: Map flags and events into OpenClix hooks without coupling rule models to provider-specific APIs.
- Supabase: Use your own tables/endpoints as a config source while preserving the same local execution path.

## Who This Project Is For

- Indie builders: Launch onboarding nudges, streak reminders, and re-engagement flows quickly.
- Product teams: Run retention experiments before committing to a full engagement platform.
- Agencies: Reuse a proven engagement foundation across client apps with predictable handoff.
- Agent-first builders: Use OpenClix as a reference source for agent-built apps, with structures agents can read, modify, and extend more safely.

## FAQ

### Is this a notification library or a full platform?

OpenClix is positioned as an open-source reference codebase for on-device engagement logic (local notifications and in-app messaging hooks), not a hosted full engagement platform.

### Do I need a backend or push infrastructure?

No for the local-first path. OpenClix focuses on on-device execution, so you can start without an APNS/FCM send pipeline.

### Do I need remote config from the beginning?

No. The intended rollout is local config first, with optional remote config wiring in a later phase.

### Do I need Clix-hosted services or a control plane?

No. The project is intended to run in your app with your own integrations, using adapter patterns for config and events.

### Can I use this with Firebase, PostHog, or Supabase?

Yes, that is the intended adapter-pattern direction described in the landing page content.

### When is OpenClix enough vs when do I need a full engagement platform?

OpenClix is a strong fit for local-first onboarding, habit, re-engagement, and feature discovery flows. If you need complex vendor tooling or server-triggered, real-time push operations, pair it with a full engagement stack.

## Links

- Website: https://openclix.ai
- GitHub: https://github.com/clix-so/openclix
- Docs (placeholder): https://docs.openclix.ai

## Contributing

Contribution guidelines are not published yet. For now, use issues and pull requests to propose improvements to the project and docs direction.

## License

License file not yet added to the repository.
