import { Card, CardContent } from "@/components/ui/card";
import { SectionHeading } from "@/components/shared/section-heading";

export function WhyOpenClix() {
  return (
    <section className="section-shell">
      <div className="grid w-full items-start gap-8 lg:grid-cols-[0.95fr_1.05fr]">
        <div className="flex flex-col gap-4">
          <span className="eyebrow">Problem framing</span>
          <SectionHeading>Why OpenClix Exists</SectionHeading>
          <p className="lede text-base md:text-lg text-measure">
            Most builders never reach retention experiments because they get
            blocked by push infrastructure, SDK integration, and setup overhead.
          </p>
          <p className="text-sm md:text-base text-muted-foreground leading-relaxed text-measure">
            OpenClix removes the blocker so teams can test behavior change
            first. Instead of adding another package into an already complex
            dependency graph, teams can vendor checked-in source and keep full
            ownership in-repo.
          </p>
        </div>

        <div className="space-y-4">
          <Card className="panel-muted border-red-400/10 bg-gradient-to-br from-red-500/6 via-transparent to-transparent">
            <CardContent className="p-5 md:p-6">
              <p className="text-xs font-semibold tracking-[0.12em] uppercase text-red-200/75">
                Remote push stack
              </p>
              <div className="mt-3 flex flex-wrap gap-2">
                {["certs", "servers", "tokens", "delivery infra"].map((chip) => (
                  <span
                    key={chip}
                    className="rounded-full border border-red-200/10 bg-red-300/5 px-3 py-1 text-xs text-red-100/75"
                  >
                    {chip}
                  </span>
                ))}
              </div>
            </CardContent>
          </Card>

          <Card className="panel-elevated">
            <CardContent className="p-5 md:p-6">
              <div className="flex items-center justify-between gap-3">
                <p className="text-xs font-semibold tracking-[0.12em] uppercase text-primary">
                  OpenClix path
                </p>
                <span className="text-xs text-muted-foreground">
                  low-friction start
                </span>
              </div>
              <ol className="mt-4 space-y-2.5">
                {[
                  "Vendor source",
                  "Connect config JSON",
                  "Define triggers",
                  "Ship + iterate",
                ].map((step, i) => (
                  <li key={step} className="panel-muted px-3 py-2">
                    <div className="flex items-center gap-3">
                      <span className="flex h-5 w-5 items-center justify-center rounded-full border border-primary/30 bg-primary/10 text-[11px] font-semibold text-primary">
                        {i + 1}
                      </span>
                      <span className="text-sm text-foreground">{step}</span>
                    </div>
                  </li>
                ))}
              </ol>
            </CardContent>
          </Card>
        </div>
      </div>
    </section>
  );
}
