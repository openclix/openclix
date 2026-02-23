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
    <section className="flex w-full flex-col items-center px-6 py-20 max-w-3xl mx-auto">
      <SectionHeading>FAQ</SectionHeading>

      <Accordion type="single" collapsible className="mt-12 w-full">
        {faqItems.map((item, i) => (
          <AccordionItem key={i} value={`item-${i}`} className="border-border">
            <AccordionTrigger className="font-heading text-left text-base font-semibold hover:text-primary transition-colors">
              {item.question}
            </AccordionTrigger>
            <AccordionContent className="text-muted-foreground text-sm leading-relaxed">
              {item.answer}
            </AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </section>
  );
}
