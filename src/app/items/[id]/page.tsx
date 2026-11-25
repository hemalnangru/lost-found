"use client";
import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import dynamic from "next/dynamic";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { useT } from "@/lib/i18n";
import TicketBand from "@/components/TicketBand";
import MapLoading from "@/components/MapLoading";
import type { MapPoint } from "@/components/MapView";

const MapView = dynamic(() => import("@/components/MapView"), {
  ssr: false,
  loading: () => <MapLoading />,
});

type Item = {
  id: string;
  user_id: string | null;
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
  const { t, td, lang } = useT();
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [me, setMe] = useState<string | null>(null);
  const [chatBusy, setChatBusy] = useState(false);
  const [chatError, setChatError] = useState("");
  const [item, setItem] = useState<Item | null>(null);
  const [loading, setLoading] = useState(true);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setMe(data.session?.user.id ?? null));
    supabase
      .from("items")
      .select("id,user_id,type,title,description,category,color,city,lat,lng,event_date,status,image_url")
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

  async function startChat() {
    setChatBusy(true);
    setChatError("");
    const { data, error } = await supabase.rpc("start_conversation", { p_item: id });
    setChatBusy(false);
    if (error) return setChatError(error.message);
    router.push(`/messages/${data as string}`);
  }

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(window.location.href);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      setCopied(false);
    }
  }

  if (loading) return <main className="max-w-4xl mx-auto px-5 py-8">{t("detail.loading")}</main>;

  if (!item) {
    return (
      <main className="max-w-4xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">{t("detail.notFound")}</h1>
        <p className="mb-4 text-ink-soft">{t("detail.notFoundText")}</p>
        <Link href="/items" className="btn btn-primary">
          {t("detail.browse")}
        </Link>
      </main>
    );
  }

  const rows: [string, string][] = [
    [t("detail.category"), td(`cat.${item.category}`, item.category)],
    [t("detail.colour"), item.color || t("detail.notGiven")],
    [t("detail.city"), item.city || t("detail.notGiven")],
    [item.type === "lost" ? t("detail.lostOn") : t("detail.foundOn"), formatDate(item.event_date, lang)],
    [t("detail.status"), td(`status.${item.status}`, item.status)],
  ];

  return (
    <main className="max-w-4xl mx-auto px-5 py-8">
      <Link href="/items" className="text-sm text-rail-dark underline">
        {t("detail.back")}
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
              {t("common.noPhoto")}
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
                {t("detail.claim")}
              </Link>
            )}
            {me && item.user_id && item.user_id !== me && (
              <button type="button" onClick={startChat} disabled={chatBusy} className="btn">
                {chatBusy
                  ? t("detail.opening")
                  : item.type === "found"
                  ? t("detail.msgFinder")
                  : t("detail.msgOwner")}
              </button>
            )}
            {!me && (
              <Link href="/login" className="btn">
                {t("detail.loginToMsg")}
              </Link>
            )}
            <button type="button" onClick={copyLink} className="btn">
              {copied ? t("detail.copied") : t("detail.copy")}
            </button>
          </div>
          {chatError && (
            <p role="alert" className="mx-5 mb-5 rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
              {chatError}
            </p>
          )}
        </article>

        <aside className="space-y-4">
          <div className="panel">
            <h2 className="font-display font-bold text-xl mb-3">{t("detail.details")}</h2>
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
            <div className="panel text-sm text-ink-soft">{t("detail.noPin")}</div>
          )}
        </aside>
      </div>
    </main>
  );
}
