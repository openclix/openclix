import {
  Settings,
  Target,
  BarChart3,
  Bell,
  Route,
  Link,
  Webhook,
  Shield,
} from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { SectionHeading } from "@/components/shared/section-heading";
import { features } from "@/data/features";

const iconMap: Record<string, React.ElementType> = {
  Settings,
  Target,
  BarChart3,
  Bell,
  Route,
  Link,
  Webhook,
  Shield,
};

export function Features() {
  return (
    <section className="flex w-full flex-col items-center px-6 py-20 max-w-6xl mx-auto">
      <SectionHeading>What It Does</SectionHeading>

      <div className="mt-12 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 w-full">
        {features.map((feature) => {
          const Icon = iconMap[feature.icon];
          return (
            <Card
              key={feature.title}
              className="bg-card border-border hover:border-primary/30 transition-colors"
            >
              <CardContent className="flex flex-col gap-3 p-6">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10">
                  {Icon && <Icon className="h-5 w-5 text-primary" />}
                </div>
                <h3 className="font-heading text-base font-semibold">
                  {feature.title}
                </h3>
                <p className="text-muted-foreground text-sm leading-relaxed">
                  {feature.description}
                </p>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </section>
  );
}
