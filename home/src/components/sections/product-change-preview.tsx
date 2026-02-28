import Image from "next/image";

type MockupScreen = {
  id: string;
  src: string;
  alt: string;
};

const mockupScreens: MockupScreen[] = [
  {
    id: "workout-home",
    src: "/images/mockups/workout-home.png",
    alt: "Workout app home screen with a motivational notification banner",
  },
  {
    id: "workout-lock",
    src: "/images/mockups/workout-lock.png",
    alt: "iPhone lock screen with stacked workout notifications",
  },
];

function IPhoneMockup({
  src,
  alt,
  offsetClassName,
}: {
  src: string;
  alt: string;
  offsetClassName?: string;
}) {
  return (
    <div className={`relative w-full ${offsetClassName ?? ""}`}>
      <div className="pointer-events-none absolute -left-[1px] top-[23%] h-16 w-[3.5px] rounded-r-full bg-white/35" />
      <div className="pointer-events-none absolute -right-[1px] top-[19%] h-24 w-[3.5px] rounded-l-full bg-white/35" />
      <div className="pointer-events-none absolute -right-[1px] top-[45%] h-16 w-[3.5px] rounded-l-full bg-white/30" />

      <div className="relative aspect-[71.6/147.6] w-full rounded-[2.8rem] border border-white/22 bg-[linear-gradient(160deg,#222830,#0f131b)] p-[7px] shadow-[0_30px_68px_rgba(0,0,0,0.48)]">
        <div className="relative h-full overflow-hidden rounded-[2.35rem] border border-white/14 bg-black">
          <Image
            src={src}
            alt={alt}
            fill
            sizes="(min-width: 1024px) 252px, 50vw"
            className="object-cover object-top"
          />
        </div>
      </div>
    </div>
  );
}

export function ProductChangePreview() {
  return (
    <section className="section-shell compact pt-2 md:pt-4">
      <div className="grid items-center gap-8 lg:grid-cols-[minmax(0,32.5rem)_minmax(0,1fr)] lg:gap-10">
        <div className="mx-auto w-full max-w-[30rem]">
          <div className="grid grid-cols-2 gap-4 md:gap-5">
            <IPhoneMockup
              src={mockupScreens[0].src}
              alt={mockupScreens[0].alt}
              offsetClassName="mt-7"
            />
            <IPhoneMockup
              src={mockupScreens[1].src}
              alt={mockupScreens[1].alt}
              offsetClassName="mb-7"
            />
          </div>
        </div>

        <div className="panel-muted px-5 py-6 md:px-7 md:py-8">
          <span className="eyebrow">Core value</span>
          <h3 className="mt-4 font-heading text-3xl font-semibold leading-[1.05] tracking-tight md:text-[2.45rem]">
            Keep Users Engaged with Unlimited Agent-Led Interaction.
          </h3>

          <ul className="mt-6 space-y-3 text-base md:text-lg">
            <li className="flex items-start gap-2.5">
              <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
              <span>Empower your app&apos;s interaction with your agent</span>
            </li>
            <li className="flex items-start gap-2.5">
              <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-accent" />
              <span>No SDK or server dependency</span>
            </li>
          </ul>
        </div>
      </div>
    </section>
  );
}
