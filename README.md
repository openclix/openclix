<p align="center">
<img alt="Event Flyer - dark" src="https://github.com/user-attachments/assets/90bd137c-d7d4-4806-befb-94b45e005718#gh-dark-mode-only">
<img alt="Event Flyer - light" src="https://github.com/user-attachments/assets/be5ab0e3-1d3d-4e17-b13a-67d2622f1a38#gh-light-mode-only">
</p>

<div align="center"><strong>OpenClix</strong></div>
<div align="center">Open-source, local-first foundation for config-driven mobile engagement logic.</div>
<br />
<div align="center">
<a href="https://openclix.ai">Website</a>
<span> · </span>
<a href="./docs">Docs</a>
<span> · </span>
<a href="https://github.com/openclix/openclix">GitHub</a>
</div>

## Introduction

OpenClix helps teams run onboarding, habit, re-engagement, and feature-discovery messaging with local-first execution.

It is designed to be:

- Open source and auditable
- Source-first (vendored client code, not runtime SDK lock-in)
- Agent-friendly (explicit interfaces and clear edit points)

## Installation

OpenClix is delivered as skills + source templates.

<details open>
<summary><b>For Humans</b></summary>

### Option A: Let an agent do it

Paste this prompt into your coding agent:

```text
Install OpenClix skills from https://github.com/openclix/openclix and integrate OpenClix into this project.
Use openclix-init to detect platform, copy templates into the dedicated OpenClix namespace,
wire initialization/event/lifecycle touchpoints, and run build verification.
Then use openclix-design-campaigns to create .clix/campaigns/app-profile.json
and generate .clix/campaigns/openclix-config.json.
Then use openclix-analytics to detect installed Firebase/PostHog/Mixpanel/Amplitude,
forward OpenClix events with openclix tags, and produce a pre/post impact report
for D7 retention and engagement metrics.
Then use openclix-update-campaigns to propose pause/resume/add/delete/update
actions from campaign metrics and produce openclix-config.next.json before
applying any change to the active config.
Do not add dependencies without approval.
```

### Option B: Manual setup

Follow the full guide: [Install and integrate OpenClix](./docs/getting-started/installation.mdx)

</details>

<details>
<summary><b>For Agents</b></summary>

1. Install skills:

```bash
npx skills add openclix/openclix
```

2. Run `openclix-init` to integrate templates and touchpoints.
3. Run `openclix-design-campaigns` to generate `.clix/campaigns/openclix-config.json`.
4. Run `openclix-analytics` to detect provider wiring and generate impact artifacts.
5. Run `openclix-update-campaigns` to produce conservative recommendation drafts.

</details>

## Documentation

| Topic                | Link                                                                             |
| -------------------- | -------------------------------------------------------------------------------- |
| Installation         | [Install and integrate OpenClix](./docs/getting-started/installation.mdx)        |
| Workflow             | [Run the OpenClix workflow](./docs/getting-started/workflow.mdx)                 |
| Verification         | [Verify your integration](./docs/getting-started/verification.mdx)               |
| Retention automation | [Agent retention automation guide](./docs/guides/agent-retention-automation.mdx) |
| Config delivery      | [Config delivery guide](./docs/guides/config-delivery.mdx)                       |
| Campaign design      | [Campaign design guide](./docs/guides/campaign-design.mdx)                       |
| Analytics impact     | [Analytics impact guide](./docs/guides/analytics-impact.mdx)                     |
| Runtime model        | [Runtime model reference](./docs/reference/runtime-model.mdx)                    |
| Use cases            | [Use cases reference](./docs/reference/use-cases.mdx)                            |
| FAQ                  | [FAQ](./docs/reference/faq.mdx)                                                  |
| Project status       | [Project status](./docs/reference/project-status.mdx)                            |

## What OpenClix Is Not

- Not a hosted full engagement platform
- Not a required runtime package dependency
- Not dependent on a Clix-hosted control plane for local-first flows

## Contributing

Use issues and pull requests to propose improvements to the project and documentation.

## License

MIT License. See [LICENSE](LICENSE).
