import { Hero } from "@/components/sections/hero";
import { UseCases } from "@/components/sections/use-cases";
import { QuickStart } from "@/components/sections/quick-start";
import { Features } from "@/components/sections/features";
import { Integrations } from "@/components/sections/integrations";
import { FAQ } from "@/components/sections/faq";
import { Newsletter } from "@/components/sections/newsletter";
import { Footer } from "@/components/sections/footer";

export default function Home() {
  return (
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
  );
}
