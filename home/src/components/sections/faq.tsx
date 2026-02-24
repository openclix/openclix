"use client";

import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { SectionHeading } from "@/components/shared/section-heading";
import { faqItems } from "@/data/faq";

export function FAQ() {
  return (
    <section className="section-shell compact max-w-4xl">
      <div className="flex flex-col items-start gap-4">
        <span className="eyebrow">Objection handling</span>
        <SectionHeading>FAQ</SectionHeading>
        <p className="lede text-sm md:text-base text-measure">
          Questions skeptical builders ask before trying a local-first
          engagement reference implementation.
        </p>
      </div>

      <Accordion type="single" collapsible className="mt-10 w-full panel px-5 py-2 md:px-6">
        {faqItems.map((item, i) => (
          <AccordionItem key={i} value={`item-${i}`} className="border-border/70 py-1">
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
  );
}
