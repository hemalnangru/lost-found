#!/bin/bash
# Adds the English/Hindi language switch and translates every page.
# Run it from inside the lost-found folder (the one with package.json).
set -e

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "Run this inside the lost-found folder (the one that has package.json)."
  exit 1
fi

BACKUP="backup-before-language"
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

write "src/app/claim/[id]/page.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { useT } from "@/lib/i18n";

export default function ClaimPage() {
  const { t } = useT();
  const { id } = useParams<{ id: string }>();
  const [loggedIn, setLoggedIn] = useState<boolean | null>(null);
  const [question, setQuestion] = useState<string | null>(null);
  const [loadingQ, setLoadingQ] = useState(true);
  const [answer, setAnswer] = useState("");
  const [contact, setContact] = useState<string | null>(null);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setLoggedIn(!!data.session));
    supabase.rpc("get_claim_question", { p_item: id }).then(({ data }) => {
      setQuestion((data as string | null) ?? null);
      setLoadingQ(false);
    });
  }, [id]);

  async function verify(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setMessage("");
    const { data, error } = await supabase.rpc("verify_claim", { p_item: id, p_answer: answer });
    setBusy(false);
    if (error) return setMessage(error.message);
    if (data) setContact(data as string);
    else setMessage(t("claim.wrong"));
  }

  if (loadingQ || loggedIn === null) {
    return <main className="max-w-md mx-auto px-5 py-12">{t("common.loading")}</main>;
  }

  return (
    <main className="max-w-md mx-auto px-5 py-12">
      <div className="ticket">
        <div className="ticket-band ticket-band-ink">
          <span className="ticket-hole" aria-hidden="true" />
          <span>{t("claim.title")}</span>
        </div>

        <div className="p-5">
          {!loggedIn ? (
            <>
              <p className="mb-4 text-ink-soft">{t("claim.loginPrompt")}</p>
              <Link href="/login" className="btn btn-primary">{t("nav.login")}</Link>
            </>
          ) : !question ? (
            <p className="text-ink-soft">{t("claim.noQuestion")}</p>
          ) : contact ? (
            <div className="rounded-xl border-[1.5px] border-found bg-found-tint p-4">
              <p className="font-bold text-found-dark">{t("claim.verified")}</p>
              <p className="mt-1 text-2xl font-display font-extrabold break-words">{contact}</p>
            </div>
          ) : (
            <form onSubmit={verify} className="space-y-4">
              <p className="text-sm text-ink-soft">{t("claim.intro")}</p>
              <p className="font-display font-bold text-xl leading-snug">{question}</p>
              <div>
                <label className="label" htmlFor="answer">{t("claim.yourAnswer")}</label>
                <input id="answer" className="field w-full" required value={answer}
                  onChange={(e) => setAnswer(e.target.value)} />
              </div>
              <button disabled={busy} className="btn btn-primary w-full">
                {busy ? t("claim.checking") : t("claim.verifyBtn")}
              </button>
              {message && (
                <p role="alert" className="rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
                  {message}
                </p>
              )}
            </form>
          )}
        </div>
      </div>
    </main>
  );
}
__LF_EOF__

write "src/app/globals.css" <<'__LF_EOF__'
@import "tailwindcss";

@theme inline {
  --color-paper: #f3f6fb;
  --color-card: #ffffff;
  --color-ink: #0e1a3a;
  --color-ink-soft: #4a5675;
  --color-rail: #1e40d8;
  --color-rail-dark: #162fa3;
  --color-rail-tint: #e8eeff;
  --color-signal: #ffc20e;
  --color-lost: #c23b20;
  --color-lost-dark: #9c2f16;
  --color-lost-tint: #fde9e4;
  --color-found: #14815a;
  --color-found-dark: #0d6544;
  --color-found-tint: #dff3ea;
  --color-line: #d7deec;
  --color-line-strong: #aab6d3;
  --font-display: var(--font-archivo), var(--font-deva), "Arial Narrow", system-ui, sans-serif;
  --font-sans: var(--font-figtree), var(--font-deva), system-ui, sans-serif;
}

:root {
  color-scheme: light;
}

html,
body {
  background: var(--color-paper);
  color: var(--color-ink);
}

body {
  font-family: var(--font-figtree), var(--font-deva), system-ui, sans-serif;
  line-height: 1.55;
}

@layer base {
  h1,
  h2,
  h3 {
    font-family: var(--font-archivo), var(--font-deva), "Arial Narrow", system-ui, sans-serif;
    letter-spacing: -0.01em;
  }
  :focus-visible {
    outline: 3px solid var(--color-signal);
    outline-offset: 2px;
  }
}

@layer components {
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.6rem 1.15rem;
    border: 1.5px solid var(--color-ink);
    border-radius: 10px;
    background: var(--color-card);
    color: var(--color-ink);
    font-weight: 600;
    font-size: 0.95rem;
    line-height: 1.2;
    cursor: pointer;
    transition: transform 0.12s ease, box-shadow 0.12s ease, background 0.12s ease;
  }
  .btn:hover {
    background: var(--color-rail-tint);
  }
  .btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
  .btn-primary {
    background: var(--color-rail);
    color: #fff;
    box-shadow: 3px 3px 0 var(--color-ink);
  }
  .btn-primary:hover {
    background: var(--color-rail-dark);
    transform: translate(1px, 1px);
    box-shadow: 2px 2px 0 var(--color-ink);
  }
  .btn-primary:active {
    transform: translate(3px, 3px);
    box-shadow: 0 0 0 var(--color-ink);
  }
  .btn-small {
    padding: 0.35rem 0.8rem;
    font-size: 0.85rem;
    border-radius: 8px;
  }
  .btn-danger {
    border-color: var(--color-lost);
    color: var(--color-lost-dark);
  }
  .btn-danger:hover {
    background: var(--color-lost-tint);
  }

  .label {
    display: block;
    margin-bottom: 0.3rem;
    font-size: 0.875rem;
    font-weight: 600;
  }
  .field {
    display: block;
    padding: 0.6rem 0.8rem;
    border: 1.5px solid var(--color-line-strong);
    border-radius: 10px;
    background: var(--color-card);
    color: var(--color-ink);
    font: inherit;
  }
  .field::placeholder {
    color: #7a86a3;
  }
  .field:focus {
    outline: none;
    border-color: var(--color-rail);
    box-shadow: 0 0 0 3px var(--color-rail-tint);
  }

  .panel {
    background: var(--color-card);
    border: 1.5px solid var(--color-ink);
    border-radius: 14px;
    padding: 1.25rem;
  }

  .ticket {
    background: var(--color-card);
    border: 1.5px solid var(--color-ink);
    border-radius: 14px;
    overflow: hidden;
  }
  .ticket-band {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    padding: 0.55rem 0.9rem;
    color: #fff;
    font-weight: 700;
  }
  .ticket-band-lost {
    background: var(--color-lost);
  }
  .ticket-band-found {
    background: var(--color-found);
  }
  .ticket-band-ink {
    background: var(--color-ink);
  }
  .ticket-hole {
    flex-shrink: 0;
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: var(--color-paper);
    border: 1.5px solid var(--color-ink);
  }
  .ticket-ref {
    margin-left: auto;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 0.75rem;
    font-weight: 500;
  }
  .ticket-perf {
    border-top: 2px dashed var(--color-line-strong);
  }

  .chip {
    display: inline-block;
    padding: 0.1rem 0.65rem;
    border-radius: 999px;
    background: var(--color-rail-tint);
    color: var(--color-rail-dark);
    font-size: 0.78rem;
    font-weight: 600;
  }
  .chip-lost {
    background: var(--color-lost-tint);
    color: var(--color-lost-dark);
  }
  .chip-found {
    background: var(--color-found-tint);
    color: var(--color-found-dark);
  }

  .segmented {
    display: inline-flex;
    border: 1.5px solid var(--color-ink);
    border-radius: 12px;
    overflow: hidden;
    background: var(--color-card);
  }
  .segmented button {
    flex: 1;
    padding: 0.55rem 1.1rem;
    font-weight: 600;
    cursor: pointer;
  }
  .segmented button + button {
    border-left: 1.5px solid var(--color-ink);
  }
  .segmented button[aria-pressed="true"] {
    background: var(--color-ink);
    color: #fff;
  }

  .segmented-sm button {
    padding: 0.25rem 0.7rem;
    font-size: 0.85rem;
  }

  .score {
    flex-shrink: 0;
    display: grid;
    place-items: center;
    width: 64px;
    height: 64px;
    border-radius: 50%;
    background: conic-gradient(var(--color-rail) calc(var(--p) * 1%), var(--color-line) 0);
  }
  .score > span {
    display: grid;
    place-items: center;
    width: calc(100% - 12px);
    height: calc(100% - 12px);
    border-radius: 50%;
    background: var(--color-card);
    font-family: var(--font-archivo), var(--font-deva), system-ui, sans-serif;
    font-weight: 800;
    font-size: 0.95rem;
  }

  .match-stamp {
    padding: 0.4rem 0.95rem;
    border: 2px solid var(--color-ink);
    border-radius: 999px;
    background: var(--color-signal);
    color: var(--color-ink);
    font-family: var(--font-archivo), var(--font-deva), system-ui, sans-serif;
    font-weight: 800;
    transform: rotate(-6deg);
    box-shadow: 3px 3px 0 var(--color-ink);
  }
}

@media (prefers-reduced-motion: reduce) {
  * {
    transition: none !important;
  }
}
__LF_EOF__

write "src/app/items/[id]/page.tsx" <<'__LF_EOF__'
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
__LF_EOF__

