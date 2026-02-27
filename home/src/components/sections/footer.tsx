import { DOCS_URL, GITHUB_URL } from "@/data/links";

const footerLinks = [
  { label: "See GitHub", href: GITHUB_URL },
  { label: "Docs", href: DOCS_URL },
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
