import localFont from "next/font/local";

export const clashDisplay = localFont({
  src: "../fonts/ClashDisplay-Variable.woff2",
  variable: "--font-clash-display",
  display: "swap",
  weight: "200 700",
});

export const satoshi = localFont({
  src: "../fonts/Satoshi-Variable.woff2",
  variable: "--font-satoshi",
  display: "swap",
  weight: "300 900",
});
