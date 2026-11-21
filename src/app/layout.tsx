import type { Metadata, Viewport } from "next";
import { Archivo, Figtree } from "next/font/google";
import "./globals.css";
import Navbar from "@/components/Navbar";

const archivo = Archivo({
  variable: "--font-archivo",
  subsets: ["latin"],
});

const figtree = Figtree({
  variable: "--font-figtree",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Pan-India Lost & Found",
  description:
    "Report a lost or found item. AI compares descriptions, places and dates to find likely matches.",
};

export const viewport: Viewport = {
  themeColor: "#1e40d8",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${archivo.variable} ${figtree.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col">
        <Navbar />
        {children}
        <footer className="mt-auto border-t border-line py-6 text-sm text-ink-soft">
          <div className="max-w-6xl mx-auto px-5">
            Built by Astha Dixit, Hemal Nangru and Shubham Kumar for INT252, Lovely
            Professional University.
          </div>
        </footer>
      </body>
    </html>
  );
}
