#!/bin/bash
# Adds: item detail page, map view on Browse, live numbers on the home page,
# and phone installability (manifest and icons).
# Run it from inside the lost-found folder (the one with package.json).
set -e

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "Run this inside the lost-found folder (the one that has package.json)."
  exit 1
fi

BACKUP="backup-before-upgrades"
mkdir -p "$BACKUP"
if ! grep -qx "$BACKUP/" .gitignore 2>/dev/null; then
  printf "\n%s/\n" "$BACKUP" >> .gitignore
fi

write() {
  local f="$1"
  mkdir -p "$(dirname "$f")"
  if [ -f "$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$f" "$BACKUP/$f"
  fi
  cat > "$f"
  echo "wrote $f"
}

write_png() {
  local f="$1"
  local data="$2"
  mkdir -p "$(dirname "$f")"
  node -e "require('fs').writeFileSync(process.argv[1], Buffer.from(process.argv[2], 'base64'))" "$f" "$data"
  echo "wrote $f"
}

write "src/app/items/[id]/page.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useMemo, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import dynamic from "next/dynamic";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import TicketBand from "@/components/TicketBand";
import type { MapPoint } from "@/components/MapView";

const MapView = dynamic(() => import("@/components/MapView"), {
  ssr: false,
  loading: () => <p className="p-4 text-sm text-ink-soft">Loading map...</p>,
});

type Item = {
  id: string;
  type: string;
  title: string;
  description: string | null;
  category: string;
  color: string | null;
  city: string | null;
  lat: number | null;
  lng: number | null;
  event_date: string;
  status: string;
  image_url: string | null;
};

export default function ItemDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [item, setItem] = useState<Item | null>(null);
  const [loading, setLoading] = useState(true);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    supabase
      .from("items")
      .select("id,type,title,description,category,color,city,lat,lng,event_date,status,image_url")
      .eq("id", id)
      .maybeSingle()
      .then(({ data }) => {
        setItem((data as Item | null) ?? null);
        setLoading(false);
      });
  }, [id]);

  const points: MapPoint[] = useMemo(
    () =>
      item && typeof item.lat === "number" && typeof item.lng === "number"
        ? [{ id: item.id, lat: item.lat, lng: item.lng, type: item.type, title: item.title }]
        : [],
    [item]
  );

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(window.location.href);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      setCopied(false);
    }
  }

  if (loading) return <main className="max-w-4xl mx-auto px-5 py-8">Loading report...</main>;

  if (!item) {
    return (
      <main className="max-w-4xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">Report not found</h1>
        <p className="mb-4 text-ink-soft">This report doesn&apos;t exist or was removed.</p>
        <Link href="/items" className="btn btn-primary">
          Browse reports
        </Link>
      </main>
    );
  }

  const rows: [string, string][] = [
    ["Category", item.category],
    ["Colour", item.color || "Not given"],
    ["City", item.city || "Not given"],
    [item.type === "lost" ? "Lost on" : "Found on", formatDate(item.event_date)],
    ["Status", item.status],
  ];

  return (
    <main className="max-w-4xl mx-auto px-5 py-8">
      <Link href="/items" className="text-sm text-rail-dark underline">
        Back to all reports
      </Link>

      <div className="mt-4 grid gap-6 md:grid-cols-[1.2fr_1fr] items-start">
        <article className="ticket">
          <TicketBand type={item.type} id={item.id} />
          {item.image_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={item.image_url}
              alt={item.title}
              className="w-full max-h-96 object-cover border-b-[1.5px] border-ink"
            />
          ) : (
            <div className="h-40 grid place-items-center bg-paper text-ink-soft border-b-[1.5px] border-ink">
              No photo added
            </div>
          )}
          <div className="p-5">
            <h1 className="font-display font-extrabold text-3xl leading-tight">{item.title}</h1>
            {item.description && <p className="mt-3 text-lg">{item.description}</p>}
          </div>
          <div className="ticket-perf mx-5" />
          <div className="p-5 flex flex-wrap gap-3">
            {item.type === "found" && (
              <Link href={`/claim/${item.id}`} className="btn btn-primary">
                Claim this item
              </Link>
            )}
            <button type="button" onClick={copyLink} className="btn">
              {copied ? "Link copied" : "Copy link"}
            </button>
          </div>
        </article>

        <aside className="space-y-4">
          <div className="panel">
            <h2 className="font-display font-bold text-xl mb-3">Details</h2>
            <dl className="space-y-2 text-sm">
              {rows.map(([k, v]) => (
                <div key={k} className="flex justify-between gap-4 border-b border-line pb-2 last:border-0">
                  <dt className="text-ink-soft">{k}</dt>
                  <dd className="font-semibold text-right capitalize">{v}</dd>
                </div>
              ))}
            </dl>
          </div>

          {points.length > 0 ? (
            <div className="isolate overflow-hidden rounded-xl border-[1.5px] border-ink">
              <MapView points={points} height={240} popups={false} />
            </div>
          ) : (
            <div className="panel text-sm text-ink-soft">This report has no map pin.</div>
          )}
        </aside>
      </div>
    </main>
  );
}
__LF_EOF__

