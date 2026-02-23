# OpenClix Home

Landing page for [openclix.ai](https://openclix.ai), built with Next.js (App Router, SSG) and shadcn/ui.

## Tech Stack

- **Framework**: Next.js 16 (App Router, Static Export)
- **UI**: shadcn/ui + Tailwind CSS v4
- **Fonts**: Clash Display (headings), Satoshi (body)
- **Runtime**: Bun

## Development

```bash
bun install
bun run dev
```

Open [http://localhost:3000](http://localhost:3000) to preview.

## Build

```bash
bun run build
```

Static output is generated in the `out/` directory.

## Deployment

Deployed to GitHub Pages via the `deploy-home.yml` workflow. Triggers on:

- Push to `main` branch (including PR merges)
- Manual `workflow_dispatch`
