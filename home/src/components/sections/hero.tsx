import Image from "next/image";
import { Button } from "@/components/ui/button";
import { DOCS_URL, GITHUB_URL } from "@/data/links";

const proofBullets = [
  "No SDK, No Servers",
  "Dynamic Remote Config",
  "Agent-First, Low Manual Ops",
];

export function Hero() {
  return (
    <section className="section-shell glow pt-8 md:pt-14">
      <div className="mx-auto flex max-w-4xl flex-col items-center gap-6 text-center md:gap-7">
        <span className="eyebrow">Open-source mobile engagement reference</span>

        <div className="mascot-icon cursor-pointer mb-1">
          <Image
            src="/images/mascot.png"
            alt="OpenClix mascot"
            width={220}
            height={146}
            className="mascot-image"
            priority
          />
        </div>

        <h1 className="font-heading text-5xl md:text-7xl font-bold tracking-tight leading-none">
          OpenClix
        </h1>

        <p className="font-heading text-3xl md:text-[3.15rem] font-semibold tracking-tight leading-[1.02] text-balance max-w-4xl">
          Open-source retention tooling your team and users will love.
        </p>

        <ul className="grid w-full max-w-3xl grid-cols-1 gap-2.5 pt-2 text-left md:grid-cols-3">
          {proofBullets.map((bullet) => (
            <li
              key={bullet}
              className="panel-muted flex items-center gap-2.5 px-3.5 py-2.5 text-sm"
            >
              <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
              <span className="text-muted-foreground leading-relaxed">{bullet}</span>
            </li>
          ))}
        </ul>

        <div className="flex flex-wrap items-center justify-center gap-3 pt-2">
          <Button
            size="lg"
            variant="outline"
            className="font-semibold text-foreground hover:text-foreground hover:bg-accent/35"
            asChild
          >
            <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">
              See GitHub
            </a>
          </Button>
          <Button
            size="lg"
            className="font-semibold shadow-[0_0_0_1px_rgba(255,255,255,0.06)_inset]"
            asChild
          >
            <a href={DOCS_URL} target="_blank" rel="noopener noreferrer">
              Read Docs
            </a>
          </Button>
        </div>

      </div>
    </section>
  );
}
