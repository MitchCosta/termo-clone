import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Termo Clone",
  description: "A simple Wordle/Termo-style clone"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt">
      <body className="min-h-screen">{children}</body>
    </html>
  );
}