write "src/app/items/page.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useMemo, useState } from "react";
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
  const { t, td, lang } = useT();
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

  const typeOptions: [string, string][] = [
    ["all", t("common.all")],
    ["lost", t("common.lost")],
    ["found", t("common.found")],
  ];
  const viewOptions: [string, string][] = [
    ["list", t("items.list")],
    ["map", t("items.map")],
  ];

  return (
    <main className="max-w-6xl mx-auto px-5 py-8">
      <div className="flex flex-wrap items-end justify-between gap-4 mb-6">
        <div>
          <h1 className="font-display font-extrabold text-3xl">{t("items.title")}</h1>
          <p className="text-ink-soft">
            {loading
              ? t("items.loading")
              : t(items.length === 1 ? "items.shownOne" : "items.shownMany", { n: items.length })}
          </p>
        </div>
        <Link href="/report" className="btn btn-primary">
          {t("common.reportItem")}
        </Link>
      </div>

      <div className="panel flex flex-wrap items-center gap-3 mb-6">
        <div className="segmented" role="group" aria-label={t("items.typeAria")}>
          {typeOptions.map(([v, l]) => (
            <button key={v} type="button" aria-pressed={type === v} onClick={() => setType(v)}>
              {l}
            </button>
          ))}
        </div>
        <select
          className="field"
          aria-label={t("items.categoryAria")}
          value={category}
          onChange={(e) => setCategory(e.target.value)}
        >
          <option value="all">{t("items.allCategories")}</option>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {td(`cat.${c}`, c)}
            </option>
          ))}
        </select>
        <input
          className="field"
          aria-label={t("items.cityAria")}
          placeholder={t("items.cityPh")}
          value={city}
          onChange={(e) => setCity(e.target.value)}
        />
        <div className="segmented sm:ml-auto" role="group" aria-label={t("items.viewAria")}>
          {viewOptions.map(([v, l]) => (
            <button key={v} type="button" aria-pressed={view === v} onClick={() => setView(v)}>
              {l}
            </button>
          ))}
        </div>
      </div>

      {!loading && items.length === 0 && (
        <div className="panel">
          <p className="font-semibold">{t("items.emptyTitle")}</p>
          <p className="text-ink-soft">
            {t("items.emptyText")}
            <Link href="/report" className="text-rail-dark underline">
              {t("items.emptyLink")}
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
            {t("common.lost")}{" "}
            <span className="ml-3 inline-block h-3 w-3 rounded-full bg-found border border-ink align-middle" />{" "}
            {t("common.found")}. {t("items.pins", { pins: points.length, total: items.length })}
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
                  {t("common.noPhoto")}
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
                <span className="chip mt-3">{td(`cat.${it.category}`, it.category)}</span>
              </div>
              <div className="ticket-perf mx-4" />
              <div className="px-4 py-3 flex items-center justify-between gap-2 text-sm">
                <span className="text-ink-soft">
                  {it.city ?? t("common.unknownCity")}, {formatDate(it.event_date, lang)}
                </span>
                <span className={`chip ${it.type === "lost" ? "chip-lost" : "chip-found"}`}>
                  {td(`status.${it.status}`, it.status)}
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
__LF_EOF__

write "src/app/login/page.tsx" <<'__LF_EOF__'
"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { useT } from "@/lib/i18n";

export default function LoginPage() {
  const { t } = useT();
  const router = useRouter();
  const [mode, setMode] = useState<"login" | "signup">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    const { error } =
      mode === "login"
        ? await supabase.auth.signInWithPassword({ email, password })
        : await supabase.auth.signUp({ email, password });
    setLoading(false);
    if (error) return setError(error.message);
    router.push("/report");
  }

  const title = mode === "login" ? t("login.logIn") : t("login.create");

  return (
    <main className="max-w-md mx-auto px-5 py-12">
      <div className="ticket">
        <div className="ticket-band ticket-band-ink">
          <span className="ticket-hole" aria-hidden="true" />
          <span>{title}</span>
        </div>
        <form onSubmit={submit} className="p-5 space-y-4">
          <div>
            <label className="label" htmlFor="email">{t("login.email")}</label>
            <input id="email" className="field w-full" type="email" placeholder="name@example.com"
              required value={email} onChange={(e) => setEmail(e.target.value)} />
          </div>
          <div>
            <label className="label" htmlFor="password">{t("login.password")}</label>
            <input id="password" className="field w-full" type="password"
              placeholder={t("login.passPh")} required minLength={6} value={password}
              onChange={(e) => setPassword(e.target.value)} />
          </div>
          <button disabled={loading} className="btn btn-primary w-full">
            {loading ? t("login.wait") : title}
          </button>
          {error && (
            <p role="alert" className="rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
              {error}
            </p>
          )}
        </form>
        <div className="ticket-perf mx-5" />
        <div className="p-5 text-sm">
          {mode === "login" ? t("login.newHere") : t("login.already")}
          <button type="button" className="font-semibold text-rail-dark underline"
            onClick={() => setMode(mode === "login" ? "signup" : "login")}>
            {mode === "login" ? t("login.createLink") : t("login.logIn")}
          </button>
        </div>
      </div>
    </main>
  );
}
__LF_EOF__

write "src/app/messages/[id]/page.tsx" <<'__LF_EOF__'
"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { formatTime } from "@/lib/format";
import { useT } from "@/lib/i18n";

type Msg = {
  id: string;
  conversation_id: string;
  sender_id: string;
  body: string;
  created_at: string;
};

type Conv = {
  id: string;
  item_id: string;
  owner_id: string;
  starter_id: string;
  items: { title: string; type: string } | null;
};

function merge(prev: Msg[], incoming: Msg[]) {
  const map = new Map(prev.map((m) => [m.id, m]));
  for (const m of incoming) map.set(m.id, m);
  return [...map.values()].sort((a, b) => a.created_at.localeCompare(b.created_at));
}

export default function ChatPage() {
  const { t, lang } = useT();
  const { id } = useParams<{ id: string }>();
  const [me, setMe] = useState<string | null>(null);
  const [conv, setConv] = useState<Conv | null>(null);
  const [messages, setMessages] = useState<Msg[]>([]);
  const [text, setText] = useState("");
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const boxRef = useRef<HTMLDivElement | null>(null);

  const loadMessages = useCallback(async () => {
    const { data } = await supabase
      .from("messages")
      .select("id,conversation_id,sender_id,body,created_at")
      .eq("conversation_id", id)
      .order("created_at", { ascending: true });
    if (data) setMessages((prev) => merge(prev, data as Msg[]));
  }, [id]);

  useEffect(() => {
    async function init() {
      const { data: s } = await supabase.auth.getSession();
      setMe(s.session?.user.id ?? null);
      if (!s.session) return setLoading(false);

      const { data } = await supabase
        .from("conversations")
        .select("id,item_id,owner_id,starter_id,items(title,type)")
        .eq("id", id)
        .maybeSingle();
      setConv((data as unknown as Conv | null) ?? null);
      await loadMessages();
      setLoading(false);
    }
    init();
  }, [id, loadMessages]);

  // live updates, plus a slow refresh as a safety net
  useEffect(() => {
    const channel = supabase
      .channel(`chat-${id}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "messages", filter: `conversation_id=eq.${id}` },
        (payload) => setMessages((prev) => merge(prev, [payload.new as Msg]))
      )
      .subscribe();
    const timer = setInterval(loadMessages, 10000);
    return () => {
      clearInterval(timer);
      supabase.removeChannel(channel);
    };
  }, [id, loadMessages]);

  useEffect(() => {
    const el = boxRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [messages]);

  async function send(e: React.FormEvent) {
    e.preventDefault();
    const body = text.trim();
    if (!body || !me) return;
    setSending(true);
    setError("");
    const { data, error } = await supabase
      .from("messages")
      .insert({ conversation_id: id, sender_id: me, body })
      .select("id,conversation_id,sender_id,body,created_at")
      .single();
    setSending(false);
    if (error) return setError(error.message);
    setMessages((prev) => merge(prev, [data as Msg]));
    setText("");
  }

  if (loading) return <main className="max-w-2xl mx-auto px-5 py-8">{t("chat.loading")}</main>;

  if (!me) {
    return (
      <main className="max-w-2xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">{t("msg.title")}</h1>
        <p className="mb-4 text-ink-soft">{t("chat.loginPrompt")}</p>
        <Link href="/login" className="btn btn-primary">{t("nav.login")}</Link>
      </main>
    );
  }

  if (!conv) {
    return (
      <main className="max-w-2xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">{t("chat.notFound")}</h1>
        <p className="mb-4 text-ink-soft">{t("chat.notFoundText")}</p>
        <Link href="/messages" className="btn btn-primary">{t("chat.back")}</Link>
      </main>
    );
  }

  const otherLabel =
    me === conv.owner_id
      ? t("msg.someone")
      : conv.items?.type === "found"
      ? t("msg.finder")
      : t("msg.owner");

  return (
    <main className="max-w-2xl mx-auto px-5 py-8">
      <Link href="/messages" className="text-sm text-rail-dark underline">
        {t("chat.back")}
      </Link>

      <div className="ticket mt-4">
        <div className="ticket-band ticket-band-ink">
          <span className="ticket-hole" aria-hidden="true" />
          <span>{otherLabel}</span>
        </div>
        <div className="px-4 py-3 text-sm border-b-[1.5px] border-ink">
          {t("chat.about")}
          <Link href={`/items/${conv.item_id}`} className="font-semibold text-rail-dark underline">
            {conv.items?.title ?? t("chat.thisReport")}
          </Link>
          . {t("chat.privacy")}
        </div>

        <div ref={boxRef} className="h-[26rem] overflow-y-auto bg-paper p-4 space-y-3" aria-live="polite">
          {messages.length === 0 && (
            <p className="text-center text-sm text-ink-soft pt-10">{t("chat.empty")}</p>
          )}
          {messages.map((m) => {
            const mine = m.sender_id === me;
            return (
              <div key={m.id} className={`flex ${mine ? "justify-end" : "justify-start"}`}>
                <div className={`max-w-[80%] rounded-2xl px-4 py-2 border-[1.5px] border-ink ${
                  mine ? "bg-rail text-white" : "bg-card"
                }`}>
                  <p className="whitespace-pre-wrap break-words">{m.body}</p>
                  <p className={`mt-1 text-xs ${mine ? "text-white/80" : "text-ink-soft"}`}>
                    {formatTime(m.created_at, lang)}
                  </p>
                </div>
              </div>
            );
          })}
        </div>

        <form onSubmit={send} className="flex gap-2 p-3 border-t-[1.5px] border-ink bg-card">
          <input className="field flex-1" aria-label={t("chat.aria")}
            placeholder={t("chat.placeholder")} maxLength={1000} value={text}
            onChange={(e) => setText(e.target.value)} />
          <button disabled={sending || !text.trim()} className="btn btn-primary">
            {sending ? t("chat.sending") : t("chat.send")}
          </button>
        </form>
      </div>

      {error && (
        <p role="alert" className="mt-4 rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
          {error}
        </p>
      )}
    </main>
  );
}
__LF_EOF__

write "src/app/messages/page.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { formatTime } from "@/lib/format";
import { useT } from "@/lib/i18n";

type Conv = {
  id: string;
  item_id: string;
  owner_id: string;
  starter_id: string;
  created_at: string;
  items: { title: string; type: string } | null;
};

type Last = { body: string; created_at: string; sender_id: string };

export default function MessagesPage() {
  const { t, lang } = useT();
  const [me, setMe] = useState<string | null>(null);
  const [convs, setConvs] = useState<Conv[]>([]);
  const [last, setLast] = useState<Record<string, Last>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    async function load() {
      const { data: s } = await supabase.auth.getSession();
      setMe(s.session?.user.id ?? null);
      if (!s.session) return setLoading(false);

      const { data, error } = await supabase
        .from("conversations")
        .select("id,item_id,owner_id,starter_id,created_at,items(title,type)");
      if (error) {
        setError(error.message);
        return setLoading(false);
      }
      const list = (data as unknown as Conv[]) ?? [];

      const ids = list.map((c) => c.id);
      const latest: Record<string, Last> = {};
      if (ids.length > 0) {
        const { data: msgs } = await supabase
          .from("messages")
          .select("conversation_id,body,created_at,sender_id")
          .in("conversation_id", ids)
          .order("created_at", { ascending: false })
          .limit(300);
        for (const m of (msgs ?? []) as (Last & { conversation_id: string })[]) {
          if (!latest[m.conversation_id]) latest[m.conversation_id] = m;
        }
      }
      list.sort((a, b) =>
        (latest[b.id]?.created_at ?? b.created_at).localeCompare(
          latest[a.id]?.created_at ?? a.created_at
        )
      );
      setLast(latest);
      setConvs(list);
      setLoading(false);
    }
    load();
  }, []);

  function when(iso: string) {
    const d = new Date(iso);
    return d.toDateString() === new Date().toDateString()
      ? formatTime(iso, lang)
      : d.toLocaleDateString(lang === "hi" ? "hi-IN" : "en-IN", { day: "numeric", month: "short" });
  }

  if (loading) return <main className="max-w-2xl mx-auto px-5 py-8">{t("msg.loading")}</main>;

  if (!me) {
    return (
      <main className="max-w-2xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">{t("msg.title")}</h1>
        <p className="mb-4 text-ink-soft">{t("msg.loginPrompt")}</p>
        <Link href="/login" className="btn btn-primary">{t("nav.login")}</Link>
      </main>
    );
  }

  return (
    <main className="max-w-2xl mx-auto px-5 py-8">
      <h1 className="font-display font-extrabold text-3xl">{t("msg.title")}</h1>
      <p className="text-ink-soft mt-1 mb-6">{t("msg.sub")}</p>

      {error && (
        <p role="alert" className="mb-4 rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
          {error}
        </p>
      )}

      {convs.length === 0 && !error && (
        <div className="panel">
          <p className="font-semibold">{t("msg.none")}</p>
          <p className="text-ink-soft">
            {t("msg.noneText")}
            <Link href="/items" className="text-rail-dark underline">{t("msg.noneLink")}</Link>.
          </p>
        </div>
      )}

      <div className="space-y-3">
        {convs.map((c) => {
          const l = last[c.id];
          const who =
            me === c.owner_id
              ? t("msg.someone")
              : c.items?.type === "found"
              ? t("msg.finder")
              : t("msg.owner");
          return (
            <Link key={c.id} href={`/messages/${c.id}`} className="ticket block hover:bg-rail-tint">
              <div className="px-4 py-3">
                <div className="flex items-baseline justify-between gap-3">
                  <p className="font-display font-bold text-lg leading-snug">
                    {c.items?.title ?? t("common.report")}
                  </p>
                  <span className="text-xs text-ink-soft shrink-0">
                    {when(l?.created_at ?? c.created_at)}
                  </span>
                </div>
                <p className="text-sm text-ink-soft">{who}</p>
                <p className="mt-1 text-sm truncate">
                  {l ? `${l.sender_id === me ? t("msg.you") : ""}${l.body}` : t("msg.noMsgs")}
                </p>
              </div>
            </Link>
          );
        })}
      </div>
    </main>
  );
}
__LF_EOF__

write "src/app/my-reports/page.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { useT } from "@/lib/i18n";
import TicketBand from "@/components/TicketBand";

type Item = {
  id: string;
  type: string;
  title: string;
  category: string;
  city: string | null;
  event_date: string;
  status: string;
  image_url: string | null;
};

const STAGES = ["open", "matched", "claimed", "returned"];

export default function MyReportsPage() {
  const { t, td, lang } = useT();
  const [items, setItems] = useState<Item[]>([]);
  const [loggedIn, setLoggedIn] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    async function load() {
      const { data: s } = await supabase.auth.getSession();
      const uid = s.session?.user.id;
      setLoggedIn(!!uid);
      if (!uid) return setLoading(false);

      const { data, error } = await supabase
        .from("items")
        .select("id,type,title,category,city,event_date,status,image_url")
        .eq("user_id", uid)
        .order("created_at", { ascending: false });
      if (error) setError(error.message);
      setItems((data as Item[]) ?? []);
      setLoading(false);
    }
    load();
  }, []);

  async function advance(it: Item) {
    const next = STAGES[STAGES.indexOf(it.status) + 1];
    if (!next) return;
    setError("");
    const { error } = await supabase.from("items").update({ status: next }).eq("id", it.id);
    if (error) return setError(error.message);
    setItems(items.map((x) => (x.id === it.id ? { ...x, status: next } : x)));
  }

  async function remove(it: Item) {
    if (!window.confirm(t("mine.confirmDelete", { title: it.title }))) return;
    setError("");
    const { error } = await supabase.from("items").delete().eq("id", it.id);
    if (error) return setError(error.message);
    setItems(items.filter((x) => x.id !== it.id));
  }

  if (loading) return <main className="max-w-3xl mx-auto px-5 py-8">{t("mine.loading")}</main>;

  if (!loggedIn) {
    return (
      <main className="max-w-3xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">{t("mine.title")}</h1>
        <p className="mb-4 text-ink-soft">{t("mine.loginPrompt")}</p>
        <Link href="/login" className="btn btn-primary">{t("nav.login")}</Link>
      </main>
    );
  }

  return (
    <main className="max-w-3xl mx-auto px-5 py-8">
      <div className="flex flex-wrap items-end justify-between gap-4 mb-6">
        <h1 className="font-display font-extrabold text-3xl">{t("mine.title")}</h1>
        <Link href="/report" className="btn btn-primary">{t("common.reportItem")}</Link>
      </div>

      {error && (
        <p role="alert" className="mb-4 rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
          {error}
        </p>
      )}

      {items.length === 0 && (
        <div className="panel">
          <p className="font-semibold">{t("mine.none")}</p>
          <p className="text-ink-soft">
            {t("mine.noneText")}
            <Link href="/report" className="text-rail-dark underline">{t("common.reportItem")}</Link>.
          </p>
        </div>
      )}

      <div className="space-y-5">
        {items.map((it) => {
          const current = STAGES.indexOf(it.status);
          const next = STAGES[current + 1];
          return (
            <article key={it.id} className="ticket">
              <TicketBand type={it.type} id={it.id} />
              <div className="p-4 flex gap-4">
                {it.image_url && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={it.image_url} alt={it.title}
                    className="h-16 w-16 rounded-lg object-cover border-[1.5px] border-ink shrink-0" />
                )}
                <div>
                  <h2 className="font-display font-bold text-lg leading-snug">{it.title}</h2>
                  <p className="text-sm text-ink-soft">
                    {td(`cat.${it.category}`, it.category)}, {it.city ?? t("common.unknownCity")},{" "}
                    {formatDate(it.event_date, lang)}
                  </p>
                </div>
              </div>

              <div className="ticket-perf mx-4" />

              <div className="p-4">
                <ol className="flex items-start" aria-label={t("mine.statusAria")}>
                  {STAGES.map((s, i) => (
                    <li key={s} className="flex items-start flex-1 last:flex-none">
                      <span className="flex flex-col items-center gap-1">
                        <span className={`grid place-items-center h-6 w-6 rounded-full border-[1.5px] border-ink text-xs font-bold ${
                          i <= current ? "bg-ink text-white" : "bg-card text-ink-soft"
                        }`}>
                          {i < current ? "✓" : i + 1}
                        </span>
                        <span className={`text-xs ${i === current ? "font-bold" : "text-ink-soft"}`}>
                          {td(`status.${s}`, s)}
                        </span>
                      </span>
                      {i < STAGES.length - 1 && (
                        <span className={`h-[2px] flex-1 mx-2 mt-[11px] ${
                          i < current ? "bg-ink" : "bg-line-strong"
                        }`} />
                      )}
                    </li>
                  ))}
                </ol>

                <div className="flex flex-wrap gap-3 mt-4">
                  {next && (
                    <button onClick={() => advance(it)} className="btn btn-primary btn-small">
                      {t("mine.markAs", { status: td(`status.${next}`, next) })}
                    </button>
                  )}
                  <button onClick={() => remove(it)} className="btn btn-danger btn-small">
                    {t("mine.delete")}
                  </button>
                </div>
              </div>
            </article>
          );
        })}
      </div>
    </main>
  );
}
__LF_EOF__

write "src/app/page.tsx" <<'__LF_EOF__'
"use client";
import Link from "next/link";
import { useT } from "@/lib/i18n";
import TicketBand from "@/components/TicketBand";
import HomeLive from "@/components/HomeLive";

export default function Home() {
  const { t } = useT();

  const steps = [
    { n: "1", title: t("home.step1.title"), text: t("home.step1.text") },
    { n: "2", title: t("home.step2.title"), text: t("home.step2.text") },
    { n: "3", title: t("home.step3.title"), text: t("home.step3.text") },
  ];

  return (
    <main className="max-w-6xl mx-auto px-5">
      <section className="grid gap-12 lg:grid-cols-2 items-center py-14 lg:py-20">
        <div>
          <h1 className="font-display font-extrabold text-4xl sm:text-5xl lg:text-[3.4rem] leading-[1.1]">
            {t("home.h1")}
          </h1>
          <p className="mt-5 text-lg text-ink-soft max-w-prose">{t("home.sub")}</p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/report" className="btn btn-primary">
              {t("home.ctaLost")}
            </Link>
            <Link href="/report?type=found" className="btn">
              {t("home.ctaFound")}
            </Link>
          </div>
          <p className="mt-5 text-sm text-ink-soft max-w-md">{t("home.privacy")}</p>
        </div>

        <div className="relative mx-auto w-full max-w-md py-6" aria-hidden="true">
          <div className="ticket -rotate-2">
            <TicketBand type="lost" id="A7K2" />
            <div className="p-4">
              <p className="font-display font-bold text-lg">{t("hero.lostTitle")}</p>
              <p className="text-sm text-ink-soft">{t("hero.lostDesc")}</p>
              <p className="mt-2 text-xs text-ink-soft">{t("hero.lostWhere")}</p>
            </div>
          </div>
          <div className="ticket rotate-[1.5deg] mt-5 ml-8">
            <TicketBand type="found" id="Q93M" />
            <div className="p-4">
              <p className="font-display font-bold text-lg">{t("hero.foundTitle")}</p>
              <p className="text-sm text-ink-soft">{t("hero.foundDesc")}</p>
              <p className="mt-2 text-xs text-ink-soft">{t("hero.foundWhere")}</p>
            </div>
          </div>
          <div className="match-stamp absolute right-0 top-1/2 -translate-y-1/2 text-lg">
            {t("hero.stamp")}
          </div>
        </div>
      </section>

      <HomeLive />

      <section className="pb-16">
        <h2 className="font-display font-extrabold text-2xl mb-6">{t("home.how")}</h2>
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
          <h2 className="font-display font-extrabold text-2xl">{t("home.trustTitle")}</h2>
          <p className="mt-2 text-white/85 max-w-2xl">{t("home.trustText")}</p>
        </div>
        <Link href="/items" className="btn">
          {t("home.browseFound")}
        </Link>
      </section>
    </main>
  );
}
__LF_EOF__

write "src/app/report/page.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import dynamic from "next/dynamic";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { reasonText, useT } from "@/lib/i18n";
import TicketBand from "@/components/TicketBand";
import MapLoading from "@/components/MapLoading";

const MapPicker = dynamic(() => import("@/components/MapPicker"), {
  ssr: false,
  loading: () => <MapLoading />,
});

type Match = {
  id: string;
  title: string;
  description: string | null;
  city: string | null;
  event_date: string;
  image_url: string | null;
  score: number;
  reasons: string[];
};

const CATEGORIES = ["phone", "wallet", "bag", "keys", "documents", "laptop", "other"];

export default function ReportPage() {
  const { t, td, lang } = useT();
  const [email, setEmail] = useState<string | null>(null);
  const [checking, setChecking] = useState(true);
  const [form, setForm] = useState({
    type: "lost", title: "", description: "", category: "phone",
    color: "", city: "", event_date: "",
  });
  const [secret, setSecret] = useState({ question: "", answer: "", contact: "" });
  const [file, setFile] = useState<File | null>(null);
  const [pin, setPin] = useState<{ lat: number; lng: number } | null>(null);
  const [matches, setMatches] = useState<Match[] | null>(null);
  const [resultType, setResultType] = useState("lost");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const resultsRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setEmail(data.session?.user.email ?? null);
      setChecking(false);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, session) => {
      setEmail(session?.user.email ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    const q = new URLSearchParams(window.location.search).get("type");
    if (q === "found") {
      Promise.resolve().then(() => setForm((f) => ({ ...f, type: "found" })));
    }
  }, []);

  useEffect(() => {
    if (matches) resultsRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [matches]);

  const set = (k: string, v: string) => setForm({ ...form, [k]: v });
  const setSec = (k: string, v: string) => setSecret({ ...secret, [k]: v });

  function useMyLocation() {
    if (!navigator.geolocation) return setError(t("report.errNoLoc"));
    navigator.geolocation.getCurrentPosition(
      (pos) => setPin({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => setError(t("report.errLoc"))
    );
  }

  function pickFile(f: File | null) {
    setError("");
    if (f && !f.type.startsWith("image/")) return setError(t("report.errImage"));
    if (f && f.size > 5 * 1024 * 1024) return setError(t("report.errSize"));
    setFile(f);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    setMatches(null);

    const { data: sessionData } = await supabase.auth.getSession();
    const token = sessionData.session?.access_token;
    if (!token) {
      setLoading(false);
      return setError(t("report.errLogin"));
    }

    let image_url: string | null = null;
    if (file) {
      const ext = file.name.split(".").pop() ?? "jpg";
      const path = `${crypto.randomUUID()}.${ext}`;
      const { error: upErr } = await supabase.storage.from("item-images").upload(path, file);
      if (upErr) {
        setLoading(false);
        return setError(t("report.errUpload", { msg: upErr.message }));
      }
      image_url = supabase.storage.from("item-images").getPublicUrl(path).data.publicUrl;
    }

    const res = await fetch("/api/report", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        ...form,
        image_url,
        lat: pin?.lat ?? null,
        lng: pin?.lng ?? null,
      }),
    });
    const data = await res.json();
    if (!res.ok) {
      setLoading(false);
      return setError(data.error ?? t("report.errGeneric"));
    }

    if (form.type === "found") {
      const { error: secErr } = await supabase.from("item_secrets").insert({
        item_id: data.item.id,
        question: secret.question.trim(),
        answer: secret.answer.trim(),
        contact: secret.contact.trim(),
      });
      if (secErr) {
        setLoading(false);
        return setError(t("report.errSecret", { msg: secErr.message }));
      }
    }

    setLoading(false);
    setResultType(form.type);
    setMatches(data.matches ?? []);
  }

  const isFound = form.type === "found";

  if (checking) return <main className="max-w-3xl mx-auto px-5 py-8">{t("common.loading")}</main>;

  if (!email) {
    return (
      <main className="max-w-3xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">{t("report.title")}</h1>
        <p className="mb-4 text-ink-soft">{t("report.loginPrompt")}</p>
        <Link href="/login" className="btn btn-primary">
          {t("nav.login")}
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-3xl mx-auto px-5 py-8">
      <h1 className="font-display font-extrabold text-3xl">{t("report.title")}</h1>
      <p className="text-ink-soft mt-1 mb-6">{t("report.sub")}</p>

      <form onSubmit={submit} className="space-y-6">
        <div className="segmented w-full sm:w-auto" role="group" aria-label={t("report.typeAria")}>
          <button type="button" aria-pressed={!isFound} onClick={() => set("type", "lost")}>
            {t("report.iLost")}
          </button>
          <button type="button" aria-pressed={isFound} onClick={() => set("type", "found")}>
            {t("report.iFound")}
          </button>
        </div>

        <section className="panel space-y-4">
          <h2 className="font-display font-bold text-xl">{t("report.about")}</h2>
          <div>
            <label className="label" htmlFor="title">{t("report.fTitle")}</label>
            <input id="title" className="field w-full" required placeholder={t("report.titlePh")}
              value={form.title} onChange={(e) => set("title", e.target.value)} />
          </div>
          <div>
            <label className="label" htmlFor="description">{t("report.fDesc")}</label>
            <textarea id="description" className="field w-full" rows={3}
              placeholder={t("report.descPh")}
              value={form.description} onChange={(e) => set("description", e.target.value)} />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="label" htmlFor="category">{t("report.fCategory")}</label>
              <select id="category" className="field w-full" value={form.category}
                onChange={(e) => set("category", e.target.value)}>
                {CATEGORIES.map((c) => (
                  <option key={c} value={c}>{td(`cat.${c}`, c)}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label" htmlFor="color">{t("report.fColour")}</label>
              <input id="color" className="field w-full" placeholder={t("report.colourPh")}
                value={form.color} onChange={(e) => set("color", e.target.value)} />
            </div>
          </div>
        </section>

        <section className="panel space-y-4">
          <h2 className="font-display font-bold text-xl">
            {isFound ? t("report.whereFound") : t("report.whereLost")}
          </h2>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="label" htmlFor="city">{t("report.fCity")}</label>
              <input id="city" className="field w-full" placeholder={t("report.cityPh")}
                value={form.city} onChange={(e) => set("city", e.target.value)} />
            </div>
            <div>
              <label className="label" htmlFor="date">{t("report.fDate")}</label>
              <input id="date" className="field w-full" type="date" required value={form.event_date}
                onChange={(e) => set("event_date", e.target.value)} />
            </div>
          </div>
          <div>
            <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
              <span className="label mb-0">{t("report.pinLabel")}</span>
              <button type="button" onClick={useMyLocation} className="btn btn-small">
                {t("report.useLocation")}
              </button>
            </div>
            <div className="isolate overflow-hidden rounded-xl border-[1.5px] border-ink">
              <MapPicker
                lat={pin?.lat ?? null}
                lng={pin?.lng ?? null}
                onPick={(lat, lng) => setPin({ lat, lng })}
              />
            </div>
            <p className="mt-2 text-sm text-ink-soft">
              {pin
                ? t("report.pinSaved", { lat: pin.lat.toFixed(4), lng: pin.lng.toFixed(4) })
                : t("report.pinHint")}
            </p>
          </div>
        </section>

        <section className="panel space-y-3">
          <h2 className="font-display font-bold text-xl">{t("report.photo")}</h2>
          <input type="file" accept="image/*" aria-label={t("report.photoAria")}
            className="field w-full"
            onChange={(e) => pickFile(e.target.files?.[0] ?? null)} />
          <p className="text-sm text-ink-soft">{t("report.photoHint")}</p>
          {file && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={URL.createObjectURL(file)} alt={t("report.photoPreview")}
              className="h-36 rounded-lg object-cover border-[1.5px] border-ink" />
          )}
        </section>

        {isFound && (
          <section className="panel space-y-4 bg-[#fff6cc]">
            <div>
              <h2 className="font-display font-bold text-xl">{t("report.verifyTitle")}</h2>
              <p className="text-sm text-ink-soft">{t("report.verifyHelp")}</p>
            </div>
            <div>
              <label className="label" htmlFor="q">{t("report.fQuestion")}</label>
              <input id="q" className="field w-full" required placeholder={t("report.qPh")}
                value={secret.question} onChange={(e) => setSec("question", e.target.value)} />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="label" htmlFor="a">{t("report.fAnswer")}</label>
                <input id="a" className="field w-full" required placeholder={t("report.aPh")}
                  value={secret.answer} onChange={(e) => setSec("answer", e.target.value)} />
              </div>
              <div>
                <label className="label" htmlFor="c">{t("report.fContact")}</label>
                <input id="c" className="field w-full" required placeholder={t("report.cPh")}
                  value={secret.contact} onChange={(e) => setSec("contact", e.target.value)} />
              </div>
            </div>
          </section>
        )}

        <button disabled={loading} className="btn btn-primary w-full sm:w-auto">
          {loading ? t("report.submitting") : t("report.submit")}
        </button>
      </form>

      {error && (
        <p role="alert" className="mt-5 rounded-lg border border-lost bg-lost-tint px-4 py-3 text-lost-dark">
          {error}
        </p>
      )}

      {matches && (
        <section ref={resultsRef} className="mt-10 scroll-mt-24">
          <h2 className="font-display font-extrabold text-2xl">{t("report.matches")}</h2>
          <p className="text-ink-soft mb-4">{t("report.matchesSub")}</p>

          {matches.length === 0 ? (
            <div className="panel">
              <p className="font-semibold">{t("report.noMatches")}</p>
              <p className="text-ink-soft">{t("report.noMatchesText")}</p>
            </div>
          ) : (
            <div className="space-y-4">
              {matches.map((m) => {
                const pct = Math.round(m.score * 100);
                return (
                  <article key={m.id} className="ticket">
                    <TicketBand type={resultType === "lost" ? "found" : "lost"} id={m.id} />
                    <div className="flex gap-4 p-4">
                      <div className="score" style={{ "--p": pct } as React.CSSProperties}
                        role="img" aria-label={t("report.matchAria", { pct })}>
                        <span>{pct}%</span>
                      </div>
                      {m.image_url && (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={m.image_url} alt={m.title}
                          className="h-16 w-16 rounded-lg object-cover border-[1.5px] border-ink shrink-0" />
                      )}
                      <div className="min-w-0 flex-1">
                        <h3 className="font-display font-bold text-lg leading-snug">{m.title}</h3>
                        {m.description && (
                          <p className="text-sm text-ink-soft">{m.description}</p>
                        )}
                        <p className="mt-1 text-xs text-ink-soft">
                          {m.city ?? t("common.unknownCity")}, {formatDate(m.event_date, lang)}
                        </p>
                      </div>
                    </div>
                    {m.reasons.length > 0 && (
                      <>
                        <div className="ticket-perf mx-4" />
                        <div className="flex flex-wrap items-center gap-2 px-4 py-3">
                          <span className="mr-1 text-sm font-semibold">{t("report.why")}</span>
                          {m.reasons.map((r) => (
                            <span key={r} className="chip">{reasonText(r, t)}</span>
                          ))}
                        </div>
                      </>
                    )}
                    {resultType === "lost" && (
                      <div className="px-4 pb-4">
                        <Link href={`/claim/${m.id}`} className="btn btn-primary btn-small">
                          {t("detail.claim")}
                        </Link>
                      </div>
                    )}
                  </article>
                );
              })}
            </div>
          )}
        </section>
      )}
    </main>
  );
}
__LF_EOF__

write "src/components/Footer.tsx" <<'__LF_EOF__'
"use client";
import { useT } from "@/lib/i18n";

export default function Footer() {
  const { t } = useT();
  return (
    <footer className="mt-auto border-t border-line py-6 text-sm text-ink-soft">
      <div className="max-w-6xl mx-auto px-5">{t("footer.text")}</div>
    </footer>
  );
}
__LF_EOF__

write "src/components/HomeLive.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { useT } from "@/lib/i18n";
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
  const { t, lang } = useT();
  const [stats, setStats] = useState<Stats | null>(null);
  const [recent, setRecent] = useState<Recent[]>([]);

  useEffect(() => {
    async function load() {
      const count = () => supabase.from("items").select("id", { count: "exact", head: true });
      const [tot, l, f, r, rec] = await Promise.all([
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
        total: tot.count ?? 0,
        lost: l.count ?? 0,
        found: f.count ?? 0,
        returned: r.count ?? 0,
      });
      setRecent((rec.data as Recent[]) ?? []);
    }
    load();
  }, []);

  const cells: [string, number | undefined][] = [
    [t("live.reports"), stats?.total],
    [t("common.lost"), stats?.lost],
    [t("common.found"), stats?.found],
    [t("live.returned"), stats?.returned],
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
            <h2 className="font-display font-extrabold text-2xl">{t("live.recent")}</h2>
            <Link href="/items" className="text-rail-dark underline font-semibold">
              {t("live.browseAll")}
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
                    {it.city ?? t("common.unknownCity")}, {formatDate(it.event_date, lang)}
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

write "src/components/LanguageSwitch.tsx" <<'__LF_EOF__'
"use client";
import { setLang, useLang, useT } from "@/lib/i18n";

export default function LanguageSwitch() {
  const lang = useLang();
  const { t } = useT();
  return (
    <div className="segmented segmented-sm" role="group" aria-label={t("nav.language")}>
      <button type="button" aria-pressed={lang === "en"} onClick={() => setLang("en")} lang="en">
        English
      </button>
      <button type="button" aria-pressed={lang === "hi"} onClick={() => setLang("hi")} lang="hi">
        हिन्दी
      </button>
    </div>
  );
}
__LF_EOF__

write "src/components/MapLoading.tsx" <<'__LF_EOF__'
"use client";
import { useT } from "@/lib/i18n";

export default function MapLoading() {
  const { t } = useT();
  return <p className="p-4 text-sm text-ink-soft">{t("common.loadingMap")}</p>;
}
__LF_EOF__

write "src/components/Navbar.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { useT } from "@/lib/i18n";
import LanguageSwitch from "@/components/LanguageSwitch";

export default function Navbar() {
  const pathname = usePathname();
  const { t, lang } = useT();
  const [email, setEmail] = useState<string | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  useEffect(() => {
    function checkAdmin(loggedIn: boolean) {
      if (!loggedIn) return setIsAdmin(false);
      supabase.rpc("is_admin").then(({ data }) => setIsAdmin(data === true));
    }
    supabase.auth.getSession().then(({ data }) => {
      setEmail(data.session?.user.email ?? null);
      checkAdmin(!!data.session);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, session) => {
      setEmail(session?.user.email ?? null);
      checkAdmin(!!session);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const links = [
    { href: "/report", label: t("nav.report") },
    { href: "/items", label: t("nav.browse") },
    ...(email
      ? [
          { href: "/my-reports", label: t("nav.myReports") },
          { href: "/messages", label: t("nav.messages") },
        ]
      : []),
    ...(isAdmin ? [{ href: "/admin", label: t("nav.admin") }] : []),
  ];

  return (
    <header className="sticky top-0 z-30 bg-card border-b-[1.5px] border-ink">
      <nav className="max-w-6xl mx-auto px-5 py-3 flex flex-wrap items-center gap-x-6 gap-y-2">
        <Link href="/" className="flex items-center gap-2 font-display font-extrabold text-lg">
          <svg width="26" height="26" viewBox="0 0 24 24" aria-hidden="true">
            <path
              d="M21 7a3 3 0 0 0-3-3h-7l-8 8 8 8h7a3 3 0 0 0 3-3z"
              fill="#ffc20e"
              stroke="#0e1a3a"
              strokeWidth="1.8"
              strokeLinejoin="round"
            />
            <circle cx="9" cy="12" r="1.8" fill="#fff" stroke="#0e1a3a" strokeWidth="1.5" />
          </svg>
          {t("brand")}
        </Link>

        <div className="flex items-center gap-5 text-[0.95rem] font-semibold">
          {links.map((l) => {
            const active = pathname.startsWith(l.href);
            return (
              <Link
                key={l.href}
                href={l.href}
                className={`py-1 border-b-[3px] ${
                  active ? "border-signal" : "border-transparent hover:border-line-strong"
                }`}
              >
                {l.label}
              </Link>
            );
          })}
        </div>

        <div className="ml-auto flex items-center gap-3 text-sm">
          <LanguageSwitch />
          {email ? (
            <>
              <span className="hidden lg:inline text-ink-soft">{email}</span>
              <button className="btn btn-small" onClick={() => supabase.auth.signOut()}>
                {t("nav.logout")}
              </button>
            </>
          ) : (
            <Link href="/login" className="btn btn-small btn-primary">
              {t("nav.login")}
            </Link>
          )}
        </div>
      </nav>
    </header>
  );
}
__LF_EOF__

write "src/components/TicketBand.tsx" <<'__LF_EOF__'
"use client";
import { useT } from "@/lib/i18n";

export default function TicketBand({ type, id }: { type: string; id?: string }) {
  const { t } = useT();
  const lost = type === "lost";
  return (
    <div className={`ticket-band ${lost ? "ticket-band-lost" : "ticket-band-found"}`}>
      <span className="ticket-hole" aria-hidden="true" />
      <span>{lost ? t("common.lost") : t("common.found")}</span>
      {id && (
        <span className="ticket-ref">
          {t("ticket.no")} {id.slice(0, 4).toUpperCase()}
        </span>
      )}
    </div>
  );
}
__LF_EOF__

write "src/lib/dictionary.ts" <<'__LF_EOF__'
export type Lang = "en" | "hi";

const en = {
  // navigation and footer
  "brand": "Pan-India Lost & Found",
  "nav.report": "Report",
  "nav.browse": "Browse",
  "nav.myReports": "My reports",
  "nav.messages": "Messages",
  "nav.admin": "Admin",
  "nav.login": "Log in",
  "nav.logout": "Log out",
  "nav.language": "Language",
  "footer.text": "Built by Astha Dixit, Hemal Nangru and Shubham Kumar for INT252, Lovely Professional University.",

  // shared words
  "common.lost": "Lost",
  "common.found": "Found",
  "common.all": "All",
  "common.loading": "Loading...",
  "common.unknownCity": "Unknown city",
  "common.noPhoto": "No photo added",
  "common.reportItem": "Report an item",
  "common.loadingMap": "Loading map...",
  "common.report": "Report",
  "ticket.no": "No.",

  "status.open": "open",
  "status.matched": "matched",
  "status.claimed": "claimed",
  "status.returned": "returned",
  "cat.phone": "phone",
  "cat.wallet": "wallet",
  "cat.bag": "bag",
  "cat.keys": "keys",
  "cat.documents": "documents",
  "cat.laptop": "laptop",
  "cat.other": "other",

  "reason.verySimilar": "very similar description",
  "reason.similar": "similar description",
  "reason.sameCity": "same city",
  "reason.sameColour": "same colour",
  "reason.sameDay": "same day",
  "reason.dayApart": "{n} day apart",
  "reason.daysApart": "{n} days apart",
  "reason.mAway": "{n} m away",
  "reason.kmAway": "{n} km away",

  // home
  "home.h1": "Lost it somewhere in India? Someone may already have found it.",
  "home.sub": "Report what you lost or found. We compare descriptions, places and dates, and tell you why two reports match.",
  "home.ctaLost": "Report a lost item",
  "home.ctaFound": "I found something",
  "home.privacy": "Contact details stay hidden until the owner answers a question only they would know.",
  "hero.lostTitle": "Black Samsung phone",
  "hero.lostDesc": "Cracked screen, dog wallpaper",
  "hero.lostWhere": "Hisar, 14 Nov",
  "hero.foundTitle": "Dark mobile phone",
  "hero.foundDesc": "Broken display, puppy lock screen",
  "hero.foundWhere": "Hisar, 15 Nov",
  "hero.stamp": "82% match",
  "home.how": "How it works",
  "home.step1.title": "Report",
  "home.step1.text": "Say what you lost or found. Add a photo and drop a pin on the map.",
  "home.step2.title": "Match",
  "home.step2.text": "We compare descriptions, distance and dates, and show why two reports look alike.",
  "home.step3.title": "Claim",
  "home.step3.text": "The finder sets a question. Answer it correctly and you get their contact details.",
  "home.trustTitle": "You can judge every match yourself",
  "home.trustText": "Each match lists its reasons, such as 400 m away or same colour. A finder's contact details are stored separately and never reach your browser until you pass the check.",
  "home.browseFound": "Browse found items",
  "live.reports": "Reports",
  "live.returned": "Returned",
  "live.recent": "Recently found",
  "live.browseAll": "Browse all reports",

  // browse
  "items.title": "Browse reports",
  "items.shownOne": "{n} report shown",
  "items.shownMany": "{n} reports shown",
  "items.loading": "Loading reports...",
  "items.typeAria": "Report type",
  "items.viewAria": "View",
  "items.categoryAria": "Category",
  "items.cityAria": "City",
  "items.list": "List",
  "items.map": "Map",
  "items.allCategories": "All categories",
  "items.cityPh": "Search city, e.g. Jalandhar",
  "items.emptyTitle": "No reports match these filters.",
  "items.emptyText": "Clear a filter, or ",
  "items.emptyLink": "report the item yourself",
  "items.pins": "{pins} of {total} reports have a map pin.",

  // report detail
  "detail.back": "Back to all reports",
  "detail.loading": "Loading report...",
  "detail.notFound": "Report not found",
  "detail.notFoundText": "This report doesn't exist or was removed.",
  "detail.browse": "Browse reports",
  "detail.claim": "Claim this item",
  "detail.msgFinder": "Message the finder",
  "detail.msgOwner": "Message the owner",
  "detail.opening": "Opening chat...",
  "detail.loginToMsg": "Log in to send a message",
  "detail.copy": "Copy link",
  "detail.copied": "Link copied",
  "detail.details": "Details",
  "detail.category": "Category",
  "detail.colour": "Colour",
  "detail.city": "City",
  "detail.notGiven": "Not given",
  "detail.lostOn": "Lost on",
  "detail.foundOn": "Found on",
  "detail.status": "Status",
  "detail.noPin": "This report has no map pin.",

  // report form
  "report.title": "Report an item",
  "report.sub": "The more detail you add, the better the matches.",
  "report.loginPrompt": "Log in to report a lost or found item.",
  "report.typeAria": "Report type",
  "report.iLost": "I lost something",
  "report.iFound": "I found something",
  "report.about": "About the item",
  "report.fTitle": "Title",
  "report.titlePh": "Black Samsung phone",
  "report.fDesc": "Description",
  "report.descPh": "Cracked screen, dog wallpaper, blue case",
  "report.fCategory": "Category",
  "report.fColour": "Colour",
  "report.colourPh": "Black",
  "report.whereLost": "Where and when you lost it",
  "report.whereFound": "Where and when you found it",
  "report.fCity": "City",
  "report.cityPh": "Jalandhar",
  "report.fDate": "Date",
  "report.pinLabel": "Pin the spot on the map (optional)",
  "report.useLocation": "Use my location",
  "report.pinSaved": "Pin saved at {lat}, {lng}. Matches will show the distance.",
  "report.pinHint": "Click the map to drop a pin. Matches will show the distance.",
  "report.photo": "Photo",
  "report.photoAria": "Photo, optional, max 5 MB",
  "report.photoHint": "Optional. Up to 5 MB.",
  "report.photoPreview": "Preview of the chosen photo",
  "report.verifyTitle": "Verification question",
  "report.verifyHelp": "Only the real owner should know the answer. They must answer it before they see your contact details.",
  "report.fQuestion": "Question",
  "report.qPh": "What is the phone wallpaper?",
  "report.fAnswer": "Correct answer",
  "report.aPh": "Dog",
  "report.fContact": "Your contact",
  "report.cPh": "Phone or email",
  "report.submit": "Save and find matches",
  "report.submitting": "Finding matches...",
  "report.matches": "Possible matches",
  "report.matchesSub": "Ranked by description, distance and date. Each card says why it matched.",
  "report.noMatches": "No matches yet.",
  "report.noMatchesText": "Your report is saved. Anyone who reports a similar item will be able to find it.",
  "report.why": "Why it matched",
  "report.matchAria": "{pct}% match",
  "report.errLogin": "Log in first.",
  "report.errImage": "Choose an image file.",
  "report.errSize": "The image must be under 5 MB.",
  "report.errNoLoc": "Your browser doesn't support location. Click the map instead.",
  "report.errLoc": "Couldn't get your location. Click the map instead.",
  "report.errUpload": "Image upload failed: {msg}",
  "report.errGeneric": "Something went wrong. Try again.",
  "report.errSecret": "Couldn't save the verification details: {msg}",

  // login
  "login.logIn": "Log in",
  "login.create": "Create account",
  "login.email": "Email",
  "login.password": "Password",
  "login.passPh": "At least 6 characters",
  "login.wait": "Please wait...",
  "login.newHere": "New here? ",
  "login.already": "Already have an account? ",
  "login.createLink": "Create an account",

  // my reports
  "mine.title": "My reports",
  "mine.loginPrompt": "Log in to see your reports.",
  "mine.loading": "Loading your reports...",
  "mine.none": "You haven't reported anything yet.",
  "mine.noneText": "Lost or found something? ",
  "mine.statusAria": "Status",
  "mine.markAs": "Mark as {status}",
  "mine.delete": "Delete",
  "mine.confirmDelete": "Delete \"{title}\"?",

  // claim
  "claim.title": "Claim this item",
  "claim.loginPrompt": "Log in to claim an item.",
  "claim.noQuestion": "This item has no verification question, so it can't be claimed here.",
  "claim.verified": "Verified. Contact the finder:",
  "claim.intro": "Only the real owner would know this. Answer correctly to see the finder's contact details.",
  "claim.yourAnswer": "Your answer",
  "claim.verifyBtn": "Verify answer",
  "claim.checking": "Checking...",
  "claim.wrong": "That answer isn't right. Check it and try again.",

  // messages
  "msg.title": "Messages",
  "msg.sub": "Chat with the owner or finder without sharing your phone number.",
  "msg.loginPrompt": "Log in to see your messages.",
  "msg.loading": "Loading messages...",
  "msg.none": "No conversations yet.",
  "msg.noneText": "Open a report and choose ",
  "msg.noneLink": "Message the finder or Message the owner",
  "msg.you": "You: ",
  "msg.noMsgs": "No messages yet",
  "msg.someone": "Someone interested in this item",
  "msg.finder": "The finder",
  "msg.owner": "The owner",
  "chat.loading": "Loading chat...",
  "chat.loginPrompt": "Log in to read your messages.",
  "chat.notFound": "Chat not found",
  "chat.notFoundText": "This chat doesn't exist, or it belongs to other people.",
  "chat.back": "Back to messages",
  "chat.about": "About ",
  "chat.thisReport": "this report",
  "chat.privacy": "Keep your phone number private until you are sure it is the right item.",
  "chat.empty": "No messages yet. Say hello and describe the item.",
  "chat.aria": "Message",
  "chat.placeholder": "Write a message",
  "chat.send": "Send",
  "chat.sending": "Sending...",
};

export type Key = keyof typeof en;

const hi: Record<Key, string> = {
  "brand": "पैन-इंडिया खोया-पाया",
  "nav.report": "रिपोर्ट करें",
  "nav.browse": "देखें",
  "nav.myReports": "मेरी रिपोर्ट",
  "nav.messages": "संदेश",
  "nav.admin": "एडमिन",
  "nav.login": "लॉग इन",
  "nav.logout": "लॉग आउट",
  "nav.language": "भाषा",
  "footer.text": "आस्था दीक्षित, हेमल नांगरू और शुभम कुमार द्वारा INT252 के लिए बनाया गया, लवली प्रोफेशनल यूनिवर्सिटी।",

  "common.lost": "खोया",
  "common.found": "मिला",
  "common.all": "सभी",
  "common.loading": "लोड हो रहा है...",
  "common.unknownCity": "शहर अज्ञात",
  "common.noPhoto": "फ़ोटो नहीं जोड़ी गई",
  "common.reportItem": "चीज़ की रिपोर्ट करें",
  "common.loadingMap": "नक़्शा लोड हो रहा है...",
  "common.report": "रिपोर्ट",
  "ticket.no": "क्र.",

  "status.open": "खुली",
  "status.matched": "मिलान हुआ",
  "status.claimed": "दावा हुआ",
  "status.returned": "लौटाई गई",
  "cat.phone": "फ़ोन",
  "cat.wallet": "बटुआ",
  "cat.bag": "बैग",
  "cat.keys": "चाबियाँ",
  "cat.documents": "दस्तावेज़",
  "cat.laptop": "लैपटॉप",
  "cat.other": "अन्य",

  "reason.verySimilar": "बहुत मिलता-जुलता विवरण",
  "reason.similar": "मिलता-जुलता विवरण",
  "reason.sameCity": "एक ही शहर",
  "reason.sameColour": "एक ही रंग",
  "reason.sameDay": "उसी दिन",
  "reason.dayApart": "{n} दिन का अंतर",
  "reason.daysApart": "{n} दिन का अंतर",
  "reason.mAway": "{n} मीटर दूर",
  "reason.kmAway": "{n} किमी दूर",

  "home.h1": "भारत में कहीं कुछ खो गया? हो सकता है किसी को वह पहले ही मिल चुका हो।",
  "home.sub": "जो खोया या मिला, उसकी रिपोर्ट करें। हम विवरण, जगह और तारीख़ की तुलना करके बताते हैं कि दो रिपोर्ट क्यों मेल खाती हैं।",
  "home.ctaLost": "खोई चीज़ की रिपोर्ट करें",
  "home.ctaFound": "मुझे कुछ मिला है",
  "home.privacy": "संपर्क विवरण तब तक छिपे रहते हैं जब तक मालिक वह सवाल सही हल नहीं कर देता जो सिर्फ़ उसे पता होगा।",
  "hero.lostTitle": "काला सैमसंग फ़ोन",
  "hero.lostDesc": "स्क्रीन टूटी, कुत्ते का वॉलपेपर",
  "hero.lostWhere": "हिसार, 14 नवंबर",
  "hero.foundTitle": "गहरे रंग का मोबाइल",
  "hero.foundDesc": "टूटा डिस्प्ले, पिल्ले की लॉक स्क्रीन",
  "hero.foundWhere": "हिसार, 15 नवंबर",
  "hero.stamp": "82% मिलान",
  "home.how": "यह कैसे काम करता है",
  "home.step1.title": "रिपोर्ट करें",
  "home.step1.text": "बताइए क्या खोया या मिला। फ़ोटो जोड़ें और नक़्शे पर पिन लगाएँ।",
  "home.step2.title": "मिलान",
  "home.step2.text": "हम विवरण, दूरी और तारीख़ की तुलना करते हैं और दिखाते हैं कि दो रिपोर्ट एक जैसी क्यों लगती हैं।",
  "home.step3.title": "दावा",
  "home.step3.text": "जिसे चीज़ मिली है वह एक सवाल रखता है। सही जवाब दें तो आपको उसका संपर्क विवरण मिल जाएगा।",
  "home.trustTitle": "हर मिलान को आप खुद परख सकते हैं",
  "home.trustText": "हर मिलान के साथ उसके कारण दिखते हैं, जैसे 400 मीटर दूर या एक ही रंग। चीज़ पाने वाले का संपर्क विवरण अलग रखा जाता है और जाँच पास करने से पहले आपके ब्राउज़र तक नहीं पहुँचता।",
  "home.browseFound": "मिली चीज़ें देखें",
  "live.reports": "रिपोर्ट",
  "live.returned": "लौटाई गईं",
  "live.recent": "हाल ही में मिली चीज़ें",
  "live.browseAll": "सभी रिपोर्ट देखें",

  "items.title": "रिपोर्ट देखें",
  "items.shownOne": "{n} रिपोर्ट दिखाई गई",
  "items.shownMany": "{n} रिपोर्ट दिखाई गईं",
  "items.loading": "रिपोर्ट लोड हो रही हैं...",
  "items.typeAria": "रिपोर्ट का प्रकार",
  "items.viewAria": "दृश्य",
  "items.categoryAria": "श्रेणी",
  "items.cityAria": "शहर",
  "items.list": "सूची",
  "items.map": "नक़्शा",
  "items.allCategories": "सभी श्रेणियाँ",
  "items.cityPh": "शहर खोजें, जैसे जालंधर",
  "items.emptyTitle": "इन फ़िल्टर से कोई रिपोर्ट नहीं मिली।",
  "items.emptyText": "कोई फ़िल्टर हटाएँ, या ",
  "items.emptyLink": "खुद रिपोर्ट करें",
  "items.pins": "{total} में से {pins} रिपोर्ट पर नक़्शे का पिन है।",

  "detail.back": "सभी रिपोर्ट पर वापस",
  "detail.loading": "रिपोर्ट लोड हो रही है...",
  "detail.notFound": "रिपोर्ट नहीं मिली",
  "detail.notFoundText": "यह रिपोर्ट मौजूद नहीं है या हटा दी गई है।",
  "detail.browse": "रिपोर्ट देखें",
  "detail.claim": "इस चीज़ पर दावा करें",
  "detail.msgFinder": "पाने वाले को संदेश भेजें",
  "detail.msgOwner": "मालिक को संदेश भेजें",
  "detail.opening": "चैट खुल रही है...",
  "detail.loginToMsg": "संदेश भेजने के लिए लॉग इन करें",
  "detail.copy": "लिंक कॉपी करें",
  "detail.copied": "लिंक कॉपी हो गया",
  "detail.details": "विवरण",
  "detail.category": "श्रेणी",
  "detail.colour": "रंग",
  "detail.city": "शहर",
  "detail.notGiven": "नहीं दिया गया",
  "detail.lostOn": "खोने की तारीख़",
  "detail.foundOn": "मिलने की तारीख़",
  "detail.status": "स्थिति",
  "detail.noPin": "इस रिपोर्ट पर नक़्शे का पिन नहीं है।",

  "report.title": "चीज़ की रिपोर्ट करें",
  "report.sub": "जितना ज़्यादा विवरण देंगे, मिलान उतने बेहतर होंगे।",
  "report.loginPrompt": "खोई या मिली चीज़ की रिपोर्ट करने के लिए लॉग इन करें।",
  "report.typeAria": "रिपोर्ट का प्रकार",
  "report.iLost": "मेरी कुछ चीज़ खो गई",
  "report.iFound": "मुझे कुछ मिला है",
  "report.about": "चीज़ के बारे में",
  "report.fTitle": "शीर्षक",
  "report.titlePh": "काला सैमसंग फ़ोन",
  "report.fDesc": "विवरण",
  "report.descPh": "टूटी स्क्रीन, कुत्ते का वॉलपेपर, नीला कवर",
  "report.fCategory": "श्रेणी",
  "report.fColour": "रंग",
  "report.colourPh": "काला",
  "report.whereLost": "कहाँ और कब खोया",
  "report.whereFound": "कहाँ और कब मिला",
  "report.fCity": "शहर",
  "report.cityPh": "जालंधर",
  "report.fDate": "तारीख़",
  "report.pinLabel": "नक़्शे पर जगह चुनें (वैकल्पिक)",
  "report.useLocation": "मेरी लोकेशन इस्तेमाल करें",
  "report.pinSaved": "{lat}, {lng} पर पिन सहेजा गया। मिलान में दूरी दिखेगी।",
  "report.pinHint": "पिन लगाने के लिए नक़्शे पर क्लिक करें। मिलान में दूरी दिखेगी।",
  "report.photo": "फ़ोटो",
  "report.photoAria": "फ़ोटो, वैकल्पिक, अधिकतम 5 MB",
  "report.photoHint": "वैकल्पिक। 5 MB तक।",
  "report.photoPreview": "चुनी गई फ़ोटो का पूर्वावलोकन",
  "report.verifyTitle": "सत्यापन सवाल",
  "report.verifyHelp": "इसका जवाब सिर्फ़ असली मालिक को पता होना चाहिए। आपका संपर्क विवरण देखने से पहले उसे यह जवाब देना होगा।",
  "report.fQuestion": "सवाल",
  "report.qPh": "फ़ोन का वॉलपेपर क्या है?",
  "report.fAnswer": "सही जवाब",
  "report.aPh": "कुत्ता",
  "report.fContact": "आपका संपर्क",
  "report.cPh": "फ़ोन या ईमेल",
  "report.submit": "सहेजें और मिलान खोजें",
  "report.submitting": "मिलान खोजे जा रहे हैं...",
  "report.matches": "संभावित मिलान",
  "report.matchesSub": "विवरण, दूरी और तारीख़ के आधार पर क्रमबद्ध। हर कार्ड बताता है कि वह क्यों मिला।",
  "report.noMatches": "अभी कोई मिलान नहीं।",
  "report.noMatchesText": "आपकी रिपोर्ट सहेज ली गई है। कोई समान चीज़ की रिपोर्ट करेगा तो उसे यह दिखेगी।",
  "report.why": "यह क्यों मिला",
  "report.matchAria": "{pct}% मिलान",
  "report.errLogin": "पहले लॉग इन करें।",
  "report.errImage": "कोई इमेज फ़ाइल चुनें।",
  "report.errSize": "इमेज 5 MB से छोटी होनी चाहिए।",
  "report.errNoLoc": "आपका ब्राउज़र लोकेशन सपोर्ट नहीं करता। नक़्शे पर क्लिक करें।",
  "report.errLoc": "आपकी लोकेशन नहीं मिल सकी। नक़्शे पर क्लिक करें।",
  "report.errUpload": "इमेज अपलोड नहीं हो सकी: {msg}",
  "report.errGeneric": "कुछ गड़बड़ हो गई। फिर कोशिश करें।",
  "report.errSecret": "सत्यापन विवरण सहेज नहीं सके: {msg}",

  "login.logIn": "लॉग इन",
  "login.create": "खाता बनाएँ",
  "login.email": "ईमेल",
  "login.password": "पासवर्ड",
  "login.passPh": "कम से कम 6 अक्षर",
  "login.wait": "कृपया प्रतीक्षा करें...",
  "login.newHere": "नए हैं? ",
  "login.already": "पहले से खाता है? ",
  "login.createLink": "खाता बनाएँ",

  "mine.title": "मेरी रिपोर्ट",
  "mine.loginPrompt": "अपनी रिपोर्ट देखने के लिए लॉग इन करें।",
  "mine.loading": "आपकी रिपोर्ट लोड हो रही हैं...",
  "mine.none": "आपने अभी तक कोई रिपोर्ट नहीं की है।",
  "mine.noneText": "कुछ खोया या मिला? ",
  "mine.statusAria": "स्थिति",
  "mine.markAs": "{status} के रूप में चिह्नित करें",
  "mine.delete": "हटाएँ",
  "mine.confirmDelete": "\"{title}\" हटाएँ?",

  "claim.title": "इस चीज़ पर दावा करें",
  "claim.loginPrompt": "किसी चीज़ पर दावा करने के लिए लॉग इन करें।",
  "claim.noQuestion": "इस चीज़ का कोई सत्यापन सवाल नहीं है, इसलिए यहाँ दावा नहीं किया जा सकता।",
  "claim.verified": "सत्यापित। चीज़ पाने वाले से संपर्क करें:",
  "claim.intro": "यह सिर्फ़ असली मालिक को पता होगा। सही जवाब दें तो पाने वाले का संपर्क विवरण दिखेगा।",
  "claim.yourAnswer": "आपका जवाब",
  "claim.verifyBtn": "जवाब जाँचें",
  "claim.checking": "जाँच हो रही है...",
  "claim.wrong": "यह जवाब सही नहीं है। जाँचकर फिर कोशिश करें।",

  "msg.title": "संदेश",
  "msg.sub": "अपना फ़ोन नंबर बताए बिना मालिक या पाने वाले से चैट करें।",
  "msg.loginPrompt": "अपने संदेश देखने के लिए लॉग इन करें।",
  "msg.loading": "संदेश लोड हो रहे हैं...",
  "msg.none": "अभी कोई बातचीत नहीं।",
  "msg.noneText": "कोई रिपोर्ट खोलें और चुनें ",
  "msg.noneLink": "पाने वाले को संदेश भेजें या मालिक को संदेश भेजें",
  "msg.you": "आप: ",
  "msg.noMsgs": "अभी कोई संदेश नहीं",
  "msg.someone": "इस चीज़ में रुचि रखने वाला कोई",
  "msg.finder": "चीज़ पाने वाला",
  "msg.owner": "मालिक",
  "chat.loading": "चैट लोड हो रही है...",
  "chat.loginPrompt": "अपने संदेश पढ़ने के लिए लॉग इन करें।",
  "chat.notFound": "चैट नहीं मिली",
  "chat.notFoundText": "यह चैट मौजूद नहीं है, या किसी और की है।",
  "chat.back": "संदेशों पर वापस",
  "chat.about": "इस चीज़ के बारे में: ",
  "chat.thisReport": "यह रिपोर्ट",
  "chat.privacy": "जब तक पक्का न हो जाए कि यही सही चीज़ है, अपना फ़ोन नंबर निजी रखें।",
  "chat.empty": "अभी कोई संदेश नहीं। नमस्ते कहें और चीज़ का विवरण दें।",
  "chat.aria": "संदेश",
  "chat.placeholder": "संदेश लिखें",
  "chat.send": "भेजें",
  "chat.sending": "भेजा जा रहा है...",
};

export const dictionaries: Record<Lang, Record<Key, string>> = { en, hi };
__LF_EOF__

write "src/lib/format.ts" <<'__LF_EOF__'
import type { Lang } from "@/lib/dictionary";

const locale = (lang: Lang) => (lang === "hi" ? "hi-IN" : "en-IN");

export function formatDate(iso: string, lang: Lang = "en") {
  const d = new Date(`${iso}T00:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString(locale(lang), {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

export function formatTime(iso: string, lang: Lang = "en") {
  return new Date(iso).toLocaleTimeString(locale(lang), { hour: "numeric", minute: "2-digit" });
}
__LF_EOF__

write "src/lib/i18n.ts" <<'__LF_EOF__'
import { useCallback, useSyncExternalStore } from "react";
import { dictionaries, type Key, type Lang } from "@/lib/dictionary";

type Vars = Record<string, string | number>;
export type T = (key: Key, vars?: Vars) => string;

// The chosen language lives in localStorage. useSyncExternalStore keeps every
// component in step and shows English on the server, so the page never mismatches.
const listeners = new Set<() => void>();

function subscribe(cb: () => void) {
  listeners.add(cb);
  window.addEventListener("storage", cb);
  return () => {
    listeners.delete(cb);
    window.removeEventListener("storage", cb);
  };
}

function getSnapshot(): Lang {
  try {
    return localStorage.getItem("lang") === "hi" ? "hi" : "en";
  } catch {
    return "en";
  }
}

const getServerSnapshot = (): Lang => "en";

export function setLang(lang: Lang) {
  try {
    localStorage.setItem("lang", lang);
  } catch {
    // storage can be blocked; the switch still works until the page reloads
  }
  document.documentElement.lang = lang;
  listeners.forEach((f) => f());
}

export function useLang(): Lang {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}

function fill(text: string, vars?: Vars) {
  if (!vars) return text;
  return text.replace(/\{(\w+)\}/g, (_, k: string) => String(vars[k] ?? `{${k}}`));
}

export function useT() {
  const lang = useLang();
  const t: T = useCallback(
    (key, vars) => fill(dictionaries[lang][key] ?? dictionaries.en[key] ?? key, vars),
    [lang]
  );
  // for values that come from the database (status, category) with a safe fallback
  const td = useCallback(
    (key: string, fallback: string) => (dictionaries[lang] as Record<string, string>)[key] ?? fallback,
    [lang]
  );
  return { t, td, lang };
}

// The server sends match reasons in English. This turns them into the chosen language.
export function reasonText(r: string, t: T): string {
  const exact: Record<string, Key> = {
    "very similar description": "reason.verySimilar",
    "similar description": "reason.similar",
    "same city": "reason.sameCity",
    "same colour": "reason.sameColour",
    "same day": "reason.sameDay",
  };
  if (exact[r]) return t(exact[r]);
  let m = r.match(/^(\d+) days? apart$/);
  if (m) return t(m[1] === "1" ? "reason.dayApart" : "reason.daysApart", { n: m[1] });
  m = r.match(/^(\d+) m away$/);
  if (m) return t("reason.mAway", { n: m[1] });
  m = r.match(/^([\d.]+) km away$/);
  if (m) return t("reason.kmAway", { n: m[1] });
  return r;
}
__LF_EOF__


echo ""
echo "Done. Restart the dev server (Ctrl + C, then npm run dev)."
echo "Use the English / Hindi buttons in the top menu."
