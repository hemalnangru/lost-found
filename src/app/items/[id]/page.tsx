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
