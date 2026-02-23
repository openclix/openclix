export interface FAQItem {
  question: string;
  answer: string;
}

export const faqItems: FAQItem[] = [
  {
    question: "Can OpenClix replace Braze or OneSignal?",
    answer:
      "For scheduled/on-device journeys (onboarding, habits, last-seen re-engagement, in-app triggers): yes, partially. For server-triggered real-time push (payments, chat, security alerts, time-sensitive ops): no—use APNs/FCM push for that.",
  },
  {
    question: "Will notifications work if the app hasn't been opened in a long time?",
    answer:
      'Only if they were scheduled ahead of time on the device. OpenClix does not "wake" devices like push.',
  },
  {
    question:
      "Can I change copy, links, targeting, and timing without shipping an app update?",
    answer:
      "Yes—via Remote Config. Changes apply after the next config refresh.",
  },
  {
    question: "Do you support A/B tests?",
    answer:
      "OpenClix supports on-device variants and bucketing and can emit exposure events to your analytics.",
  },
];
