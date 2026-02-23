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
    <section className="flex w-full flex-col items-center px-6 py-20 max-w-4xl mx-auto">
      <SectionHeading>Works With Everything</SectionHeading>

      <div className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-6 w-full">
        {integrations.map((integration) => {
          const Icon = iconMap[integration.icon];
          return (
            <Card
              key={integration.title}
              className="bg-card border-border hover:border-accent/30 transition-colors text-center"
            >
              <CardContent className="flex flex-col items-center gap-3 p-6">
                <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-accent/10">
                  {Icon && <Icon className="h-6 w-6 text-accent" />}
                </div>
                <h3 className="font-heading text-lg font-semibold">
                  {integration.title}
                </h3>
                <p className="text-muted-foreground text-sm leading-relaxed">
                  {integration.description}
                </p>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </section>
  );
}
