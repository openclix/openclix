
<p align="center">
<img alt="Event Flyer - dark" src="https://github.com/user-attachments/assets/90bd137c-d7d4-4806-befb-94b45e005718#gh-dark-mode-only">
<img alt="Event Flyer - light" src="https://github.com/user-attachments/assets/be5ab0e3-1d3d-4e17-b13a-67d2622f1a38#gh-light-mode-only">
</p>


# OpenClix

Open-source, agent-friendly foundation for config-driven, on-device mobile engagement logic.

Most teams do not reach retention experiments because they get blocked by push infrastructure setup, SDK integration, and delivery pipeline overhead before they can test user behavior changes.

OpenClix is a practical, local-first foundation for mobile engagement logic that runs on-device. It is designed to be readable, auditable, forkable, and easy for humans and AI agents to extend through explicit interfaces and clear edit points. If you are building apps with your own agent workflows, OpenClix is intended to be a strong reference source for how to structure engagement logic so agents can safely read, modify, and evolve it. Configuration can be shipped as an in-app resource JSON or loaded from an HTTPS endpoint. The client runtime is delivered as source that you bring into your repository, not as a package dependency.

## Installation

OpenClix is currently delivered as agent skills + reference templates.

<details open>
<summary><b>For Humans</b></summary>

**Option A: Let an agent do it**

Paste this into any coding agent (Codex, Claude Code, OpenCode, Cursor, etc.):

```text
Install OpenClix skills from https://github.com/openclix/openclix and integrate OpenClix into this project.
Use openclix-init to detect platform, copy templates into the dedicated OpenClix namespace,
wire initialization/event/lifecycle touchpoints, and run build verification.
Then use openclix-campaign-design to create .clix-campaigns/app-profile.json
and generate .clix-campaigns/openclix-config.json.
Then use openclix-analytics to detect installed Firebase/PostHog/Mixpanel/Amplitude,
forward OpenClix events with openclix tags, and produce a pre/post impact report
for D7 retention and engagement metrics.
Do not add dependencies without approval.
```

**Option B: Manual setup**

1. **Install skills:**

   ```bash
   npx skills add openclix/openclix
   ```

2. **Integrate OpenClix** with `openclix-init`:

   ```text
   Use openclix-init to integrate OpenClix into this project.
   Detect the real platform, copy templates into the dedicated OpenClix namespace,
   wire initialization/event/lifecycle touchpoints, and run build verification.
   Do not add dependencies without approval.
   ```

3. **Design campaign config** with `openclix-campaign-design`:

   ```text
   Use openclix-campaign-design.
   Create or update .clix-campaigns/app-profile.json from my app goals + event taxonomy,
   then generate schema-valid OpenClix config in .clix-campaigns/openclix-config.json.
   Use event/scheduled/recurring triggers with do_not_disturb and frequency_cap.
   ```

4. **Measure campaign impact** with `openclix-analytics`:

   ```text
   Use openclix-analytics.
   Detect installed Firebase/PostHog/Mixpanel/Amplitude in this app.
   If at least one provider is installed, wire OpenClix event forwarding with required openclix tags,
   then generate .clix-analytics/impact-metrics.json and .clix-analytics/impact-report.md
   using pre/post compare defaults (28d pre, 7d stabilization exclusion, 28d post).
   If no provider is installed, explain provider setup options and stop.
   ```

5. **Verify integration:**
   - Run platform-appropriate build/analyze commands
   - Confirm `.clix-campaigns/openclix-config.json` exists and is schema-valid
   - Confirm `.clix-analytics/impact-metrics.json` and `.clix-analytics/impact-report.md` are generated

</details>

<details>
<summary><b>For Agents</b></summary>

### Step-by-Step Instructions

1. Install OpenClix skills with `npx skills add openclix/openclix` (repo: `https://github.com/openclix/openclix`).
2. Run `openclix-init` on the target mobile app codebase.
3. Run `openclix-campaign-design` to produce `.clix-campaigns/openclix-config.json`.
4. Run `openclix-analytics` to detect PA providers, wire event forwarding, and output pre/post impact reports under `.clix-analytics/`.
5. Keep integration minimal and do not add dependencies without approval.

