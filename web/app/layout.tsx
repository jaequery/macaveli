import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Macaveli — Move, resize, and record macOS windows from anywhere",
  description:
    "A tiny macOS menubar app for fast window management and screen recording. Hold a modifier, drag anywhere on a window to move or resize. Snap to halves with ⌃[ and ⌃].",
  openGraph: {
    title: "Macaveli",
    description:
      "Move, resize, and record macOS windows from anywhere. A tiny menubar app.",
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
