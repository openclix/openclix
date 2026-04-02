---
name: openclix-update
description: Sync OpenClix source-integration code with the latest openclix-init template baseline using dry-run planning and explicit overwrite controls. TRIGGER when the user asks to "update OpenClix", "sync templates", "refresh integration code", or when the openclix-init template baseline has changed and source files need re-sync. DO NOT trigger for campaign config updates — that belongs to openclix-update-campaigns. This skill updates integration source code, not campaign configurations.
---

# OpenClix Update

## Purpose

`openclix-update` keeps an existing OpenClix integration aligned with the latest `openclix-init` template output.
It does **not** propose campaign operations; that remains the responsibility of `openclix-update-campaigns`.

## Scope

1. Detect OpenClix integration and platform context.
2. Generate a sync plan that highlights drift, safe marker-based merge candidates, and conflict files.
3. Apply updates only after explicit confirmation.
4. Produce a human-readable and machine-readable report for review.

## Hard Rules

- Default to preview mode.
  - Do not modify target files unless `--apply` is used.
- Preserve existing `.openclix/**` files unless the generated update path is explicitly selected.
- Require backup before overwrite:
  - existing target files are backed up to `.openclix/openclix-update/backups/<timestamp>/`.
- Do not auto-apply conflict files.
  - Conflict entries (`status: "conflict"`) require `--force` when running `apply_sync.sh --apply`.
- Fail-safe on unknown template/platform combinations.
- Do not mix campaign-update workflows in this skill.
- Prefer marker-based merges when both markers exist in the target file:
  - `OPENCLIX_MANAGED_START`
  - `OPENCLIX_MANAGED_END`
- Do not auto-remove or rewrite user-managed sections outside managed markers.

## Template / Schema Policy

- Baseline source-of-truth is `skills/openclix-init/templates/*`.
- Schema/reference changes are handled through `skills/openclix-init/references/openclix.schema.json`.
- When template files change in the plugin, re-run:
  - `bash skills/openclix-update/scripts/detect_integration.sh --root <target-project-root>`
  - `bash skills/openclix-update/scripts/plan_sync.sh --root <target-project-root>`
  - `bash skills/openclix-update/scripts/apply_sync.sh --root <target-project-root> --plan <plan-file> --apply`

## Core Workflow

### 1) Detect integration

```bash
bash skills/openclix-update/scripts/detect_integration.sh --root <target-project-root>
```

### 2) Build sync plan

```bash
bash skills/openclix-update/scripts/plan_sync.sh \
  --root <target-project-root> \
  [--platform react-native|flutter|ios|android] \
  [--target-root <platform-root>] \
  [--plan <openclix-update-plan.json>]
```

Outputs:

- `.openclix/openclix-update/openclix-update-plan.json`
- Conflicts are listed in `conflicts` for explicit review.

### 3) Apply when approved

```bash
bash skills/openclix-update/scripts/apply_sync.sh \
  --root <target-project-root> \
  --plan <plan-file> \
  --apply \
  [--force]
```

Outputs:

- `.openclix/openclix-update/openclix-update-apply.json`

### 4) Build report

```bash
bash skills/openclix-update/scripts/report.sh \
  --plan <plan-file> \
  [--apply <apply-file>] \
  [--output <report.md-file>] \
  [--json <report-json-file>]
```

Outputs:

- `openclix-update-report.md`
- `openclix-update-report.json`

## Inputs

- `--root` target project root that already contains an OpenClix integration

## Outputs

- `openclix-update-plan.json`
- `openclix-update-apply.json`
- `openclix-update-report.md`
- `openclix-update-report.json`

## Exit behavior

- `0` success when script completed and wrote output.
- `1` validation or execution failure.
- `2` blocked by conflicts during non-force apply.
