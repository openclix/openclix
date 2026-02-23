import type { Metadata } from "next";
import { clashDisplay, satoshi } from "@/lib/fonts";
import "./globals.css";

export const metadata: Metadata = {
  title: "OpenClix — Remote Config + On-Device Notification Journeys",
  description:
    "Ship onboarding, habit, and re-engagement campaigns that run on the device—without FCM. No push tokens. No deliverability promises. Just deterministic, on-device control.",
  openGraph: {
    title: "OpenClix",
    description:
      "Remote Config + On-Device Notification Journeys. Ship campaigns that run on the device—without FCM.",
    url: "https://openclix.ai",
    siteName: "OpenClix",
    type: "website",
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
