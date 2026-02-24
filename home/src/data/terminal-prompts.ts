export interface TerminalPromptExample {
  id: string;
  text: string;
  tag?: string;
}

export const terminalPromptExamples: TerminalPromptExample[] = [
  {
    id: "onboarding",
    tag: "Onboarding",
    text: "Use OpenClix to generate an onboarding reminder flow for users who signed up but never finished setup.",
  },
  {
    id: "streak-save",
    tag: "Streak",
    text: "Create a streak-save reminder with dynamic copy based on streak length and last activity.",
  },
  {
    id: "cart-recovery",
    tag: "Cart",
    text: "Draft a cart recovery campaign for shoppers who left items in the cart without checking out.",
  },
  {
    id: "win-back",
    tag: "Win-back",
    text: "Generate a win-back campaign for users inactive for 7 days with quiet hours and cooldowns.",
  },
  {
    id: "milestone",
    tag: "Milestone",
    text: "Create milestone messages that celebrate a first purchase and nudge the next action.",
  },
  {
    id: "experiment",
    tag: "Experiment",
    text: "Set up a remote-config experiment to test reminder timing and suppression rules.",
  },
];
