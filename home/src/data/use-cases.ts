export interface UseCase {
  title: string;
  items: string[];
}

export const useCases: UseCase[] = [
  {
    title: "Onboarding Nudges",
    items: [
      "Guide first-session progress with lightweight nudges tied to milestones.",
      "Encourage setup completion without building a push backend first.",
    ],
  },
  {
    title: "Re-Engagement Reminders",
    items: [
      "Trigger nudges after inactivity windows using local rules and last-seen signals.",
      "Tune copy, timing, and suppression logic by updating hosted openclix-config.json.",
    ],
  },
  {
    title: "Streak Maintenance",
    items: [
      "Keep routines alive with quiet hours, cooldowns, and simple eligibility checks.",
      "Make reminder behavior deterministic and easy to audit.",
    ],
  },
  {
    title: "Milestone Messages",
    items: [
      "Celebrate completions, streaks, and progress thresholds with local messaging.",
      "Use config updates to test different message variants quickly.",
    ],
  },
  {
    title: "Feature Discovery Prompts",
    items: [
      "Surface next-best actions after key events or screen visits.",
      "Pair local notifications with in-app hooks and deep links.",
    ],
  },
];
