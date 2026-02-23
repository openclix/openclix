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
      "No backend or APNS/FCM send pipeline is required for the local-first path. OpenClix focuses on on-device execution with remote-config-driven behavior.",
  },
  {
    question: "Do I need Clix-hosted services or a control plane?",
    answer:
      "No. OpenClix is intended to run in your app with your own integrations. You can use adapter patterns for config and events without relying on a hosted Clix control surface.",
  },
  {
    question: "Can I use this with Firebase/PostHog/Supabase remote config?",
    answer:
      "Yes. The landing page and repo position these as adapter patterns. You can map OpenClix to those tools while keeping the core behavior app-controlled and auditable.",
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
];
