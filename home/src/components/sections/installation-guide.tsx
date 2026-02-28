"use client";

import { useState } from "react";
import { Copy, BookOpenText, Check } from "lucide-react";
import { SectionHeading } from "@/components/shared/section-heading";
import { Button } from "@/components/ui/button";
import { DOCS_URL } from "@/data/links";

const agentPrompt = `Install OpenClix skills from https://github.com/openclix/openclix and integrate OpenClix into this project.
Use openclix-init to detect platform, copy templates into the dedicated OpenClix namespace,
wire initialization/event/lifecycle touchpoints, and run build verification.
Then use openclix-design-campaigns to create .clix/campaigns/app-profile.json
and generate .clix/campaigns/openclix-config.json.
Then use openclix-analytics to detect installed Firebase/PostHog/Mixpanel/Amplitude,
forward OpenClix events with openclix tags, and produce a pre/post impact report
for D7 retention and engagement metrics.
Then use openclix-update-campaigns to propose pause/resume/add/delete/update
actions from campaign metrics and produce openclix-config.next.json before
applying any change to the active config.
Do not add dependencies without approval.`;
const agentPromptPreview = `Install OpenClix skills from https://github.com/openclix/openclix and integrate OpenClix into this project.
Use openclix-init to detect platform, copy templates into the dedicated OpenClix namespace,
wire initialization/event/lifecycle touchpoints, and run build verification.`;
const agentPromptRemaining = `Then use openclix-design-campaigns to create .clix/campaigns/app-profile.json
and generate .clix/campaigns/openclix-config.json.
Then use openclix-analytics to detect installed Firebase/PostHog/Mixpanel/Amplitude,
forward OpenClix events with openclix tags, and produce a pre/post impact report
for D7 retention and engagement metrics.
Then use openclix-update-campaigns to propose pause/resume/add/delete/update
actions from campaign metrics and produce openclix-config.next.json before
applying any change to the active config.
Do not add dependencies without approval.`;

const manualSkillsCommand = "npx skills add openclix/openclix";

export function InstallationGuide() {
  const [copiedTarget, setCopiedTarget] = useState<"agent" | "manual" | null>(null);
  const [showRemainingPrompt, setShowRemainingPrompt] = useState(false);

  const handleCopy = async (value: string, target: "agent" | "manual") => {
    try {
      await navigator.clipboard.writeText(value);
      setCopiedTarget(target);
      window.setTimeout(() => setCopiedTarget(null), 1500);
    } catch {
      setCopiedTarget(null);
    }
  };

  return (
    <section className="section-shell compact pt-3 md:pt-5">
      <div className="panel-elevated w-full p-5 md:p-7">
        <div className="flex flex-col gap-6">
          <div>
            <span className="eyebrow">Install OpenClix</span>
            <SectionHeading>Get Started with Agent.</SectionHeading>
          </div>

          <div className="grid gap-4 lg:grid-cols-2">
            <div className="panel-muted px-4 py-4 md:px-5 md:py-5">
              <p className="text-xs uppercase tracking-[0.13em] text-primary">Option 1</p>
              <p className="text-sm text-muted-foreground">
                Copy and paste the prompt
              </p>
              <p className="mt-2 font-heading text-xl leading-tight">
                Agent prompt install
              </p>
              <div className="mt-4 overflow-hidden rounded-xl border border-white/10 bg-black/35">
                <div className="flex items-center justify-between gap-3 border-b border-white/10 px-3 py-2">
                  <p className="text-xs text-muted-foreground">
                    Copy the PROMPT below and run it in your agent.
                  </p>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="h-8 gap-1.5 px-2 text-xs"
                    onClick={() => handleCopy(agentPrompt, "agent")}
                    aria-label="Copy prompt text"
                  >
                    {copiedTarget === "agent" ? (
                      <>
                        <Check className="h-3.5 w-3.5" />
                        Copied
                      </>
                    ) : (
                      <>
                        <Copy className="h-3.5 w-3.5" />
                        Copy
                      </>
                    )}
                  </Button>
                </div>
                <div className="p-4 font-mono text-xs text-foreground md:text-sm">
                  <pre className="m-0 overflow-x-auto whitespace-pre-wrap">{agentPromptPreview}</pre>
                  {showRemainingPrompt ? (
                    <pre className="mt-2 m-0 overflow-x-auto whitespace-pre-wrap">
                      {agentPromptRemaining}
                    </pre>
                  ) : (
                    <button
                      type="button"
                      onClick={() => setShowRemainingPrompt(true)}
                      className="mt-2 cursor-pointer text-xs text-muted-foreground hover:text-foreground transition-colors"
                    >
                      Show remaining lines
                    </button>
                  )}
                </div>
              </div>
            </div>

            <div className="panel-muted px-4 py-4 md:px-5 md:py-5">
              <p className="text-xs uppercase tracking-[0.13em] text-primary">Option 2</p>
              <p className="text-sm text-muted-foreground">
                Manually add the skills using npx
              </p>
              <p className="mt-2 font-heading text-xl leading-tight">
                Step-by-step (README format)
              </p>
              <ol className="mt-4 space-y-2 text-sm text-muted-foreground">
                <li>1. Install skills with the command below.</li>
                <li>2. Run <code>openclix-init</code> to integrate templates and touchpoints.</li>
                <li>3. Run <code>openclix-design-campaigns</code> to generate campaigns.</li>
                <li>4. Run <code>openclix-analytics</code> to generate impact artifacts.</li>
                <li>5. Run <code>openclix-update-campaigns</code> for recommendation drafts.</li>
              </ol>
              <div className="mt-4 overflow-hidden rounded-xl border border-white/10 bg-black/25">
                <div className="flex items-center justify-between gap-3 border-b border-white/10 px-3 py-2">
                  <p className="text-xs text-muted-foreground">Run this first in terminal.</p>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="h-8 gap-1.5 px-2 text-xs"
                    onClick={() => handleCopy(manualSkillsCommand, "manual")}
                    aria-label="Copy manual install command"
                  >
                    {copiedTarget === "manual" ? (
                      <>
                        <Check className="h-3.5 w-3.5" />
                        Copied
                      </>
                    ) : (
                      <>
                        <Copy className="h-3.5 w-3.5" />
                        Copy
                      </>
                    )}
                  </Button>
                </div>
                <pre className="overflow-x-auto p-3 text-xs text-foreground md:text-sm">
                  <code>{manualSkillsCommand}</code>
                </pre>
              </div>
              <Button className="mt-5 w-full font-semibold" asChild>
                <a href={DOCS_URL} target="_blank" rel="noopener noreferrer">
                  <BookOpenText className="mr-2 h-4 w-4" />
                  Open Install and Integrate Guide
                </a>
              </Button>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
