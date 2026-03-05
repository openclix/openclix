import { audienceOutcomes } from "@/data/audience-outcomes";
import { quickStartSteps } from "@/data/quick-start";
import { pillars } from "@/data/pillars";

/* ── Audience strip ─────────────────────────────────────────────── */

function AudienceStrip() {
  return (
    <section className="section-shell compact">
      <div className="mx-auto max-w-5xl">
        <p className="eyebrow mb-8 justify-center text-center">
          Built for
        </p>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {audienceOutcomes.map((item) => (
            <div
              key={item.audience}
              className="panel-muted px-4 py-4 text-center"
            >
              <p className="font-heading text-sm font-semibold text-foreground">
                {item.audience}
              </p>
              <p className="mt-1.5 text-xs leading-relaxed text-muted-foreground">
                {item.outcome}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ── Quickstart ─────────────────────────────────────────────────── */

function Quickstart() {
  return (
    <section id="quickstart" className="section-shell">
      <div className="mx-auto mb-10 max-w-2xl text-center">
        <span className="eyebrow justify-center">Get started</span>
        <h2 className="mt-4 font-heading text-3xl font-bold tracking-tight md:text-4xl">
          Quickstart
        </h2>
        <p className="lede mt-4 text-sm md:text-base">
          Install OpenClix skills, then iterate with config-driven engagement
          logic you fully own.
        </p>
      </div>

      <div className="panel-muted mx-auto mb-10 w-full max-w-xl px-5 py-3.5 text-center">
        <code className="font-mono text-sm text-foreground md:text-base">
          npx skills add openclix/openclix
        </code>
      </div>

      <div className="grid grid-cols-1 gap-5 md:grid-cols-3">
        {quickStartSteps.map((s) => (
          <div key={s.step} className="panel feature-card p-5 md:p-6">
            <span className="font-heading text-2xl font-bold text-primary/60">
              {s.step}
            </span>
            <h3 className="mt-2 font-heading text-base font-semibold">
              {s.title}
            </h3>
            <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
              {s.description}
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}

/* ── Pillars ────────────────────────────────────────────────────── */

function Pillars() {
  return (
    <section id="pillars" className="section-shell">
      <div className="mx-auto mb-12 max-w-2xl text-center">
        <span className="eyebrow justify-center">Foundation</span>
        <h2 className="mt-4 font-heading text-3xl font-bold tracking-tight md:text-4xl">
          Core Pillars
        </h2>
      </div>

      <div className="grid grid-cols-1 gap-5 md:grid-cols-3">
        {pillars.map((pillar) => (
          <div
            key={pillar.title}
            className="panel feature-card p-5 md:p-6"
          >
            <h3 className="font-heading text-lg font-bold tracking-tight">
              {pillar.title}
            </h3>
            <ul className="mt-4 space-y-2.5">
              {pillar.points.map((point) => (
                <li
                  key={point}
                  className="flex items-start gap-2.5 text-sm leading-relaxed text-muted-foreground"
                >
                  <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
                  {point}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </section>
  );
}

/* ── Composed export ────────────────────────────────────────────── */

export function Jumpstart() {
  return (
    <>
      <div className="section-divider" />
      <AudienceStrip />
      <div className="section-divider" />
      <Quickstart />
      <div className="section-divider" />
      <Pillars />
    </>
  );
}
