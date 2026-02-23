export interface Pillar {
  title: string;
  points: string[];
}

export const pillars: Pillar[] = [
  {
    title: "OSS",
    points: [
      "MIT/permissive mindset",
      "transparent logic",
      "forkable and auditable",
    ],
  },
  {
    title: "No Friction / No Dependencies",
    points: [
      "no backend required",
      "no hosted control plane required",
      "no auth/API key for local-first use",
      "no proprietary SDK lock-in",
    ],
  },
  {
    title: "AI AGENT FRIENDLY",
    points: [
      "legible folder structure",
      "explicit interfaces and schemas",
      "examples, fixtures, and clear edit points",
      "agent-oriented docs/prompts",
    ],
  },
];
