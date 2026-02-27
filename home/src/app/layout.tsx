import type { Metadata } from "next";
import { clashDisplay, satoshi } from "@/lib/fonts";
import "./globals.css";

const siteUrl = "https://openclix.ai";
const siteName = "OpenClix";
const siteDescription =
  "Open-source, local-first mobile app retention and engagement automation. OpenClix uses config-driven on-device logic, source-first integration, and agent-driven operations with OpenClaw, Claude Code, and Codex.";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: `${siteName} — Agent-Based Mobile App Retention & Engagement Automation`,
    template: `%s | ${siteName}`,
  },
  description: siteDescription,
  keywords: [
    "openclix-config.json",
    "mobile app retention automation",
    "mobile engagement automation",
    "agent-driven retention ops",
    "agent-based mobile app retention automation",
    "on-device campaign operations",
    "config-driven mobile engagement",
    "source-first mobile integration",
    "openclix-init",
    "openclix-design-campaigns",
    "openclix-analytics",
    "openclix-update-campaigns",
    "retention_ops_automation",
    "OpenClaw",
    "Claude Code",
    "Codex",
    "iOS",
    "Android",
    "onboarding",
    "re-engagement",
    "OpenClix",
  ],
  authors: [{ name: siteName, url: siteUrl }],
  creator: siteName,
  publisher: siteName,

  icons: {
    icon: "/favicon.ico",
    apple: "/apple-touch-icon.png",
  },
  manifest: "/site.webmanifest",

  openGraph: {
    title: `${siteName} — Agent-Based Mobile App Retention & Engagement Automation`,
    description: siteDescription,
    url: siteUrl,
    siteName,
    locale: "en_US",
    type: "website",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: `${siteName} — Agent-Based Mobile App Retention & Engagement Automation`,
      },
    ],
  },

  twitter: {
    card: "summary_large_image",
    title: `${siteName} — Agent-Based Mobile App Retention & Engagement Automation`,
    description: siteDescription,
    images: ["/og-image.png"],
  },

  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },

  alternates: {
    canonical: siteUrl,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${clashDisplay.variable} ${satoshi.variable}`}>
      <body className="min-h-screen">{children}</body>
    </html>
  );
}
