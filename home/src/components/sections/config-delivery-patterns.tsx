import { Badge } from "@/components/ui/badge";
import { Smartphone, Server, LineChart } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { SectionHeading } from "@/components/shared/section-heading";
import { configDeliveryPatterns } from "@/data/config-delivery-patterns";

const iconMap: Record<string, React.ElementType> = {
  Smartphone,
  Server,
  LineChart,
};

export function ConfigDeliveryPatterns() {
  return (
    <section className="section-shell compact">
      <div className="flex flex-col items-start gap-4">
        <span className="eyebrow">Compatibility patterns</span>
        <SectionHeading>openclix-config.json Delivery Patterns</SectionHeading>
        <p className="lede text-sm md:text-base text-measure">
          Serve openclix-config.json over HTTP as a static file or dynamic API.
          Keep the rule engine in your app while changing campaign settings remotely.
        </p>
      </div>

      <div className="mt-10 grid grid-cols-1 md:grid-cols-3 gap-5 w-full">
        {configDeliveryPatterns.map((pattern) => {
          const Icon = iconMap[pattern.icon];
          return (
            <Card
              key={pattern.title}
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
                  {pattern.title}
                </h3>
                <div className="panel-muted w-full px-3 py-2.5">
                  <p className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                    http -&gt; openclix-config.json -&gt; rules
                  </p>
                </div>
                <p className="text-muted-foreground text-sm leading-relaxed">
                  {pattern.description}
                </p>
                <div className="flex flex-wrap gap-2 pt-1">
                  <span className="rounded-full border border-border px-2 py-1 text-[10px] text-muted-foreground">
                    static or dynamic
                  </span>
                  <span className="rounded-full border border-border px-2 py-1 text-[10px] text-muted-foreground">
                    no app redeploy
                  </span>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <div className="mt-6 panel-muted w-full px-4 py-3">
        <p className="text-xs md:text-sm text-muted-foreground">
          These are delivery patterns, not product dependencies. Update a static
          JSON file or API response to change campaigns without a new app release.
        </p>
      </div>
    </section>
  );
}
