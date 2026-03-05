export function SectionHeading({ children }: { children: React.ReactNode }) {
  return (
    <h2 className="font-heading text-3xl md:text-4xl font-bold tracking-tight">
      {children}
    </h2>
  );
}
