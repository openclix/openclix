export interface QuickStartStep {
  step: number;
  title: string;
  description: string;
}

export const quickStartSteps: QuickStartStep[] = [
  {
    step: 1,
    title: "Copy the reference implementation",
    description:
      "Start from the OSS codebase and bring the parts you need into your app with clear, forkable logic.",
  },
  {
    step: 2,
    title: "Connect remote config + event hooks",
    description:
      "Wire your config source and app events so engagement rules can react without backend plumbing.",
  },
  {
    step: 3,
    title: "Trigger rules and ship local engagement flows",
    description:
      "Run local notifications and in-app messaging logic on-device with debuggable reasons and safe edit points.",
  },
];
