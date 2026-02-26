export interface QuickStartStep {
  step: number;
  title: string;
  description: string;
}

export const quickStartSteps: QuickStartStep[] = [
  {
    step: 1,
    title: "Vendor source into your repo",
    description:
      "Bring OpenClix client code in-repo as checked-in source so you can inspect and own every integration detail.",
  },
  {
    step: 2,
    title: "Connect config JSON + event hooks",
    description:
      "Wire app-resource or HTTPS JSON config with app events so rules react without backend plumbing.",
  },
  {
    step: 3,
    title: "Trigger rules and ship local engagement flows",
    description:
      "Run local notifications and in-app messaging logic on-device with debuggable reasons and safe edit points.",
  },
];
