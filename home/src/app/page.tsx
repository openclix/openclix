import { Hero } from "@/components/sections/hero";
import { UseCases } from "@/components/sections/use-cases";
import { QuickStart } from "@/components/sections/quick-start";
import { Features } from "@/components/sections/features";
import { Integrations } from "@/components/sections/integrations";
import { FAQ } from "@/components/sections/faq";
import { Newsletter } from "@/components/sections/newsletter";
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
        "Remote Config + On-Device Notification Journeys. Ship onboarding, habit, and re-engagement campaigns that run on the device—without FCM.",
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
      <main className="flex flex-col items-center">
        <Hero />
        <UseCases />
        <QuickStart />
        <Features />
        <Integrations />
        <FAQ />
        <Newsletter />
        <Footer />
      </main>
    </>
  );
}
