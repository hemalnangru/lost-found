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
