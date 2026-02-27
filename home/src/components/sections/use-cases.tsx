import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { SectionHeading } from "@/components/shared/section-heading";
import { useCases } from "@/data/use-cases";

const tags = [
  "onboarding",
  "retention",
  "streak",
  "milestone",
  "discovery",
  "agent-ops",
];

export function UseCases() {
  return (
    <section className="section-shell">
      <div className="flex flex-col items-start gap-4">
        <span className="eyebrow">Value made concrete</span>
        <SectionHeading>What You Can Build First</SectionHeading>
      </div>

      <div className="mt-10 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5 w-full">
        {useCases.map((useCase, idx) => (
          <Card
            key={useCase.title}
            className={`hover:border-primary/30 transition-colors ${
              idx === 0 ? "panel-elevated lg:col-span-2" : "panel"
            }`}
          >
            <CardHeader className="px-5 pt-5 pb-3 md:px-6 md:pt-6 md:pb-4">
              <div className="flex items-center justify-between gap-2">
                <Badge variant="outline" className="bg-background/40 text-[10px]">
                  {tags[idx] ?? "use case"}
                </Badge>
                <span className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                  {idx === 0 ? "featured" : "starter"}
                </span>
              </div>
              <CardTitle className="font-heading text-lg md:text-xl">
                {useCase.title}
              </CardTitle>
            </CardHeader>
            <CardContent className="px-5 pb-5 md:px-6 md:pb-6">
              <ul className="space-y-2">
                {useCase.items.map((item, i) => (
                  <li
                    key={i}
                    className="text-muted-foreground text-sm leading-relaxed flex gap-2"
                  >
                    <span className="text-primary mt-0.5 shrink-0">•</span>
                    {item}
                  </li>
                ))}
              </ul>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="mt-6 panel-muted w-full px-4 py-3">
        <p className="text-muted-foreground text-sm">
          Local notifications first, with in-app messaging hooks and
          hosted openclix-config.json tuning.
        </p>
      </div>
    </section>
  );
}
