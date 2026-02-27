import { Button } from "@/components/ui/button";
import { DOCS_URL, GITHUB_URL } from "@/data/links";

export function FinalCTA() {
  return (
    <section className="section-shell glow">
      <div className="panel-elevated w-full max-w-4xl p-1.5 mx-auto">
        <div className="rounded-[calc(var(--radius)+0.3rem)] border border-border/70 bg-background/60 p-8 md:p-12 text-center">
          <p className="text-xs uppercase tracking-[0.14em] text-muted-foreground">
            Start shipping this sprint
          </p>
          <p className="mt-3 font-heading text-3xl md:text-4xl font-bold tracking-tight leading-tight text-balance">
          Ship your first on-device engagement flow this sprint.
          </p>

          <p className="mt-4 text-muted-foreground text-sm md:text-base">
            Start with local-first engagement logic you can inspect and evolve.
          </p>

          <div className="mt-8 flex flex-col sm:flex-row items-center justify-center gap-3">
            <Button size="lg" variant="outline" asChild className="font-semibold">
              <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">
                See GitHub
              </a>
            </Button>
            <Button size="lg" asChild className="font-semibold">
              <a href={DOCS_URL} target="_blank" rel="noopener noreferrer">
                Read Docs
              </a>
            </Button>
          </div>

          <div className="mt-5 flex flex-wrap items-center justify-center gap-2 text-xs text-muted-foreground">
            <span className="rounded-full border border-border px-2 py-1">
              copyable architecture
            </span>
            <span className="rounded-full border border-border px-2 py-1">
              openclix-config.json over HTTP
            </span>
            <span className="rounded-full border border-border px-2 py-1">
              on-device execution
            </span>
          </div>
        </div>
      </div>
    </section>
  );
}
