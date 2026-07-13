import type { Metadata } from "next";
import { JetBrains_Mono } from "next/font/google";
import "./globals.css";

// Mono signature — keycaps, eyebrows, section labels, version tags.
const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  variable: "--font-jetbrains",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Macaveli — Your Mac, already set up.",
  description:
    "The essential Mac utilities — window control, screenshots, clipboard history, screen recording — already configured in one free menubar app. Open source, no signup, no telemetry.",
  openGraph: {
    title: "Macaveli — Your Mac, already set up.",
    description:
      "The essential Mac utilities, already configured in one free menubar app. Open source, no signup, no telemetry.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={jetbrainsMono.variable}>
      <body>{children}</body>
    </html>
  );
}
