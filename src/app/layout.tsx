import type { Metadata, Viewport } from "next";
import { Archivo, Figtree, Noto_Sans_Devanagari } from "next/font/google";
import "./globals.css";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

const archivo = Archivo({
  variable: "--font-archivo",
  subsets: ["latin"],
});

const figtree = Figtree({
  variable: "--font-figtree",
  subsets: ["latin"],
});

// Hindi letters. The browser uses it only for characters the other fonts lack.
const deva = Noto_Sans_Devanagari({
  variable: "--font-deva",
  subsets: ["devanagari"],
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
    <html
      lang="en"
      className={`${archivo.variable} ${figtree.variable} ${deva.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <Navbar />
        {children}
        <Footer />
      </body>
    </html>
  );
}
