export interface QuickStartStep {
  step: number;
  title: string;
  description: string;
}

export const quickStartSteps: QuickStartStep[] = [
  {
    step: 1,
    title: "Add the SDK",
    description:
      "Install the OpenClix SDK for iOS or Android and initialize it in your app.",
  },
  {
    step: 2,
    title: "Define flags + config",
    description:
      "JSON values, variants, rollout rules — all managed remotely.",
  },
  {
    step: 3,
    title: "Publish journeys",
    description:
      "Local notification schedules + on-device rules. Updates propagate when the app fetches config (app start, foreground, and best-effort background refresh).",
  },
];
