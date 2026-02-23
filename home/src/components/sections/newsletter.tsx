"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { SectionHeading } from "@/components/shared/section-heading";

export function Newsletter() {
  const [email, setEmail] = useState("");

  return (
    <section className="flex w-full flex-col items-center px-6 py-20">
      <div className="w-full max-w-2xl rounded-2xl border border-border bg-card p-8 md:p-12 text-center">
        <SectionHeading>Stay in the Loop</SectionHeading>

        <p className="mt-4 text-muted-foreground text-sm">
          Get updates on releases, SDKs, and new journey templates. No spam.
          Unsubscribe anytime.
        </p>

        <form
          className="mt-8 flex flex-col sm:flex-row items-center gap-3 max-w-md mx-auto"
          onSubmit={(e) => e.preventDefault()}
        >
          <Input
            type="email"
            placeholder="your@email.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="bg-background border-border"
          />
          <Button type="submit" className="w-full sm:w-auto font-semibold shrink-0">
            Subscribe
          </Button>
        </form>
      </div>
    </section>
  );
}
