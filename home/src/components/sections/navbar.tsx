import { DOCS_URL, GITHUB_URL } from "@/data/links";

const navLinks = [
  { label: "Quickstart", href: "#quickstart" },
  { label: "FAQ", href: "#faq" },
];

export function Navbar() {
  return (
    <header className="site-navbar">
      <div className="site-navbar-inner">
        <a
          href="/"
          className="font-heading text-lg font-bold text-primary tracking-tight"
        >
          OpenClix
        </a>

        <nav className="flex items-center gap-6">
          {navLinks.map((link) => (
            <a
              key={link.label}
              href={link.href}
              className="hidden md:inline-block text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              {link.label}
            </a>
          ))}
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="hidden md:inline-block text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            GitHub
          </a>
          <a
            href={DOCS_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center h-8 px-4 text-sm font-semibold rounded-md border border-primary/40 text-primary hover:bg-primary/10 transition-colors"
          >
            Docs
          </a>
        </nav>
      </div>
    </header>
  );
}