### Verification

- Run platform-appropriate build/analyze commands.
- Confirm OpenClix touchpoints and generated campaign files are present.

</details>

---

### What `openclix-init` does

- Detects platform (Expo/RN/Flutter/iOS/Android) from real project files
- Copies OpenClix local-source templates (shadcn-style)
- Wires minimal integration points only
- Reuses existing dependencies and chooses concrete adapters at integration time
- Verifies with platform-appropriate build/analyze commands

### What `openclix-campaign-design` does

- Builds a structured campaign planning profile
- Designs lifecycle campaigns (onboarding/habit/re-engagement/milestone/feature discovery)
- Produces schema-valid OpenClix config (`openclix/config/v1`)
- Applies guardrails for trigger modeling, cancellation, and message copy

### What `openclix-analytics` does

- Detects installed PA providers (Firebase, PostHog, Mixpanel, Amplitude)
- Selects one provider by fixed priority (Firebase > PostHog > Mixpanel > Amplitude)
- Wires OpenClix app/system event forwarding with standardized `openclix_*` properties
- Produces pre/post impact artifacts focused on `d7_retention` with engagement support metrics
- Stops with provider setup guidance when no supported PA is installed

### Why Source-First Delivery Is a Strength

OpenClix intentionally uses a vendoring model for client code:

- Distributed as source: integration copies generated client files into your repo.
- Not a runtime dependency: your app does not depend on a separate OpenClix package at runtime.
- Lower dependency risk: avoids adding another transitive dependency chain that can cause version conflicts or fragile build graphs.
- Easier ownership: once integrated, the code is yours to inspect, modify, and evolve with your product constraints.

This is a deliberate alternative to SDK-package integration: install the skill, vendor the source, and keep full control in-repo.

### Runtime Model

OpenClix follows a local-first execution path:

```text
config source (in-app resource JSON or HTTPS JSON) -> app event -> rule evaluation -> schedule/show message -> debug reason
```

This lets teams ship onboarding and re-engagement flows without requiring push tokens, FCM/APNS send infrastructure, or a hosted control plane for the local-first path.

### Config Delivery Options

OpenClix config JSON can be delivered in either way:

- App resource: bundle JSON with the app package.
- HTTPS endpoint: fetch JSON over HTTP(S).

For HTTPS delivery, both patterns are valid:

- Static asset JSON (for example, CDN/object-storage hosted file).
- Dynamically generated JSON (for example, API/server response built at request time).

## Project Status

| Area | Status | Notes |
| --- | --- | --- |
| Core project spec / direction | Defined | Scope, use cases, and architecture direction are documented. |
| Reference SDK / engine implementation | In progress | The main OSS implementation is the focus of the next phase. |
| Config JSON runtime model | Planned (Phase 1) | Start with config JSON from app resources or HTTPS before adding provider-specific adapters. |
| Remote config adapters | Optional next phase | Remote config is intended as an extension, not a requirement. |
| Hosted control plane | Not required | Local-first path does not require a Clix-hosted control plane. |

## Why OpenClix Exists

Builders often hit the same early retention blocker: remote push stacks come with certs, servers, tokens, and delivery infrastructure before you can validate whether a reminder or nudge even improves outcomes.

OpenClix is meant to remove that blocker so teams can start with a low-friction path:

1. Copy the reference implementation
2. Connect a config source (in-app JSON or HTTPS JSON) and event hooks
3. Define triggers and rules
4. Ship local engagement flows

## What OpenClix Is (and Is Not)

OpenClix is:

- An open-source reference project for mobile engagement logic
- A local-first foundation for notifications and in-app messaging hooks
- A source-distributed integration model (vendored, checked-in client code)
- Adapter-friendly architecture for config and analytics providers
- An agent-friendly codebase shape with explicit edit points and legible structure

