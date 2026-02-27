# AGENT.md

## Scope and Intent
This repository is an OpenClix reference project (local-first, agent-friendly), not a finished hosted platform.

Work usually falls into one of these areas:

1. `home/`: Next.js marketing site for `openclix.ai`.
2. `skills/openclix-init/`: mobile integration templates and skill guidance.

Keep changes tightly scoped to the user's requested area.

## Source of Truth
- Product direction and current phase: `README.md`
- Website implementation: `home/src/**`
- Integration workflow rules: `skills/openclix-init/SKILL.md`
- Template source: `skills/openclix-init/templates/**`
- Schema reference: `skills/openclix-init/references/openclix.schema.json`
- For template behavior/contract changes, treat `templates/react-native/**` and `references/openclix.schema.json` as the canonical baseline.
- Template verification gate: `scripts/verify_templates.sh`
- Deployment pipeline: `.github/workflows/deploy-home.yml`

Ignore generated artifacts unless debugging build outputs:
- `home/.next/**`
- `home/out/**`
- `home/node_modules/**`

## Task Routing
- Landing page copy/UI/SEO changes: edit only `home/src/**` (and `home/public/**` if asset changes are required).
- OpenClix runtime/template behavior: edit `skills/openclix-init/templates/**`.
- Config model/schema changes: update schema + all affected platform templates together.
- Project spec changes: update `README.md` and corresponding docs in `home/**` and `docs/**` within the same change set.
- CI/CD/deploy behavior: edit `.github/workflows/**`.

## Command Reference
Run commands in the correct directory.
For JavaScript/TypeScript tasks in this repo, prefer Bun (`bun run`, `bun x`, `bun install`) over Node.js package managers/runners unless a task explicitly requires otherwise.

### Website (`home/`)
- `bun install`
- `bun run dev`
- `bun run lint`
- `bun run build`

For any `home/` code change, `bun run build` should pass.
`next.config.ts` uses `output: "export"`; avoid server-only features that break static export.

### Templates (repo root)
- `./scripts/verify_templates.sh react-native`
- `./scripts/verify_templates.sh android`
- `./scripts/verify_templates.sh ios`
- `./scripts/verify_templates.sh flutter`
- `./scripts/verify_templates.sh all`

Run at least changed-platform verification. Run `all` when shared logic/tokens are touched.

## Template Guardrails (Must Keep)
When editing `skills/openclix-init/templates/**`:

- No in-memory fallback implementations as production defaults.
- Keep event naming aligned to `event_tracked` (do not reintroduce ingest naming).
- Preserve flat campaign state keys: `campaign_states`, `queued_messages`, `trigger_history`, `updated_at`.
- Preserve trigger/settings tokens: `scheduled`, `recurring`, `cancel_event`, `do_not_disturb`, `frequency_cap`.
- In React Native templates, keep optional dependency references isolated to `infrastructure/` (not `core/` or `engine/`).
- Maintain cross-platform parity; if uncertain, align with `templates/react-native/` as canonical behavior reference.
- Roll out template contract updates in sequence: React Native first, verify RN, then propagate equivalent updates to Android/iOS/Flutter.

## Dependency and Change Policy
- Prefer existing dependencies and platform APIs.
- Do not add/upgrade dependencies unless explicitly requested.
- Keep diffs minimal; avoid broad refactors outside the requested scope.

## Completion Checklist
Before handoff:

1. List changed files with intent.
2. Run relevant checks and report pass/fail.
3. Explicitly state checks not run.
4. Call out static-export risks (`home`) or cross-platform parity risks (`templates`) if present.
