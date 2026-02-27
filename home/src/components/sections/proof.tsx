import { Card, CardContent } from "@/components/ui/card";
import { SectionHeading } from "@/components/shared/section-heading";

const annotations = [
  "What event happened",
  "What rule matched",
  "Why message fired (or was suppressed)",
];

export function ProofSection() {
  return (
    <section className="section-shell glow">
      <div className="flex flex-col gap-4">
        <span className="eyebrow">Aha early</span>
        <SectionHeading>Fast Proof</SectionHeading>
        <p className="lede text-sm md:text-base text-measure">
          Show the execution path early. This panel explains what happened,
          which rule matched, and the reason behind the outcome.
        </p>
      </div>

      <div className="mt-10 grid w-full gap-6 lg:grid-cols-[1.2fr_0.8fr]">
        <Card className="panel-elevated overflow-hidden">
          <CardContent className="p-4 md:p-5">
            <div className="rounded-xl border border-border/80 bg-background/70 p-4 md:p-5">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <p className="text-xs font-semibold tracking-[0.13em] uppercase text-muted-foreground">
                  Demo flow mock
                </p>
                <div className="font-mono text-[11px] text-muted-foreground">
                  config -&gt; event -&gt; rule -&gt; message
                </div>
              </div>

              <div className="mt-4 space-y-3">
                <div className="panel-muted px-3.5 py-3">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                      1. Config change
                    </span>
                    <span className="rounded-full border border-border px-2 py-0.5 text-[10px] text-muted-foreground">
                      openclix-config.json
                    </span>
                  </div>
                  <p className="mt-2 text-sm leading-relaxed">
                    Updated the hosted JSON copy and delay window for inactive users.
                  </p>
                </div>

                <div className="grid gap-3 md:grid-cols-2">
                  <div className="panel-muted px-3.5 py-3">
                    <p className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                      2. Trigger event
                    </p>
                    <p className="mt-2 font-mono text-xs text-muted-foreground">
                      app_foreground • last_seen=3d
                    </p>
                  </div>
                  <div className="panel-muted px-3.5 py-3">
                    <p className="text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
                      3. Rule match
                    </p>
                    <p className="mt-2 font-mono text-xs text-primary">
                      match=reengagement_3d
                    </p>
                  </div>
                </div>

                <div className="rounded-xl border border-primary/20 bg-primary/7 p-3.5">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="text-sm font-semibold">4. Scheduled message</p>
                    <div className="flex items-center gap-2">
                      <span className="rounded-full border border-primary/20 bg-background/50 px-2 py-1 text-[10px]">
                        fired
                      </span>
                      <span className="rounded-full border border-border px-2 py-1 text-[10px] text-muted-foreground">
                        suppression: none
                      </span>
                    </div>
                  </div>
                  <p className="mt-2 text-sm text-muted-foreground leading-relaxed">
                    “Pick up where you left off” notification queued for 15
                    minutes with deep link to onboarding step.
                  </p>
                </div>

                <div className="rounded-xl border border-dashed border-border/80 bg-background/50 px-4 py-5 text-center">
                  <p className="font-heading text-lg font-semibold">
                    Replace with demo GIF/video later
                  </p>
                  <p className="mt-2 text-sm text-muted-foreground">
                    Use the same visual story: config update, event trace, rule
                    decision, message preview, reason panel.
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="panel overflow-hidden">
          <CardContent className="p-5 md:p-6">
            <p className="text-xs uppercase tracking-[0.13em] text-muted-foreground">
              Explain the panel
            </p>
            <ul className="mt-4 space-y-3">
              {annotations.map((item, i) => (
                <li key={item} className="panel-muted px-3 py-3">
                  <div className="flex items-start gap-3 text-sm leading-relaxed">
                    <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full border border-primary/25 bg-primary/10 text-[11px] font-semibold text-primary">
                      {i + 1}
                    </span>
                    <span className="text-muted-foreground">{item}</span>
                  </div>
                </li>
              ))}
            </ul>

            <div className="mt-6 rounded-xl border border-primary/20 bg-primary/5 p-4">
              <p className="text-sm font-medium text-foreground">
                See what changed, not just what fired.
              </p>
              <p className="mt-1 text-xs text-muted-foreground">
                Built to make retention behavior inspectable during development.
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </section>
  );
}
