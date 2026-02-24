"use client";

import { useEffect, useState } from "react";
import { SectionHeading } from "@/components/shared/section-heading";
import { terminalPromptExamples } from "@/data/terminal-prompts";

type AnimationPhase = "typing" | "pause";

const TYPE_SPEED_MS = 32;
const HOLD_SPEED_MS = 2600;

export function PromptTerminalSection() {
  const [promptIndex, setPromptIndex] = useState(0);
  const [displayedText, setDisplayedText] = useState("");
  const [phase, setPhase] = useState<AnimationPhase>("typing");
  const [isPaused, setIsPaused] = useState(false);
  const [reducedMotion, setReducedMotion] = useState(false);

  const currentPrompt = terminalPromptExamples[promptIndex] ?? terminalPromptExamples[0];
  const activePromptIndex = reducedMotion ? 0 : promptIndex;
  const activePrompt =
    terminalPromptExamples[activePromptIndex] ?? terminalPromptExamples[0];
  const visibleText = reducedMotion
    ? terminalPromptExamples[0]?.text ?? ""
    : displayedText;

  useEffect(() => {
    const mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

    const updatePreference = () => {
      setReducedMotion(mediaQuery.matches);
    };

    updatePreference();
    mediaQuery.addEventListener("change", updatePreference);

    return () => {
      mediaQuery.removeEventListener("change", updatePreference);
    };
  }, []);

  useEffect(() => {
    if (reducedMotion || isPaused || !currentPrompt) {
      return;
    }

    let timeoutMs = TYPE_SPEED_MS;
    let nextStep = () => {};

    if (phase === "typing") {
      if (displayedText.length < currentPrompt.text.length) {
        timeoutMs = TYPE_SPEED_MS;
        nextStep = () => {
          setDisplayedText(currentPrompt.text.slice(0, displayedText.length + 1));
        };
      } else {
        timeoutMs = HOLD_SPEED_MS;
        nextStep = () => {
          setPhase("pause");
        };
      }
    }

    if (phase === "pause") {
      timeoutMs = HOLD_SPEED_MS;
      nextStep = () => {
        setPromptIndex((prev) => (prev + 1) % terminalPromptExamples.length);
        setDisplayedText("");
        setPhase("typing");
      };
    }

    const timer = window.setTimeout(nextStep, timeoutMs);

    return () => {
      window.clearTimeout(timer);
    };
  }, [currentPrompt, displayedText, phase, reducedMotion, isPaused]);

  return (
    <section className="section-shell compact">
      <div className="flex flex-col items-start gap-4">
        <span className="eyebrow">Promptable retention workflows</span>
        <SectionHeading>Ask for the campaign you need</SectionHeading>
        <p className="lede text-sm md:text-base text-measure">
          OpenClix is built for practical campaign prompts: onboarding nudges,
          streak saves, win-back flows, and remote-config experiments.
        </p>
      </div>

      <div
        className="panel-elevated mt-8 w-full overflow-hidden focus-visible:ring-2 focus-visible:ring-primary/50 focus-visible:ring-offset-0"
        role="group"
        aria-label="Animated examples of OpenClix campaign prompts"
        tabIndex={0}
        onMouseEnter={() => setIsPaused(true)}
        onMouseLeave={() => setIsPaused(false)}
        onFocus={() => setIsPaused(true)}
        onBlur={(event) => {
          if (
            !event.currentTarget.contains(event.relatedTarget as Node | null)
          ) {
            setIsPaused(false);
          }
        }}
      >
        <div className="relative">
          <div className="flex items-center justify-between gap-3 border-b border-white/8 bg-black/20 px-4 py-3 md:px-5">
            <div className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full bg-[#ff5f57]" />
              <span className="h-2.5 w-2.5 rounded-full bg-[#febc2e]" />
              <span className="h-2.5 w-2.5 rounded-full bg-[#28c840]" />
            </div>
            <div className="text-[11px] tracking-[0.14em] uppercase text-muted-foreground">
              openclix@local: ~
            </div>
            <div className="hidden md:flex items-center gap-2">
                <span className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                {activePrompt?.tag ?? "Prompt"}
              </span>
              <span className="h-1.5 w-1.5 rounded-full bg-primary/80" />
            </div>
          </div>

          <div
            aria-hidden="true"
            className="pointer-events-none absolute inset-0 opacity-20"
            style={{
              backgroundImage:
                "repeating-linear-gradient(to bottom, rgba(255,255,255,0.06) 0px, rgba(255,255,255,0.06) 1px, transparent 1px, transparent 4px)",
            }}
          />

          <div className="relative px-4 py-5 md:px-5 md:py-6">
            <div className="mb-4 flex flex-wrap items-center gap-2 text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
              {terminalPromptExamples.map((prompt, index) => (
                <span
                  key={prompt.id}
                  className={`rounded-full border px-2.5 py-1 transition-colors ${
                    activePromptIndex === index
                      ? "border-primary/35 bg-primary/10 text-primary"
                      : "border-white/10 bg-white/2"
                  }`}
                >
                  {prompt.tag}
                </span>
              ))}
            </div>

            <div className="rounded-xl border border-white/8 bg-black/25 p-3 md:p-4">
              <div className="flex flex-wrap items-start gap-x-2 gap-y-1 font-mono text-sm leading-6 md:text-[15px] md:leading-7">
                <span className="shrink-0 text-primary">➜ ~/openclix</span>
                <span className="shrink-0 text-muted-foreground">$</span>
                <span className="min-w-0 text-foreground/95 break-words" aria-hidden="true">
                  {visibleText}
                  <span className="terminal-caret" />
                </span>
              </div>
              <p className="sr-only">
                Examples include onboarding reminders, streak-save campaigns,
                cart recovery, win-back flows, milestone messages, and remote
                config experiments.
              </p>
            </div>

            <p className="mt-4 text-xs leading-relaxed text-muted-foreground md:text-sm">
              Hover or focus this terminal to pause the animation and read a
              prompt.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
