export interface UseCase {
  title: string;
  items: string[];
}

export const useCases: UseCase[] = [
  {
    title: "Onboarding Journeys",
    items: [
      'Welcome series with step-by-step nudges',
      '"Finish setup" reminders that auto-cancel when completed',
    ],
  },
  {
    title: "Habit & Routine",
    items: [
      "Daily/weekly reminders at user-chosen times",
      "Streak maintenance, quiet hours, cooldown windows",
    ],
  },
  {
    title: "Re-Engagement (Last-Seen Based)",
    items: [
      "1/3/7-day inactive nudges",
      '"You haven\'t tried X yet" prompts (evaluated on next app run)',
    ],
  },
  {
    title: "In-App Triggered Notifications",
    items: [
      "Immediate follow-ups after key actions",
      '"Next best action" prompts after screen visits or events',
    ],
  },
  {
    title: "Scheduled Promotions",
    items: [
      "Weekend/event reminders you can edit anytime via Remote Config",
      "Deep links to offers, content, or paywalls",
    ],
  },
];
