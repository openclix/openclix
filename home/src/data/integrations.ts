export interface Integration {
  category: string;
  title: string;
  description: string;
  icon: string;
}

export const integrations: Integration[] = [
  {
    category: "platform",
    title: "Firebase Adapter Pattern",
    description:
      "Use Firebase Remote Config as an input source while keeping rule evaluation and scheduling inside your app.",
    icon: "Smartphone",
  },
  {
    category: "backend",
    title: "PostHog Adapter Pattern",
    description:
      "Map flags and events into OpenClix hooks without coupling your rule model to PostHog-specific APIs.",
    icon: "Server",
  },
  {
    category: "analytics",
    title: "Supabase Adapter Pattern",
    description:
      "Use your own tables and endpoints as a config source with the same local rule execution path.",
    icon: "LineChart",
  },
];
