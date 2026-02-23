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
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { SectionHeading } from "@/components/shared/section-heading";
import { features } from "@/data/features";
import { GITHUB_URL } from "@/data/links";

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
    <section className="section-shell">
      <div className="grid gap-8 lg:grid-cols-[0.85fr_1.15fr] items-start">
        <div className="flex flex-col items-start gap-4">
          <span className="eyebrow">Developer trust</span>
          <SectionHeading>Technical Trust</SectionHeading>
          <div className="rounded-full border border-primary/20 bg-primary/8 px-3 py-1 text-xs text-primary">
            Developer-facing architecture
          </div>
          <p className="lede text-sm md:text-base text-measure">
            OpenClix is designed for teams that want clear execution paths,
            testable modules, and integration points they can own.
          </p>
          <Button size="lg" variant="outline" className="font-semibold mt-1" asChild>
            <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">
              See GitHub
            </a>
          </Button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 w-full">
          {features.map((feature, idx) => {
          const Icon = iconMap[feature.icon];
          return (
            <Card
              key={feature.title}
              className={`hover:border-primary/30 transition-colors ${
                idx % 5 === 0 ? "panel-elevated" : "panel"
              }`}
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
      </div>
    </section>
  );
}
