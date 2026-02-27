# OpenClix Docs (Mintlify)

This directory contains the Mintlify docs site for OpenClix.

## Local development

```bash
cd docs
bun install
bun run dev
```

## Validation

```bash
bun run validate
bun run broken-links
```

## Notes

- Config file uses latest Mintlify format: `docs.json`.
- CLI command uses `mint` (not legacy `mintlify` command).
- Mint CLI is pinned to `4.2.390` in `package.json` (latest checked on 2026-02-27).
