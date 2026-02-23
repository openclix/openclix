import type { Metadata } from "next";
import { clashDisplay, satoshi } from "@/lib/fonts";
import "./globals.css";

const siteUrl = "https://openclix.ai";
const siteName = "OpenClix";
const siteDescription =
  "Ship onboarding, habit, and re-engagement campaigns that run on the device—without FCM. No push tokens. No deliverability promises. Just deterministic, on-device control.";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: `${siteName} — Remote Config + On-Device Notification Journeys`,
    template: `%s | ${siteName}`,
  },
  description: siteDescription,
  keywords: [
    "remote config",
    "feature flags",
    "local notifications",
    "on-device notifications",
    "mobile SDK",
    "iOS",
    "Android",
    "push notifications",
    "onboarding",
    "re-engagement",
    "A/B testing",
    "notification journeys",
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
    title: `${siteName} — Remote Config + On-Device Notification Journeys`,
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
        alt: `${siteName} — Remote Config + On-Device Notification Journeys`,
      },
    ],
  },

  twitter: {
    card: "summary_large_image",
    title: `${siteName} — Remote Config + On-Device Notification Journeys`,
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
