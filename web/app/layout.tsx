import type { Metadata, Viewport } from "next";
import { JetBrains_Mono } from "next/font/google";
import { SiteEffects } from "./components/site-effects";
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

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f2f2f0" },
    { media: "(prefers-color-scheme: dark)", color: "#0e0e10" },
  ],
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={jetbrainsMono.variable} suppressHydrationWarning>
      <head>
        {/* Scroll-reveal only hides content once we know JS is running. */}
        <script dangerouslySetInnerHTML={{ __html: "document.documentElement.classList.add('js')" }} />
      </head>
      <body>
        <a className="skip" href="#main">
          Skip to content
        </a>
        {children}
        <SiteEffects />
      </body>
    </html>
  );
}
