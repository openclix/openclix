export interface Feature {
  icon: string;
  title: string;
  description: string;
}

export const features: Feature[] = [
  {
    icon: "Settings",
    title: "Remote Config, Not Just Flags",
    description:
      "Typed values, JSON payloads, versioning, defaults, and safe fallbacks.",
  },
  {
    icon: "Target",
    title: "Targeting & Segments (On-Device)",
    description:
      "Evaluate rules locally using device/user attributes you choose to provide.",
  },
  {
    icon: "BarChart3",
    title: "Gradual Rollouts & Variants",
    description:
      "Percentage rollouts, A/B-style variants, and deterministic bucketing.",
  },
  {
    icon: "Bell",
    title: "Local Notification Campaigns",
    description:
      "Schedule notifications with templates, quiet hours, and per-campaign frequency caps.",
  },
  {
    icon: "Route",
    title: "On-Device Journey Engine",
    description:
      "Stateful flows with delays, conditions, and auto-cancel when goals are met.",
  },
  {
    icon: "Link",
    title: "Deep Links & Personalization",
    description:
      "Route users to the right screen with parameterized deep links and message templates.",
  },
  {
    icon: "Webhook",
    title: "Event Hooks (Bring Your Own Analytics)",
    description:
      "Export exposure + notification events to your analytics stack via HTTP.",
  },
  {
    icon: "Shield",
    title: "Privacy-First by Design",
    description: "No push tokens required. Most decisions happen locally.",
  },
];
