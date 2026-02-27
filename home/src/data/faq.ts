export interface FAQItem {
  question: string;
  answer: string;
}

export const faqItems: FAQItem[] = [
  {
    question: "Is this a notification library or a full platform?",
    answer:
      "OpenClix is an open-source reference codebase for on-device engagement logic (local notifications and in-app messaging hooks), not a hosted full engagement platform.",
  },
  {
    question: "Do I need a backend or push infrastructure?",
    answer:
      "No backend or APNS/FCM send pipeline is required for the local-first path. OpenClix focuses on on-device execution with openclix-config.json-driven behavior.",
  },
  {
    question: "Do I install OpenClix as a package dependency?",
    answer:
      "No. OpenClix is source-distributed: the client code is copied into your repository and checked in, so you avoid extra runtime dependency chain risk and keep full ownership of the code.",
  },
  {
    question: "Do I need Clix-hosted services or a control plane?",
    answer:
      "No. OpenClix is intended to run in your app with your own integrations. You can start bundled, then host openclix-config.json over HTTP when you need remote updates.",
  },
  {
    question: "How can I deliver openclix-config.json?",
    answer:
      "Serve openclix-config.json over HTTP as either a static file or a dynamic API response. Updating that JSON source lets you change campaign settings without shipping a new app build.",
  },
  {
    question: "Can AI agents actually modify this safely?",
    answer:
      "That is a core design goal. OpenClix emphasizes legible structure, explicit interfaces, and clear edit points so AI-assisted changes are easier to review and validate.",
  },
  {
    question:
      "When is OpenClix enough vs when do I need a full engagement platform?",
    answer:
      "OpenClix is a strong fit for local-first onboarding, habit, re-engagement, and feature discovery flows. If you need complex vendor tooling or server-triggered, real-time push operations, pair it with a full engagement stack.",
  },
  {
    question: "How should I use OpenClaw safely in retention operations?",
    answer:
      "Treat third-party OpenClaw skills/plugins as untrusted by default. Review source before execution, prefer sandboxed runs, and keep a strict human approval gate before applying config changes.",
  },
];
