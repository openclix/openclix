import { Card, CardContent } from "@/components/ui/card";

export function Mission() {
  return (
    <section className="section-shell glow">
      <div className="rounded-3xl border border-border/80 bg-gradient-to-br from-card via-card to-primary/5 p-1">
        <Card className="w-full border-border/70 bg-background/65 shadow-none">
          <CardContent className="p-8 md:p-14 text-left md:text-center">
            <p className="text-xs uppercase tracking-[0.14em] text-muted-foreground">
              Belief / Mission
            </p>
            <p className="mt-4 font-heading text-3xl md:text-4xl font-bold tracking-tight leading-tight text-balance">
              We believe everyone can now run a great app and solve bigger
              problems.
            </p>

            <p className="mt-6 text-sm md:text-base leading-relaxed text-muted-foreground max-w-2xl mx-auto">
              Great apps should not be gated by infrastructure complexity,
              vendor lock-in, or hidden systems.
            </p>

            <p className="mt-4 text-sm md:text-base leading-relaxed text-muted-foreground max-w-2xl mx-auto">
              OpenClix exists to give builders a practical, open, agent-friendly
              starting point for retention and engagement.
            </p>
          </CardContent>
        </Card>
      </div>
    </section>
  );
}
