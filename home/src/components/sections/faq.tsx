"use client";

import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { faqItems } from "@/data/faq";

export function FAQ() {
  return (
    <>
      <div className="section-divider" />
      <section id="faq" className="section-shell compact max-w-4xl">
        <div className="flex flex-col items-center gap-4 text-center">
          <span className="eyebrow justify-center">Common questions</span>
          <h2 className="font-heading text-3xl font-bold tracking-tight md:text-4xl">
            FAQ
          </h2>
          <p className="lede text-sm text-measure md:text-base">
            Quick answers before you adopt OpenClix.
          </p>
        </div>

        <Accordion
          type="single"
          collapsible
          className="mt-10 w-full panel px-5 py-2 md:px-6"
        >
          {faqItems.map((item, i) => (
            <AccordionItem
              key={i}
              value={`item-${i}`}
              className="border-border/70 py-1"
            >
              <AccordionTrigger className="font-heading text-left text-base font-semibold hover:text-primary transition-colors">
                {item.question}
              </AccordionTrigger>
              <AccordionContent className="text-muted-foreground text-sm leading-relaxed pb-3">
                {item.answer}
              </AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </section>
    </>
  );
}
