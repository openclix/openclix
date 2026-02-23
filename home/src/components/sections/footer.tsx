const footerLinks = [
  { label: "Docs", href: "#" },
  { label: "GitHub", href: "https://github.com/clix-so/openclix" },
  { label: "Changelog", href: "#" },
  { label: "Privacy", href: "#" },
  { label: "Contact", href: "#" },
];

export function Footer() {
  return (
    <footer className="flex w-full flex-col items-center px-6 py-12 border-t border-border">
      <div className="flex flex-col items-center gap-6 max-w-4xl">
        <p className="font-heading text-lg font-semibold text-primary">
          openclix.ai
        </p>

        <nav className="flex flex-wrap items-center justify-center gap-x-6 gap-y-2">
          {footerLinks.map((link) => (
            <a
              key={link.label}
              href={link.href}
              className="text-sm text-muted-foreground hover:text-foreground transition-colors"
              {...(link.href.startsWith("http")
                ? { target: "_blank", rel: "noopener noreferrer" }
                : {})}
            >
              {link.label}
            </a>
          ))}
        </nav>
      </div>
    </footer>
  );
}