write "src/app/items/page.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import dynamic from "next/dynamic";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import TicketBand from "@/components/TicketBand";
import type { MapPoint } from "@/components/MapView";

const MapView = dynamic(() => import("@/components/MapView"), {
  ssr: false,
  loading: () => <p className="p-4 text-sm text-ink-soft">Loading map...</p>,
});

type Item = {
  id: string;
  type: string;
  title: string;
  description: string | null;
  category: string;
  city: string | null;
  lat: number | null;
  lng: number | null;
  event_date: string;
  status: string;
  image_url: string | null;
};

const CATEGORIES = ["phone", "wallet", "bag", "keys", "documents", "laptop", "other"];

export default function ItemsPage() {
  const [items, setItems] = useState<Item[]>([]);
  const [type, setType] = useState("all");
  const [category, setCategory] = useState("all");
  const [city, setCity] = useState("");
  const [view, setView] = useState("list");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      setLoading(true);
      let q = supabase
        .from("items")
        .select("id,type,title,description,category,city,lat,lng,event_date,status,image_url")
        .order("created_at", { ascending: false })
        .limit(60);
      if (type !== "all") q = q.eq("type", type);
      if (category !== "all") q = q.eq("category", category);
      if (city.trim()) q = q.ilike("city", `%${city.trim()}%`);
      const { data } = await q;
      setItems((data as Item[]) ?? []);
      setLoading(false);
    }
    load();
  }, [type, category, city]);

  const points: MapPoint[] = useMemo(
    () =>
      items
        .filter((i) => typeof i.lat === "number" && typeof i.lng === "number")
        .map((i) => ({
          id: i.id,
          lat: i.lat as number,
          lng: i.lng as number,
          type: i.type,
          title: i.title,
        })),
    [items]
  );

  return (
    <main className="max-w-6xl mx-auto px-5 py-8">
      <div className="flex flex-wrap items-end justify-between gap-4 mb-6">
        <div>
          <h1 className="font-display font-extrabold text-3xl">Browse reports</h1>
          <p className="text-ink-soft">
            {loading
              ? "Loading reports..."
              : `${items.length} report${items.length === 1 ? "" : "s"} shown`}
          </p>
        </div>
        <Link href="/report" className="btn btn-primary">
          Report an item
        </Link>
      </div>

      <div className="panel flex flex-wrap items-center gap-3 mb-6">
        <div className="segmented" role="group" aria-label="Report type">
          {[
            ["all", "All"],
            ["lost", "Lost"],
            ["found", "Found"],
          ].map(([v, l]) => (
            <button key={v} type="button" aria-pressed={type === v} onClick={() => setType(v)}>
              {l}
            </button>
          ))}
        </div>
        <select
          className="field"
          aria-label="Category"
          value={category}
          onChange={(e) => setCategory(e.target.value)}
        >
          <option value="all">All categories</option>
          {CATEGORIES.map((c) => (
            <option key={c}>{c}</option>
          ))}
        </select>
        <input
          className="field"
          aria-label="City"
          placeholder="Search city, e.g. Jalandhar"
          value={city}
          onChange={(e) => setCity(e.target.value)}
        />
        <div className="segmented sm:ml-auto" role="group" aria-label="View">
          {[
            ["list", "List"],
            ["map", "Map"],
          ].map(([v, l]) => (
            <button key={v} type="button" aria-pressed={view === v} onClick={() => setView(v)}>
              {l}
            </button>
          ))}
        </div>
      </div>

      {!loading && items.length === 0 && (
        <div className="panel">
          <p className="font-semibold">No reports match these filters.</p>
          <p className="text-ink-soft">
            Clear a filter, or{" "}
            <Link href="/report" className="text-rail-dark underline">
              report the item yourself
            </Link>
            .
          </p>
        </div>
      )}

      {view === "map" && items.length > 0 && (
        <div className="mb-6">
          <div className="isolate overflow-hidden rounded-xl border-[1.5px] border-ink">
            <MapView points={points} height={520} />
          </div>
          <p className="mt-2 text-sm text-ink-soft">
            <span className="inline-block h-3 w-3 rounded-full bg-lost border border-ink align-middle" />{" "}
            Lost{" "}
            <span className="ml-3 inline-block h-3 w-3 rounded-full bg-found border border-ink align-middle" />{" "}
            Found. {points.length} of {items.length} reports have a map pin.
          </p>
        </div>
      )}

      {view === "list" && (
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((it) => (
            <article key={it.id} className="ticket relative flex flex-col">
              <TicketBand type={it.type} id={it.id} />
              {it.image_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={it.image_url}
                  alt={it.title}
                  className="h-40 w-full object-cover border-b-[1.5px] border-ink"
                />
              ) : (
                <div className="h-24 grid place-items-center bg-paper text-sm text-ink-soft border-b-[1.5px] border-ink">
                  No photo added
                </div>
              )}
              <div className="p-4 flex-1">
                <h2 className="font-display font-bold text-lg leading-snug">
                  <Link href={`/items/${it.id}`} className="after:absolute after:inset-0">
                    {it.title}
                  </Link>
                </h2>
                {it.description && (
                  <p className="text-sm text-ink-soft mt-1 line-clamp-2">{it.description}</p>
                )}
                <span className="chip mt-3">{it.category}</span>
              </div>
              <div className="ticket-perf mx-4" />
              <div className="px-4 py-3 flex items-center justify-between gap-2 text-sm">
                <span className="text-ink-soft">
                  {it.city ?? "Unknown city"}, {formatDate(it.event_date)}
                </span>
                <span className={`chip ${it.type === "lost" ? "chip-lost" : "chip-found"}`}>
                  {it.status}
                </span>
              </div>
            </article>
          ))}
        </div>
      )}
    </main>
  );
}
__LF_EOF__

