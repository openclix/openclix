export interface Feature {
  icon: string;
  title: string;
  description: string;
}

export const features: Feature[] = [
  {
    icon: "Settings",
    title: "Transparent Rule Engine",
    description:
      "Inspect how eligibility, suppression, and scheduling decisions are made.",
  },
  {
    icon: "Target",
    title: "Explicit Interfaces & Schemas",
    description:
      "Legible boundaries make the behavior easier to extend and safer for agents to edit.",
  },
  {
    icon: "BarChart3",
    title: "Testable Modules",
    description:
      "Separate logic and adapters so you can test core behavior without app-specific glue.",
  },
  {
    icon: "Bell",
    title: "Local-First Execution",
    description:
      "Run retention messaging on-device with remote config controlling behavior.",
  },
  {
    icon: "Route",
    title: "Debug Eligibility Reasons",
    description:
      "Track what matched, what was suppressed, and why a message did or did not fire.",
  },
  {
    icon: "Link",
    title: "Adapter Patterns",
    description:
      "Connect config and analytics providers through adapters you can swap later.",
  },
  {
    icon: "Webhook",
    title: "Clear Edit Points for AI Agents",
    description:
      "Readable structure, examples, and explicit touchpoints for AI-assisted iteration loops.",
  },
  {
    icon: "Copy",
    title: "Source-First Integration",
    description:
      "Client runtime is copied into your repo as checked-in source, not as a runtime package dependency.",
  },
  {
    icon: "Shield",
    title: "Forkable and Auditable",
    description:
      "Change what you need, review diffs in plain code, and keep product control in-house.",
  },
];