OpenClix is not:

- A full hosted engagement platform
- A mandatory package-level runtime dependency
- A requirement to stand up APNS/FCM delivery infrastructure first for local-first flows
- A requirement to use remote config from day one
- A requirement to use a Clix-hosted control plane or proprietary backend

## Why It Is Agent-Friendly

OpenClix is designed so teams using their own agents to build apps can treat it as a reference project, not a black box SDK.

- Legible structure: clear boundaries and edit points make agent-generated changes easier to review
- Explicit interfaces and schemas: behavior is easier to extend without hidden coupling
- Auditable logic: retention and messaging rules live in plain code/config rather than opaque vendor systems
- Safe iteration loops: teams can diff, test, and refine agent-assisted changes in a fork they control

## Core Capabilities

Target capabilities (reference vision / planned direction):

- Local notifications and in-app messaging hooks
- Config-driven behavior running on-device (in-app JSON or HTTPS JSON)
- Readable rule engine with explicit eligibility and suppression reasons
- Optional adapter patterns for remote config and analytics providers
- Forkable and auditable architecture
- Clear edit points for AI-agent-assisted iteration

## Configuration Model (Local-First, Remote Optional)

OpenClix is planned to ship in phases:

1. Phase 1: Config JSON in app resources or from HTTPS (defaults, rules, templates, suppression settings)
2. Phase 2: Optional adapter wiring to integrate broader remote config providers without changing core execution
3. Phase 3: Additional adapters/integrations as needed

This keeps the core rule engine and scheduling behavior stable while letting teams adopt provider-specific remote config integrations only when they need them.

## Use Cases

- Onboarding Nudges: Guide setup completion and first-session progress without building push backend infrastructure first.
- Re-Engagement Reminders: Trigger nudges after inactivity windows using local rules and tune timing/copy via config updates.
- Streak Maintenance: Keep habits alive with quiet hours, cooldowns, and simple deterministic eligibility checks.
- Milestone Messages: Celebrate progress thresholds and test variants through config updates.
- Feature Discovery Prompts: Surface next-best actions after key events or screen visits using local notifications and in-app hooks.

## Conceptual Flow

```text
config JSON (in-app resource or HTTPS endpoint) -> app event -> rule evaluation -> schedule/show message -> debug reason
```

Observability goals:

- What event happened
- What rule matched
- Why a message fired (or was suppressed)

## Implementation Focus (Current Phase)

This repository is intended to become the main open-source OpenClix project. The core SDK / reference engine implementation is not fully published here yet, so this README focuses on the intended architecture and product direction.

The near-term implementation focus is:

- Config JSON-driven rule model and scheduling runtime (in-app or HTTPS)
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

### Do I install OpenClix as an SDK package dependency?

No. The primary model is source-first integration through skills: OpenClix client code is generated/copied into your repository, checked in, and owned by your team.

### Do I need a backend or push infrastructure?

No for the local-first path. OpenClix focuses on on-device execution, so you can start without an APNS/FCM send pipeline.

### Do I need remote config from the beginning?

No. You can start with config JSON bundled as an app resource, or serve the same JSON over HTTPS (static asset or dynamically generated response).

### Do I need Clix-hosted services or a control plane?

No. The project is intended to run in your app with your own integrations, using adapter patterns for config and events.

### Can I use this with Firebase, PostHog, or Supabase?

Yes, that is the intended adapter-pattern direction described in the landing page content.

### When is OpenClix enough vs when do I need a full engagement platform?

OpenClix is a strong fit for local-first onboarding, habit, re-engagement, and feature discovery flows. If you need complex vendor tooling or server-triggered, real-time push operations, pair it with a full engagement stack.

## Links

- Website: https://openclix.ai
- GitHub: https://github.com/openclix/openclix
- Docs (placeholder): https://docs.openclix.ai

## Contributing

Contribution guidelines are not published yet. For now, use issues and pull requests to propose improvements to the project and docs direction.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
