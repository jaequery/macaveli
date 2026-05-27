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
  title: "Macaveli — One app. Replace twelve.",
  description:
    "The Mac utility you forgot to install. Window management, snap layouts, screen recording — every macOS utility you reinstall on a fresh Mac, in one tiny menubar app. Free, open source, no signup.",
  openGraph: {
    title: "Macaveli — One app. Replace twelve.",
    description: "Every macOS utility you reinstall on a fresh Mac, in one menubar app.",
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
