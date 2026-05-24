import type { Metadata } from "next";
import "./globals.css";

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
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
