import { Badge } from "@/components/ui/badge";
import { Smartphone, Server, LineChart } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { SectionHeading } from "@/components/shared/section-heading";
import { integrations } from "@/data/integrations";

const iconMap: Record<string, React.ElementType> = {
  Smartphone,
  Server,
  LineChart,
};

export function Integrations() {
  return (
    <section className="section-shell compact">
      <div className="flex flex-col items-start gap-4">
        <span className="eyebrow">Compatibility patterns</span>
        <SectionHeading>Remote Config Adapter Patterns</SectionHeading>
        <p className="lede text-sm md:text-base text-measure">
          Use provider examples as adapter patterns. Keep the rule engine in
          your app while wiring config and events from systems you already use.
        </p>
      </div>

      <div className="mt-10 grid grid-cols-1 md:grid-cols-3 gap-5 w-full">
        {integrations.map((integration) => {
          const Icon = iconMap[integration.icon];
          return (
            <Card
              key={integration.title}
              className="panel hover:border-accent/30 transition-colors"
            >
              <CardContent className="flex flex-col items-start gap-4 p-5">
                <div className="flex w-full items-center justify-between gap-3">
                  <Badge variant="outline" className="bg-background/40 text-[10px]">
                    Pattern
                  </Badge>
                  <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-accent/10">
                    {Icon && <Icon className="h-5 w-5 text-accent" />}
                  </div>
                </div>
                <h3 className="font-heading text-lg font-semibold leading-snug">
                  {integration.title}
                </h3>
                <div className="panel-muted w-full px-3 py-2.5">
                  <p className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                    provider -&gt; adapter -&gt; rules
                  </p>
                </div>
                <p className="text-muted-foreground text-sm leading-relaxed">
                  {integration.description}
                </p>
                <div className="flex flex-wrap gap-2 pt-1">
                  <span className="rounded-full border border-border px-2 py-1 text-[10px] text-muted-foreground">
                    example pattern
                  </span>
                  <span className="rounded-full border border-border px-2 py-1 text-[10px] text-muted-foreground">
                    no lock-in
                  </span>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <div className="mt-6 panel-muted w-full px-4 py-3">
        <p className="text-xs md:text-sm text-muted-foreground">
          These are implementation patterns, not product dependencies. You can
          swap providers without changing the core rule model.
        </p>
      </div>
    </section>
  );
}
