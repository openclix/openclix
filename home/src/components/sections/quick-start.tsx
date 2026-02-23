import { Card, CardContent } from "@/components/ui/card";
import { SectionHeading } from "@/components/shared/section-heading";
import { quickStartSteps } from "@/data/quick-start";

export function QuickStart() {
  return (
    <section className="flex w-full flex-col items-center px-6 py-20 max-w-4xl mx-auto">
      <SectionHeading>Quick Start</SectionHeading>

      <div className="mt-12 flex flex-col gap-6 w-full">
        {quickStartSteps.map((step) => (
          <Card
            key={step.step}
            className="bg-card border-border"
          >
            <CardContent className="flex items-start gap-6 p-6">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 border border-primary/20">
                <span className="font-heading text-lg font-bold text-primary">
                  {step.step}
                </span>
              </div>
              <div className="flex flex-col gap-1">
                <h3 className="font-heading text-lg font-semibold">
                  {step.title}
                </h3>
                <p className="text-muted-foreground text-sm leading-relaxed">
                  {step.description}
                </p>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      <p className="mt-8 text-muted-foreground text-sm text-center max-w-xl">
        Updates propagate when the app fetches config (app start, foreground, and
        best-effort background refresh).
      </p>
    </section>
  );
}
