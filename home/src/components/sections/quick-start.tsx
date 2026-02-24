import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { SectionHeading } from "@/components/shared/section-heading";
import { quickStartSteps } from "@/data/quick-start";

export function QuickStart() {
  return (
    <section className="section-shell">
      <div className="flex flex-col items-start gap-4">
        <span className="eyebrow">Low adoption anxiety</span>
        <SectionHeading>How It Works</SectionHeading>
        <div className="flex flex-wrap gap-2">
          <Badge variant="outline" className="bg-background/50">
            Fits your app
          </Badge>
          <Badge variant="outline" className="bg-background/50">
            Fast to wire
          </Badge>
          <Badge variant="outline" className="bg-background/50">
            Easy to reason about
          </Badge>
        </div>
      </div>

      <div className="mt-10 grid w-full gap-4 md:grid-cols-3">
        {quickStartSteps.map((step) => (
          <Card
            key={step.step}
            className="panel relative overflow-hidden"
          >
            <CardContent className="flex h-full flex-col gap-4 p-5 md:p-6">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 border border-primary/20">
                  <span className="font-heading text-lg font-bold text-primary">
                    {step.step}
                  </span>
                </div>
                <div className="h-px flex-1 bg-gradient-to-r from-primary/30 to-transparent md:block hidden" />
              </div>
              <div className="flex flex-col gap-2">
                <h3 className="font-heading text-lg font-semibold leading-snug">
                  {step.title}
                </h3>
                <p className="text-muted-foreground text-sm leading-relaxed">
                  {step.description}
                </p>
              </div>
              <div className="mt-auto pt-2">
                <span className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                  Step {step.step}
                </span>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="mt-6 panel-muted w-full px-4 py-3">
        <p className="text-sm text-muted-foreground leading-relaxed">
          Copy the reference implementation, wire it into your existing remote
          config and event hooks, then iterate on rules with clear runtime
          behavior.
        </p>
      </div>
    </section>
  );
}
