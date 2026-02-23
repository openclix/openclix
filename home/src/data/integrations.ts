export interface Integration {
  category: string;
  title: string;
  description: string;
  icon: string;
}

export const integrations: Integration[] = [
  {
    category: "platform",
    title: "iOS + Android",
    description:
      "Native SDKs with an on-device evaluation engine.",
    icon: "Smartphone",
  },
  {
    category: "backend",
    title: "Any Backend",
    description:
      "Fetch Remote Config from OpenClix Cloud or your own endpoint.",
    icon: "Server",
  },
  {
    category: "analytics",
    title: "Any Analytics",
    description:
      "PostHog, Segment, Amplitude, Mixpanel—or your own collector (via event hooks).",
    icon: "LineChart",
  },
];
