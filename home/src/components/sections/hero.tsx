import Image from "next/image";
import { Button } from "@/components/ui/button";
import { DOCS_URL, GITHUB_URL } from "@/data/links";

const proofBullets = [
  "Local notifications + in-app messaging hooks",
  "Vendored source in your repo",
  "Readable rules and explicit reasons",
];

export function Hero() {
  return (
    <section className="section-shell glow pt-8 md:pt-14">
      <div className="flex flex-col items-center gap-5 text-center max-w-4xl mx-auto">
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

        <p className="lede text-base md:text-lg text-measure">
          Copy source-distributed, config-driven mobile engagement logic into
          your repo. No runtime package dependency and no push delivery
          pipeline to stand up first.
        </p>

        <div className="flex flex-wrap items-center justify-center gap-3 pt-1">
          <Button size="lg" variant="outline" className="font-semibold" asChild>
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

        <ul className="grid w-full max-w-3xl grid-cols-1 md:grid-cols-3 gap-2.5 pt-2 text-left">
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
      </div>
    </section>
  );
}
