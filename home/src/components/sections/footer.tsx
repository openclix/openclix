import { DOCS_URL, GITHUB_URL } from "@/data/links";

const resourceLinks = [
  { label: "Documentation", href: DOCS_URL, external: true },
  { label: "GitHub", href: GITHUB_URL, external: true },
  { label: "Quickstart", href: "#quickstart", external: false },
];

const projectLinks = [
  { label: "FAQ", href: "#faq", external: false },
  {
    label: "License (MIT)",
    href: GITHUB_URL + "/blob/main/LICENSE",
    external: true,
  },
];

export function Footer() {
  return (
    <>
      <div className="section-divider" />
      <footer className="w-full px-6 py-12 md:py-16">
        <div className="mx-auto grid max-w-[78rem] grid-cols-1 gap-10 md:grid-cols-3">
          {/* Brand */}
          <div>
            <p className="font-heading text-lg font-bold tracking-tight text-primary">
              OpenClix
            </p>
            <p className="mt-3 max-w-xs text-sm leading-relaxed text-muted-foreground">
              Open-source, local-first mobile engagement automation.
            </p>
          </div>

          {/* Resources */}
          <div>
            <p className="footer-category">Resources</p>
            <nav className="mt-3 flex flex-col gap-2.5">
              {resourceLinks.map((link) => (
                <a
                  key={link.label}
                  href={link.href}
                  className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                  {...(link.external
                    ? { target: "_blank", rel: "noopener noreferrer" }
                    : {})}
                >
                  {link.label}
                </a>
              ))}
            </nav>
          </div>

          {/* Project */}
          <div>
            <p className="footer-category">Project</p>
            <nav className="mt-3 flex flex-col gap-2.5">
              {projectLinks.map((link) => (
                <a
                  key={link.label}
                  href={link.href}
                  className="text-sm text-muted-foreground hover:text-foreground transition-colors"
                  {...(link.external
                    ? { target: "_blank", rel: "noopener noreferrer" }
                    : {})}
                >
                  {link.label}
                </a>
              ))}
            </nav>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="mx-auto mt-10 max-w-[78rem] border-t border-border pt-6">
          <p className="text-center text-xs text-muted-foreground">
            &copy; 2025 OpenClix. Open source under MIT License.
          </p>
        </div>
      </footer>
    </>
  );
}
