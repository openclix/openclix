import { Hero } from "@/components/sections/hero";
import { PromptTerminalSection } from "@/components/sections/prompt-terminal";
import { WhyOpenClix } from "@/components/sections/why-openclix";
import { ProofSection } from "@/components/sections/proof";
import { UseCases } from "@/components/sections/use-cases";
import { QuickStart } from "@/components/sections/quick-start";
import { AudienceOutcomes } from "@/components/sections/audience-outcomes";
import { Pillars } from "@/components/sections/pillars";
import { Features } from "@/components/sections/features";
import { Integrations } from "@/components/sections/integrations";
import { Mission } from "@/components/sections/mission";
import { FAQ } from "@/components/sections/faq";
import { FinalCTA } from "@/components/sections/final-cta";
import { Footer } from "@/components/sections/footer";
import { faqItems } from "@/data/faq";

const jsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      name: "OpenClix",
      url: "https://openclix.ai",
      applicationCategory: "DeveloperApplication",
      operatingSystem: "iOS, Android",
      description:
        "Open-source, agent-friendly reference codebase for dynamic mobile engagement controlled by remote config and executed on-device.",
      offers: {
        "@type": "Offer",
        price: "0",
        priceCurrency: "USD",
      },
    },
    {
      "@type": "Organization",
      name: "OpenClix",
      url: "https://openclix.ai",
      logo: "https://openclix.ai/icon-512.png",
      sameAs: ["https://github.com/clix-so/openclix"],
    },
    {
      "@type": "WebSite",
      name: "OpenClix",
      url: "https://openclix.ai",
    },
    {
      "@type": "FAQPage",
      mainEntity: faqItems.map((item) => ({
        "@type": "Question",
        name: item.question,
        acceptedAnswer: {
          "@type": "Answer",
          text: item.answer,
        },
      })),
    },
  ],
};

export default function Home() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <main className="w-full">
        <Hero />
        <PromptTerminalSection />
        <WhyOpenClix />
        <ProofSection />
        <QuickStart />
        <AudienceOutcomes />
        <Pillars />
        <UseCases />
        <Features />
        <Integrations />
        <Mission />
        <FAQ />
        <FinalCTA />
        <Footer />
      </main>
    </>
  );
}
