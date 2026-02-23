import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SectionHeading } from "@/components/shared/section-heading";
import { useCases } from "@/data/use-cases";

export function UseCases() {
  return (
    <section className="flex w-full flex-col items-center px-6 py-20 max-w-6xl mx-auto">
      <SectionHeading>What You Can Build</SectionHeading>

      <div className="mt-12 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 w-full">
        {useCases.map((useCase) => (
          <Card
            key={useCase.title}
            className="bg-card border-border hover:border-primary/30 transition-colors"
          >
            <CardHeader>
              <CardTitle className="font-heading text-lg">
                {useCase.title}
              </CardTitle>
            </CardHeader>
            <CardContent>
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
    </section>
  );
}
