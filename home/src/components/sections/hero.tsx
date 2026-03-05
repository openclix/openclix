import { Button } from "@/components/ui/button";
import { DOCS_URL, GITHUB_URL } from "@/data/links";

export function Hero() {
  return (
    <section id="hero" className="section-shell glow pt-28 md:pt-36 pb-16">
      <div className="mx-auto flex max-w-4xl flex-col items-center gap-6 text-center">
        <span className="eyebrow hero-animate">
          Open-source local-first engagement
        </span>

        <h1 className="hero-animate hero-animate-delay-1 font-heading text-5xl md:text-7xl font-bold tracking-tighter leading-[1.02]">
          Build retention flows
          <br />
          without the infra maze
        </h1>

        <p className="hero-animate hero-animate-delay-2 lede text-base md:text-lg max-w-2xl text-balance">
          Source-first, config-driven mobile engagement logic that runs
          on-device. Ship quickly with clear ownership.
        </p>

        <div className="hero-animate hero-animate-delay-3 flex flex-wrap items-center justify-center gap-3 pt-2">
          <Button
            size="lg"
            className="font-semibold shadow-[0_0_0_1px_rgba(255,255,255,0.06)_inset]"
            asChild
          >
            <a href={DOCS_URL} target="_blank" rel="noopener noreferrer">
              Read Docs
            </a>
          </Button>
          <Button size="lg" variant="outline" className="font-semibold" asChild>
            <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">
              See GitHub
            </a>
          </Button>
        </div>
      </div>
    </section>
  );
}
