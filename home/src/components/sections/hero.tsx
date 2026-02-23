import Image from "next/image";
import { Button } from "@/components/ui/button";

export function Hero() {
  return (
    <section className="relative flex w-full flex-col items-center px-6 pt-24 pb-16 text-center">
      {/* Glow effect */}
      <div className="pointer-events-none absolute top-0 left-1/2 -translate-x-1/2 h-[400px] w-[600px] rounded-full bg-primary/10 blur-[120px]" />

      <div className="relative z-10 flex flex-col items-center gap-6 max-w-3xl">
        {/* Mascot icon */}
        <div className="mascot-icon cursor-pointer mb-2">
          <Image
            src="/images/mascot.png"
            alt="OpenClix mascot"
            width={240}
            height={160}
            className="mascot-image"
            priority
          />
        </div>

        <h1 className="font-heading text-5xl md:text-7xl font-bold tracking-tight">
          OpenClix
        </h1>

        <p className="text-lg md:text-xl font-semibold text-primary">
          Remote Config + On-Device Notification Journeys.
        </p>

        <p className="text-muted-foreground text-base md:text-lg max-w-2xl leading-relaxed">
          Ship onboarding, habit, and re-engagement campaigns that run on the
          device—without FCM. No push tokens. No deliverability promises. Just
          deterministic, on-device control.
        </p>

        <div className="flex flex-wrap items-center justify-center gap-3 mt-4">
          <Button size="lg" className="font-semibold">
            Get Started
          </Button>
          <Button size="lg" variant="outline" className="font-semibold">
            Docs
          </Button>
          <Button size="lg" variant="outline" className="font-semibold" asChild>
            <a
              href="https://github.com/clix-so/openclix"
              target="_blank"
              rel="noopener noreferrer"
            >
              GitHub
            </a>
          </Button>
          <Button
            size="lg"
            variant="secondary"
            className="font-semibold"
          >
            Request Early Access
          </Button>
        </div>
      </div>
    </section>
  );
}
