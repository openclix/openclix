import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SectionHeading } from "@/components/shared/section-heading";
import { audienceOutcomes } from "@/data/audience-outcomes";
import { DOCS_URL } from "@/data/links";

export function AudienceOutcomes() {
  return (
    <section className="section-shell compact">
      <div className="flex flex-col items-start gap-4">
        <span className="eyebrow">Audience outcomes</span>
        <SectionHeading>Built for How Teams Ship</SectionHeading>
      </div>

      <div className="mt-10 grid grid-cols-1 md:grid-cols-2 gap-5 w-full">
        {audienceOutcomes.map((block, idx) => (
          <Card key={block.audience} className="bg-card border-border">
            <CardHeader
              className={`pb-2 ${idx === 0 ? "md:pb-3" : ""} ${
                idx === 0 ? "md:min-h-24" : ""
              }`}
            >
              <p className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground mb-2">
                persona {idx + 1}
              </p>
              <CardTitle className="font-heading text-lg leading-snug">
                {block.audience}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4 pt-0">
              <p className="text-sm leading-relaxed text-muted-foreground text-balance">
                {block.outcome}
              </p>
              <div className="flex items-center justify-between gap-3 border-t border-border/70 pt-3">
                <span className="text-xs text-muted-foreground">
                  Start with a local-first baseline
                </span>
                <Button size="sm" variant="outline" asChild className="font-semibold">
                  <a href={DOCS_URL} target="_blank" rel="noopener noreferrer">
                    Read Docs
                  </a>
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </section>
  );
}
