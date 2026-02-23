import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Cpu, Feather, GitBranch } from "lucide-react";
import { SectionHeading } from "@/components/shared/section-heading";
import { pillars } from "@/data/pillars";

const pillarIcons = [GitBranch, Feather, Cpu];

export function Pillars() {
  return (
    <section className="section-shell">
      <div className="flex flex-col items-start gap-4">
        <span className="eyebrow">Differentiation</span>
        <SectionHeading>Core Pillars</SectionHeading>
      </div>

      <div className="mt-12 grid grid-cols-1 lg:grid-cols-3 gap-6 w-full">
        {pillars.map((pillar, idx) => {
          const Icon = pillarIcons[idx];
          const variantClass =
            idx === 1
              ? "panel-elevated"
              : idx === 2
                ? "panel border-primary/15 bg-gradient-to-br from-primary/5 via-card to-card"
                : "panel";
          return (
          <Card key={pillar.title} className={variantClass}>
            <CardHeader className="px-5 pt-5 pb-3 md:px-6 md:pt-6 md:pb-4">
              <div className="flex items-center justify-between gap-3">
                <p className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                  pillar {idx + 1}
                </p>
                {Icon && (
                  <div className="flex h-9 w-9 items-center justify-center rounded-lg border border-border/80 bg-background/50">
                    <Icon className="h-4 w-4 text-primary" />
                  </div>
                )}
              </div>
              <CardTitle className="font-heading text-xl leading-tight">
                {pillar.title}
              </CardTitle>
            </CardHeader>
            <CardContent className="px-5 pb-5 md:px-6 md:pb-6">
              <ul className="space-y-2.5">
                {pillar.points.map((point) => (
                  <li
                    key={point}
                    className="grid grid-cols-[0.375rem_1fr] items-start gap-x-2.5 text-sm leading-relaxed text-muted-foreground"
                  >
                    <span className="mt-[0.45rem] h-1.5 w-1.5 rounded-full bg-primary" />
                    <span>{point}</span>
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        )})}
      </div>
    </section>
  );
}
