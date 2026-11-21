import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Pan-India Lost & Found",
    short_name: "Lost & Found",
    description: "Report a lost or found item and get AI-matched results.",
    start_url: "/",
    display: "standalone",
    background_color: "#f3f6fb",
    theme_color: "#1e40d8",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
