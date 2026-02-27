---
name: openclix-update-campaigns
description: Update OpenClix campaigns from analytics performance by proposing pause/resume/add/delete/update actions per campaign, producing a next config draft, and applying only after user confirmation. Use when users ask to optimize campaign operations from PA metrics or adjust campaign status/rules based on retention and engagement outcomes.
---

# OpenClix Update Campaigns

Operate campaigns from measured outcomes, not intuition.
This skill consumes `openclix-analytics` outputs and generates safe, reviewable campaign updates.

## Purpose

1. Read campaign performance signals from PA metrics.
2. Propose campaign actions per campaign ID.
3. Generate `.clix/campaigns/openclix-config.next.json` without mutating the active config.
4. Apply changes only after user confirmation.
5. Choose update procedure based on detected delivery mode (bundle vs hosted HTTP).

## Hard Rules

- Keep default mode as `propose_then_apply`.
- Never mutate `.clix/campaigns/openclix-config.json` before user confirmation.
- Use campaign-level decisions (`openclix_campaign_id`) with conservative sampling.
- Follow pause-first policy for deletion:
  - no immediate delete from running state
  - delete only when already long-paused and repeatedly underperforming
- Inherit config delivery/runtime constraints from `openclix-design-campaigns`.
- Before writing outputs under `.clix/**`, ensure `.clix/` exists in `.gitignore`.

## Inputs

Required:

- `.clix/analytics/impact-metrics.json`
- `.clix/campaigns/openclix-config.json`

Optional:

- `.clix/analytics/campaign-metrics.json`
- `.clix/campaigns/app-profile.json`
- `.clix/campaigns/update-history.json`

## Outputs

- `.clix/campaigns/update-recommendations.json`
- `.clix/campaigns/openclix-config.next.json`
- `.clix/campaigns/update-history.json`

## Workflow

### 1) Preflight

1. Confirm OpenClix integration exists in the app repository.
2. Confirm required input artifacts are present.
3. Ensure `.clix/` is ignored by git when `.clix/**` outputs are created.

### 2) Detect delivery mode

Run:

```bash
bash skills/openclix-update-campaigns/scripts/detect_delivery_mode.sh --root <target-project-root>
```

Priority:

1. explicit user mode (`--mode`) if provided
2. code-based detection

Returned mode is one of:

- `bundle`
- `hosted_http`
- `dual`
- `unknown`

If mode is `unknown`, stop and ask the user to choose bundle or hosted HTTP.

### 3) Ensure campaign metrics

If `.clix/analytics/campaign-metrics.json` is missing:

1. Generate a stub file with `status: insufficient_data`.
2. Point to provider query recipes for campaign-level extraction.
3. Continue with conservative `no_change` decisions.

### 4) Evaluate campaign actions

Run:

```bash
bash skills/openclix-update-campaigns/scripts/evaluate_campaigns.sh --root <target-project-root>
```

Decision defaults:

- unit: per campaign
- primary metric: global `d7_retention_delta_pp`
- guardrails: campaign `open_rate`, `fail_rate`, `cancel_rate`
- minimum sample: `delivered >= 200` and `opened >= 20`

Action rules are documented in `references/decision-rules.md`.

### 5) Produce recommendation artifacts

The evaluator must output:

- `update-recommendations.json` with action list, reason codes, and proposed patches
- `openclix-config.next.json` with draft changes only
- updated `update-history.json`

### 6) Confirmation gate

Show the recommendation summary and ask for confirmation.
Do not apply to active config until confirmation.

### 7) Apply by delivery mode (after confirmation)

- `bundle`: sync updated source config to bundled runtime resource path and verify local load + `ClixCampaignManager.replaceConfig(...)` path.
- `hosted_http`: publish updated config to user-owned HTTPS host and verify URL health.
- `dual`: update both hosted primary and local fallback paths consistently.

### 8) Validate and hand off

Run platform checks and report:

- selected delivery mode + evidence
- proposed/applied action list
- modified file paths
- verification command results
- any insufficient-data blockers

## Automation handoff

For multi-agent retention review loops, run:

```bash
bash scripts/retention_ops_automation.sh \
  --root <target-project-root> \
  --agent all \
  --delivery-mode auto \
  --dry-run
```

The helper executes delivery mode detection + evaluator orchestration and writes:

- `.clix/automation/run-summary.json`
- `.clix/automation/prompts/openclaw.md`
- `.clix/automation/prompts/claude-code.md`
- `.clix/automation/prompts/codex.md`

Failure codes from helper script:

- `10`: prerequisite command or required script missing
- `20`: no supported PA provider detected
- `21`: OpenClix integration not detected
- `30`: required input artifact missing
- `31`: delivery mode unresolved (`unknown`)
- `40`: evaluator failed

## Resources

- `references/decision-rules.md`
- `references/delivery-mode-detection.md`
- `references/campaign-metrics-contract.md`
- `references/provider-campaign-query-recipes.md`
- `../openclix-design-campaigns/SKILL.md`
- `../openclix-analytics/SKILL.md`
