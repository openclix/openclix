import { Navbar } from "@/components/sections/navbar";
import { Hero } from "@/components/sections/hero";
import { Jumpstart } from "@/components/sections/jumpstart";
import { Mission } from "@/components/sections/mission";
import { FAQ } from "@/components/sections/faq";
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
        "Open-source, local-first foundation for agent-based mobile app retention and engagement automation using config-driven, on-device messaging logic.",
      keywords: [
        "mobile app retention automation",
        "mobile engagement automation",
        "agent-driven retention ops",
        "OpenClaw",
        "Claude Code",
        "Codex",
      ],
      featureList: [
        "openclix-init integration automation",
        "openclix-design-campaigns config generation",
        "openclix-analytics impact measurement",
        "openclix-update-campaigns recommendation drafting",
        "retention_ops_automation multi-agent prompt generation",
      ],
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
      sameAs: ["https://github.com/openclix/openclix"],
    },
    {
      "@type": "WebSite",
      name: "OpenClix",
      url: "https://openclix.ai",
      description:
        "Documentation and workflows for agent-based mobile app retention and engagement automation with OpenClaw, Claude Code, and Codex.",
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
      <Navbar />
      <main className="w-full">
        <Hero />
        <Jumpstart />
        <Mission />
        <FAQ />
        <Footer />
      </main>
    </>
  );
}
