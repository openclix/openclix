import { Instrument_Sans, Space_Grotesk } from "next/font/google";

export const clashDisplay = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-clash-display",
  display: "swap",
  weight: ["400", "500", "600", "700"],
});

export const satoshi = Instrument_Sans({
  subsets: ["latin"],
  variable: "--font-satoshi",
  display: "swap",
  weight: ["400", "500", "600", "700"],
});
