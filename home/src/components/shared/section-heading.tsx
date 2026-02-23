export function SectionHeading({ children }: { children: React.ReactNode }) {
  return (
    <h2 className="font-heading text-3xl md:text-4xl font-bold tracking-tight">
      <span className="text-primary mr-2">&#x27E9;</span>
      {children}
    </h2>
  );
}