write "src/app/layout.tsx" <<'__LF_EOF__'
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
__LF_EOF__

write "src/app/manifest.ts" <<'__LF_EOF__'
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
__LF_EOF__

write "src/app/page.tsx" <<'__LF_EOF__'
import Link from "next/link";
import TicketBand from "@/components/TicketBand";
import HomeLive from "@/components/HomeLive";

const steps = [
  {
    n: "1",
    title: "Report",
    text: "Say what you lost or found. Add a photo and drop a pin on the map.",
  },
  {
    n: "2",
    title: "Match",
    text: "We compare descriptions, distance and dates, and show why two reports look alike.",
  },
  {
    n: "3",
    title: "Claim",
    text: "The finder sets a question. Answer it correctly and you get their contact details.",
  },
];

export default function Home() {
  return (
    <main className="max-w-6xl mx-auto px-5">
      <section className="grid gap-12 lg:grid-cols-2 items-center py-14 lg:py-20">
        <div>
          <h1 className="font-display font-extrabold text-4xl sm:text-5xl lg:text-[3.4rem] leading-[1.05]">
            Lost it somewhere in India? Someone may already have found it.
          </h1>
          <p className="mt-5 text-lg text-ink-soft max-w-prose">
            Report what you lost or found. We compare descriptions, places and dates, and
            tell you why two reports match.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/report" className="btn btn-primary">
              Report a lost item
            </Link>
            <Link href="/report?type=found" className="btn">
              I found something
            </Link>
          </div>
          <p className="mt-5 text-sm text-ink-soft max-w-md">
            Contact details stay hidden until the owner answers a question only they would
            know.
          </p>
        </div>

        <div className="relative mx-auto w-full max-w-md py-6" aria-hidden="true">
          <div className="ticket -rotate-2">
            <TicketBand type="lost" id="A7K2" />
            <div className="p-4">
              <p className="font-display font-bold text-lg">Black Samsung phone</p>
              <p className="text-sm text-ink-soft">Cracked screen, dog wallpaper</p>
              <p className="mt-2 text-xs text-ink-soft">Hisar, 14 Nov</p>
            </div>
          </div>
          <div className="ticket rotate-[1.5deg] mt-5 ml-8">
            <TicketBand type="found" id="Q93M" />
            <div className="p-4">
              <p className="font-display font-bold text-lg">Dark mobile phone</p>
              <p className="text-sm text-ink-soft">Broken display, puppy lock screen</p>
              <p className="mt-2 text-xs text-ink-soft">Hisar, 15 Nov</p>
            </div>
          </div>
          <div className="match-stamp absolute right-0 top-1/2 -translate-y-1/2 text-lg">
            82% match
          </div>
        </div>
      </section>

      <HomeLive />

      <section className="pb-16">
        <h2 className="font-display font-extrabold text-2xl mb-6">How it works</h2>
        <div className="grid gap-6 sm:grid-cols-3">
          {steps.map((s) => (
            <div key={s.n} className="border-t-[3px] border-ink pt-4">
              <p className="font-display font-extrabold text-4xl text-rail">{s.n}</p>
              <h3 className="font-display font-bold text-xl mt-1">{s.title}</h3>
              <p className="mt-1 text-ink-soft">{s.text}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="mb-16 rounded-2xl bg-ink text-white p-8 sm:p-10 grid gap-6 sm:grid-cols-[1fr_auto] items-center">
        <div>
          <h2 className="font-display font-extrabold text-2xl">You can judge every match yourself</h2>
          <p className="mt-2 text-white/85 max-w-2xl">
            Each match lists its reasons, such as 400 m away or same colour. A finder&apos;s
            contact details are stored separately and never reach your browser until you
            pass the check.
          </p>
        </div>
        <Link href="/items" className="btn">
          Browse found items
        </Link>
      </section>
    </main>
  );
}
__LF_EOF__

write "src/components/HomeLive.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import TicketBand from "@/components/TicketBand";

type Recent = {
  id: string;
  type: string;
  title: string;
  description: string | null;
  city: string | null;
  event_date: string;
  image_url: string | null;
};

type Stats = { total: number; lost: number; found: number; returned: number };

export default function HomeLive() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [recent, setRecent] = useState<Recent[]>([]);

  useEffect(() => {
    async function load() {
      const count = () => supabase.from("items").select("id", { count: "exact", head: true });
      const [t, l, f, r, rec] = await Promise.all([
        count(),
        count().eq("type", "lost"),
        count().eq("type", "found"),
        count().eq("status", "returned"),
        supabase
          .from("items")
          .select("id,type,title,description,city,event_date,image_url")
          .eq("type", "found")
          .order("created_at", { ascending: false })
          .limit(3),
      ]);
      setStats({
        total: t.count ?? 0,
        lost: l.count ?? 0,
        found: f.count ?? 0,
        returned: r.count ?? 0,
      });
      setRecent((rec.data as Recent[]) ?? []);
    }
    load();
  }, []);

  const cells: [string, number | undefined][] = [
    ["Reports", stats?.total],
    ["Lost", stats?.lost],
    ["Found", stats?.found],
    ["Returned", stats?.returned],
  ];

  return (
    <section className="pb-16">
      <div className="ticket grid grid-cols-2 sm:grid-cols-4 divide-dashed divide-line-strong sm:divide-x-2">
        {cells.map(([label, n]) => (
          <div key={label} className="px-5 py-4">
            <p className="font-display font-extrabold text-3xl">{n === undefined ? "-" : n}</p>
            <p className="text-sm text-ink-soft">{label}</p>
          </div>
        ))}
      </div>

      {recent.length > 0 && (
        <div className="mt-10">
          <div className="flex items-end justify-between gap-4 mb-4">
            <h2 className="font-display font-extrabold text-2xl">Recently found</h2>
            <Link href="/items" className="text-rail-dark underline font-semibold">
              Browse all reports
            </Link>
          </div>
          <div className="grid gap-5 sm:grid-cols-3">
            {recent.map((it) => (
              <article key={it.id} className="ticket relative">
                <TicketBand type={it.type} id={it.id} />
                <div className="p-4">
                  <h3 className="font-display font-bold text-lg leading-snug">
                    <Link href={`/items/${it.id}`} className="after:absolute after:inset-0">
                      {it.title}
                    </Link>
                  </h3>
                  {it.description && (
                    <p className="text-sm text-ink-soft mt-1 line-clamp-2">{it.description}</p>
                  )}
                  <p className="text-xs text-ink-soft mt-3">
                    {it.city ?? "Unknown city"}, {formatDate(it.event_date)}
                  </p>
                </div>
              </article>
            ))}
          </div>
        </div>
      )}
    </section>
  );
}
__LF_EOF__

write "src/components/MapView.tsx" <<'__LF_EOF__'
"use client";
import { useEffect } from "react";
import Link from "next/link";
import { MapContainer, TileLayer, CircleMarker, Popup, useMap } from "react-leaflet";
import "leaflet/dist/leaflet.css";

export type MapPoint = {
  id: string;
  lat: number;
  lng: number;
  type: string;
  title: string;
};

function Fit({ points }: { points: MapPoint[] }) {
  const map = useMap();
  useEffect(() => {
    if (points.length === 0) return;
    if (points.length === 1) {
      map.setView([points[0].lat, points[0].lng], 14);
      return;
    }
    map.fitBounds(
      points.map((p) => [p.lat, p.lng] as [number, number]),
      { padding: [40, 40], maxZoom: 13 }
    );
  }, [points, map]);
  return null;
}

export default function MapView({
  points,
  height = 320,
  popups = true,
}: {
  points: MapPoint[];
  height?: number;
  popups?: boolean;
}) {
  return (
    <MapContainer
      center={[22.9734, 78.6569]}
      zoom={5}
      style={{ height, width: "100%" }}
    >
      <TileLayer
        attribution="&copy; OpenStreetMap contributors"
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <Fit points={points} />
      {points.map((p) => (
        <CircleMarker
          key={p.id}
          center={[p.lat, p.lng]}
          radius={9}
          pathOptions={{
            color: "#0e1a3a",
            weight: 2,
            fillColor: p.type === "lost" ? "#c23b20" : "#14815a",
            fillOpacity: 0.9,
          }}
        >
          {popups && (
            <Popup>
              <div style={{ minWidth: 140 }}>
                <strong>{p.title}</strong>
                <br />
                {p.type === "lost" ? "Lost" : "Found"}
                <br />
                <Link href={`/items/${p.id}`} style={{ color: "#162fa3", textDecoration: "underline" }}>
                  View details
                </Link>
              </div>
            </Popup>
          )}
        </CircleMarker>
      ))}
    </MapContainer>
  );
}
__LF_EOF__

write_png "public/icons/icon-192.png" "iVBORw0KGgoAAAANSUhEUgAAAMAAAADACAIAAADdvvtQAAALFklEQVR42u3de4ycVRnH8ec5553LO5ednen2xtIttKUtFVpLuYhIQ4NooEYhGqM2kWgCBEJbBQVNC0SpkRgu2oJY+gcYIyJBTa2FgBiBFqqWXrCRFrAFSqW23dvs7NzPOY9/7FLoBdguO+7MO79v9o8mTWazM5+c9533nPe83HHRLkJouCm8BQiAEAAhAEIAhBAAIQBCAIQACCEAQgCEAAgBEEIAhAAIARACIIQACAEQAiAEQAiAEAIgBEAIgBAAIQRACIAQACEAQgiAEAAhAEIAhBAAIQBCAIQACAEQQgCEAAgBEAIghAAIARACIARACAEQAiAEQAiAEAIgBEAIgBAAIeThLTgiccRExDV6dSImEWKu2a8AoNGzQ0SsE0Ru4N81S4tUyZWJFQAFSQ+TCpd7nqz0bSKu2fAgVoXGRtsu1+F2sXliDUAB0cPKz++/v9S1jlXk8IBUk5NOqVRzmxMdy7zYDDG5RjfEHRftgh5Wfn7/z8vdj7NuZRbFUiM+TGRFiyuyiiU7lgfAUJMDOlqPUrZquFhmViM9BvHgCyZj1jktUg6GoWYGdLQerU2+qMelzMrr9mUSliwzjxgi51j57tGn0/eta8u0GuO0uCAY8qDnsJ5CSWXiZu1te86a008lVYtrZPNn9zPTvWvbMmljKCKukNu7oqENNecIdHw9rTH3xIrdc2flq1lPKRnpSzVCwqRF+27xTycNGmr8cUinTrkeet6rx2S9kCeKaeR/FLGQM7zwwmx3b+jZ7Yl4zAqFxJUqfZtCsY/pyEnkSo11fajZAH24Hs+r4VVE5qAZaipAo6wnkIaaB1Bd6AmeoSYBVEd6AmaoGQDVnZ4hG2onKdf5vH3gAdWpnqEZmqlD44mq9Wwo2IDqWs+xhrp6Q89uT8RiViQsLl/N/zPSuoBUiMjVraEAA2oAPUcbmp/t7gk9uyPhRy1xRKrdOtLuxWaQVOoWkIKeOjGkhGxerbxh76IFPbm80kqInKscIFIkUrdvtIKe+jHkLIuis6cWbZUH17RxvU9WKuipK0NMVKjwe45XAkDQc4IfSUMtt1fQgwAIegAIegAIegAIelATAYIeAIKeBs9rKj1OyDlmJmYhISfMLBo7lDQZoOHoESEnrKNORSwZHpjeVp6QYSkqEVJg1ByAhqPHOVYhp6P21X/7T21LvrAzkc3rSEjmTctfPKf/E2f2M5EraqVwyAs4oOHqidkDnaFbV0147PlMd3+InCFnSfEf/pZe8ahbcEb2h1fuP3tW3vZ7GoaCexI9fD3bdsXOWzr9gSfH9xfKynaOSckpHcmJY8OedJty39Mvtc6/cfovH2/TSWMtw0QgR6Bh6uGI27MvctmtU3oL4ZDrnDVz5pJrF51/3pxxY8fk84WtL+1c89Dvn3jqGT+R+uZdHemY/fxFPTbnaY1xKFCAhv2NXVjLjavbD/ZFPen+xte/fOePbkgm4wP/l0m3TDp5whcWLrh39SM333JnNOovfaD9gjPymaQRw4yRKCiHsGHqsY5V3D33YnL9llaPsueec9bqlbckk3FjjHMykLXWWnv9NV+59qqvlYq9bxz016wfw76zDnwCAujdvcNO+GqhEGn5zYZ01bBSdMcPlhKRMdbzPKV4IK01s7LWLr/pqskdJ2sqPbYpXc1rHMKCMwKxCuffXlnq+iN7aaVsrqBT/pCuNSvPlfq8za/FlSueNvXUeR8/XUT0MRcNlWIibk0l518wz5nCngPR3W9FOOwcBqFgABIRz5+uvAyTqVR5yvjKn3+8e+7Mgun7ID0ixIqKBXUoF3K2curk9kgkIiLHPbUZOJydPmOKOJsvqf/2eKQJQ1Bwvsbr6BRWESZnLI9vNdMnlajCCgMEAA3pEMZcPPiwrex3FIlH7YZ/xS++aVq2pFTEufe/ZsNM4siPubHJqtLh19/8T7lcZmY53v0xA+dDO1/Zw0rHo25C2pAl+AzMIczG278Vis8W02tdKNNiXtgZ/9zyqdmCUtEPMuSMiraYc07LO+W/tvv1Ldt3MrO17phrRUIkvdncc89vUV5syvjS1EllqShMawQDEJNUlU4mO5Z5sZli+4z1xqTMxpeHYIiJLH/1wp6QJ87R9277GRF5nj7qa7yI01qv+MmaN/fusxT90vk9objF9eggnQMpkdK7uwjaXNUMyZBW4vJq/tm5hfN6DaX+sXnrNUtuz+XyR32N11rfu/qR+9c8HPVbTxlXvGphlxQVZsRO4Ay1Ee6NZyLDyg+3nG8KL7vK2478RMy8si+6cUfiixf2+r5zVXXsTjoiTIrOnVH47TOpsotv3fri+ic3RsJh348opTu7ep7ZsPk7y+5e9YtfRf1EoageumHv3Fl5V9SjtbTDCauo27g9+ZftSd8nZ8uh+OxQfHY9P1ijgXZpdcyD++KawiuskyHPdGW9T83K/2nF7lTMuZJS+n0nU6+4/dQ3O/2w6jfVUro1lUzGy+XKoc5uIsVeymN7/+K3rlzYaftGcyLMWPZazR0PTvz+gxMzaamW+/xxi/xxi8Rk63b31gaajVdH7O4+tGOZUuIKeu7Mwt9/9urVnz2QiEWcbuvK8ht7c/sPVQxnvEjLp+f0PnfXq1de1olp1GHUWOuB3jU0MA5VKXnY0PuNQwOGxqfM6u/uvfGKQ0cuKDs4sKCMiBwWAzUBoOEbEsMu502fXJ4+vXi9OTS4Y9MRS1qhJ+CHsI90LGMmrcSV2fR6Nq9dSbmCMlnPFhQzFkQ3F6BhGiIixeRp0UoG9o33NG7JaFJAwzeEAAiGAOj/aAjzEgD0kQxpzG0B0IkbCo1pMc/vil1y87Qde3ydsAaGAOhEDPVVbSidsFv2+JfcPG3brpjXYoyBIQAaqqGZYnuM9VrjtregLl0+ddvLcS8FQwA0JEN+cvJtkfRnxGaN9WJR11iGnADQKBuqEOv4SUsjmUvF9trGMSRCQhQLy3vW9DMAjcYfJUZcIT7xukjmskYxJEJKCzt6cbevQ++s3hYDQKP1d4m4YqMYEiHHpONuyd0dv/5rOhkfuDtWqfB4Ikd1fKN1gKeCuFEMDerx3eJ7Jq1a25ZuMc5psQUVnhBOnieuVM8HsmDPJTaAocN6lrzzMHnrtEiJdSJx8rdZxUgMAMHQh+tZtbYtkzbGaXGHL0bMEinV+WfUDKsZ6tTQh+mZIaav/j+gJlkOU3eGhqAnV7cL6ZsQUH0ZCoyepgJUL4aCpKfZAI2+oYDpoSZ4bvzxDZGYcMsnne01hR1CsUjY5orqdxvSF5/Z3z6pXC1qIhLhEf0hcSyKtO8Wv/ONvdH1UEPdmTrCY8Fxt15Mx+z62/ecNaefSqomozPT4nuCo6eZAR3fUL6ox6XMyuv2ZRKWLDOP2My4c6x89+jT6fvWtWVaA6KnyQEdx5BStmq4WGZWI/3AZB58wWTMOqePWP7WsHqoYZ/WM/Ln1ERU7n7cUaunJRUXqdnvsxISKQZDDwAdZYhLXetYRdzg4FSbr71SUd6YRMeyAOgBoCMMxSZe7UWnVvo21XD5hFgVGhttu1yH2wOgB+dAR50PEas4kaPa7vKrRar1vGcURqBhj0Mktp+YarZ8QoiYRIg5GHoA6FhFqtZGKVjPccHmFAiAEAAhAEIAhBAAIQBCAIQACCEAQgCEAAgBEEIAhAAIARACIIQACAEQAiAEQAiAEAIgBEAIgBAAIQRACIAQACEAQgiAEAAhAEIAhBAAIQBCAIQACAEQQgCEAAgBEAIghAAIARACIARACAEQAiAEQAiAEAIgBEAIgBAAIUT/A6+kHA4D5yedAAAAAElFTkSuQmCC"

write_png "public/icons/icon-512.png" "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"

write_png "src/app/apple-icon.png" "iVBORw0KGgoAAAANSUhEUgAAALQAAAC0CAIAAACyr5FlAAAKGElEQVR42u3dbYxcVR3H8f//nHPnefaBbiHFdrvt1hZooKWhMTVYhSgJFiHBpIloUiz1hYkBEkBFt6LSFwolgC/0hS1arSFCRFutJj7QRJuggVgeS6kULGzbQJduuzNzZ2bvOefvi22Wlnbpg7Pde+f+vpmXm53kzmfOvffcO/dw76d2E0KnSmETIOBAwIGAAwEHAg4EHAg4EHAg4EDAgRBwIOBAwIGAAwEHAg4EHAg4EHAg4EAIOBBwIOBAwIGAAwEHAg4EHAg4EHAgBBwIOBBwIOBAwIGAAwEHAg4EHAg4EHAgBBwIOBBwIOBAwIGAAwEHAg4EHCh9mdRvAU8ik/KPmZP+3UszDiFiVgXiydkIYsU3xt4FOJI2YHBAxFHlOVvfQ2yIWjh+MIk1+fmmtJhISKKEDiHpxOGZs97XaoPro9pLJG5ydis6KF5enHm3UkWRZhJ9cPrWlfXMWfFh5a11NnxVmU6lhFp+1MHkPXt71BQuLfcOsCok0UfacBwv4zVlyiKuUldKtXiv4j2V855Ze1sxhQUJ9ZEqHCfI0EHZe1dvqofWHFg0P/RNpbgFQLywyvoX9hTu2nBxPuuV0i5Kqg+TZhnVutp4x9u33nyIGqqVpxRCy5eOlPPutkdnlfJOB2UbvlZ5a13ifKRk5Di1jMfufHvVTUPRYaNa/WF5T8EFdtOWntWPzCrlkzp+6M6+r6VZhh02gRHF1NqXVmRDvWRxta/bPrmjKzBem5xrHrDhrkzHMlZ5Ihv/+Y+2x3EaGUbLJL2xSr6P9sYxZTLaw0cb45hiGW3go11xxEJG0n20JY4YyTgTHxRXH+2HI3YyPtTHfhvuznYsIxUQ+bj5aDMcMZVxSh9Ge6ULtrFPZS4KigtJmnHDoSDjfGa02GGz6qZDG28ftI6JPKtMVH2OJI67FQUZ53usVuIr+pZPDl/YZSPHzBLbbaogY0r2L9W6Eon7ZlWQMVU+4p+CDNSWOCADOCADOCADOCADOCAj+Zk0yBifUWDGJ96eOM5ahgg5z0qJMkJEJOwsE5FSAiTthOOsZXjPKvAm7yjikeHAecplJN8VERPVtPfJmIYCjtbLcJ510Q4NZX752wu2v9ixe38+slzMuSv6whuWHlm5/IjJeVfXGgcoCcdx9jIc6y67edu0e382c3DIUCMkqhAJkXrltdyv/zFn/VPhxjv3Xbmw5kYMfCQXxznJ6LCbtvaseXS2tWEp37zq45d/bOmizo7S4P53/vXs8y+9vGfn66UV983b9v3Xr1wQ+lArBR/Jw3FOMspu6/bu1Y/0Bbq6cGHfA+vuuu7aZeN/0BwdfewXv1v3wx+/e7i54r7+Hev3zJkx6kdb80NIzHPE+NyESGlphOp7j88Q35g5Y/pftv70umuXee+tc9Y651wmCL66ZuXmjQ9mzejBoeDBJy7irBcPBknCIcxZ8fWzms9wjrnofr+j6/k3C1pq96+9fXpP9+hopJQyWhujtdZENDoaXbN86aov3kx2+Ilnpr2xN69z3uPcNiE4hFh7Xx3571ob7lZBObJupKZPO9M19vH+9cUOX29eckn/TSuu8SJBcMJ+k5m11iKyZtXnyx254aO845UiZb3H4JEQHEzimTNB8TJWWfE+0PT4N/atuuE0s+PMQo4PDgdkRz/aP7tQyJEInzQnqhQz89w5My+cfoE07f73soRRI1G7Fc8qp3NziMkL5TN+8dw6CRGOGrFbIQ68PRy+s1m8NVodrurlX5+389Wi6bTWTvg1F2HSMqM7IpP5z959YdggZpGTZ05FRN54c/DdQ4c5az4yrQlzydqtRMp0l3u/pXSHs41Cjkfq6vqB/p27PszH2Ef86StGVD67e/feLdu2K+YosicCEuccM2/Y9JvKSKO7U65eWKOmwlR6gnYrSnzDFC4t9X6bdcFGzWKOj4Sn8aG1SE1/7uoji+eEjotr7//RoaHhTCY4/lSWiDKZYPvfn930q6fIdK9c9t7c/rprYJ4jYfMcSuzIsUfh6EJ0Bj6YyDvOFfx9XzjIKjd48NBnbvzKn59+5vhT2dEo+smGJ7502z1Nm5nRE92z8h1pKsawMdEYHuvHPoljc+yBWuLCIMjWGtJV8H9at/fKy2r2qDFmgunzP4xPn8tVSz44fT7qSzOm0VRNn4sQGzkyYhbdPn+okjFcNcUl5d4B8Y24/egt9s8EOzcfH7zw1hybQSXOqUJ+Ud9UXngDjqn2MX7J/m8TXLLPTNkle+CYeh9jN/tQ3sftZp8E4UjIwRhrGX8U8JkdnyolYtkeNb6hOsq2u9Pmc95VjasYIdwG1k44zskHMxktikksi2VxpJVo3EDahjjOyce4krEXal8c/4cPlAIcZ+Ajgo/04pjYx2cH+nfuKgbd1jr4SC2OCXwMh2rFd+Y+/c8OU7YOPtKL40QfSheiqFHI8dG6+sy9/Zu29WiMH6nGcZyPUu+AMl02qmeMKhX86odnbdrSY+Aj1TjGfLiKyc/rmPuAyc9zUVUpXSr41Y/E2ocX4DhPaXGhMl3l3gFTWOCiilK6lI+vD+8pnxGlxu9BY+CY7PGjzqoQfx/OsSr6l/flhis6GLtbQEaBY/J9SDPmPqxl02l3vlK88f6+UcuKSYSC0lVEKob3T7fZBSgVZx/HZOwqXj/QP1zTuQw711BmWqbzEyIRVk04HwMIkWWVz3Qss+Eu1zygTS4w/skdXX3ddsniqg31lFySPV7GkVAVc2xtk3Wx3Huvzl5MsVwSsC3XW4mdj5NlRFGT9dgId4n4GpGO43F+m67UFCMf1rHptv9+ubhi7ckyFoitEOt4bsQ2XuMtFj6sY9NlN/9x2i0/6Ks2VT7HNiEyqN1Xh5xiH2NjxqatPV9+aDZryWa0jULWxXLv2vjLoBSsKztlPo7J2NKz+uFZpYI3Wjtb1bk55VnfNPl54qoxl0HpWJH6ND6imiZikVa+nOP3lysvvL9cecfs76rMheJq8ZdBqVnLniZ6VNDGO96+9eZD1FCtnGUQopz/+VPTb3v0VAvZ+0YiZKQKx6l91JvqoTUHFs0PfbM1v5j1wirrX9hTuGvDxfnsSTJiOZ8BHKfwoUxZxFXqSrV28prJeyrnPbP2NqkyUojjAz5eVaZTKWn9ZQ0m79nbo6ZwaUJlpBPHMR/e12qD66PaSyRucjatDoqXF2ferVQxiTJSi4OIPHFAxLb6vK3vITYt3q+INfn5prSYSEiihF7gTC2OsZMKZpUjnpwn9YoV3xh7l4RuIEPpjYlIfEiTtMArM5GiJD+rMM04xlJ41OTEmwYh4EDAgYADAQcCDgQcCDgQcCDgQMCBEHAg4EDAgYADAQcCDgQcCDgQcCDgQAg4EHAg4EDAgYADAQcCDgQcCDgQcCDgwCZAwIGAAwEHAg4EHAg4EHAg4EDAgYADIeBAwIGAAwEHAg4EHAg4EHAg4ECp63/GqJe6FdQoMAAAAABJRU5ErkJggg=="


echo ""
echo "Done. Old versions of changed files are in $BACKUP/."
echo "Restart the dev server (Ctrl + C, then npm run dev) and open http://localhost:3000"
