#!/bin/bash
# Applies the ticket-style redesign to the lost-found project.
# Run it from inside the lost-found folder (the one with package.json).
set -e

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "Run this inside the lost-found folder (the one that has package.json)."
  exit 1
fi

BACKUP="backup-before-redesign"
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

export default function ClaimPage() {
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
    const { data, error } = await supabase.rpc("verify_claim", {
      p_item: id,
      p_answer: answer,
    });
    setBusy(false);
    if (error) return setMessage(error.message);
    if (data) setContact(data as string);
    else setMessage("That answer isn't right. Check it and try again.");
  }

  if (loadingQ || loggedIn === null) {
    return <main className="max-w-md mx-auto px-5 py-12">Loading...</main>;
  }

  return (
    <main className="max-w-md mx-auto px-5 py-12">
      <div className="ticket">
        <div className="ticket-band ticket-band-ink">
          <span className="ticket-hole" aria-hidden="true" />
          <span>Claim this item</span>
        </div>

        <div className="p-5">
          {!loggedIn ? (
            <>
              <p className="mb-4 text-ink-soft">Log in to claim an item.</p>
              <Link href="/login" className="btn btn-primary">
                Log in
              </Link>
            </>
          ) : !question ? (
            <p className="text-ink-soft">
              This item has no verification question, so it can&apos;t be claimed here.
            </p>
          ) : contact ? (
            <div className="rounded-xl border-[1.5px] border-found bg-found-tint p-4">
              <p className="font-bold text-found-dark">Verified. Contact the finder:</p>
              <p className="mt-1 text-2xl font-display font-extrabold break-words">{contact}</p>
            </div>
          ) : (
            <form onSubmit={verify} className="space-y-4">
              <p className="text-sm text-ink-soft">
                Only the real owner would know this. Answer correctly to see the finder&apos;s
                contact details.
              </p>
              <p className="font-display font-bold text-xl leading-snug">{question}</p>
              <div>
                <label className="label" htmlFor="answer">
                  Your answer
                </label>
                <input
                  id="answer"
                  className="field w-full"
                  required
                  value={answer}
                  onChange={(e) => setAnswer(e.target.value)}
                />
              </div>
              <button disabled={busy} className="btn btn-primary w-full">
                {busy ? "Checking..." : "Verify answer"}
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
  --font-display: var(--font-archivo), "Arial Narrow", system-ui, sans-serif;
  --font-sans: var(--font-figtree), system-ui, sans-serif;
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
  font-family: var(--font-figtree), system-ui, sans-serif;
  line-height: 1.55;
}

@layer base {
  h1,
  h2,
  h3 {
    font-family: var(--font-archivo), "Arial Narrow", system-ui, sans-serif;
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
    font-family: var(--font-archivo), system-ui, sans-serif;
    font-weight: 800;
    font-size: 0.95rem;
  }

  .match-stamp {
    padding: 0.4rem 0.95rem;
    border: 2px solid var(--color-ink);
    border-radius: 999px;
    background: var(--color-signal);
    color: var(--color-ink);
    font-family: var(--font-archivo), system-ui, sans-serif;
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

write "src/app/items/page.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import TicketBand from "@/components/TicketBand";

type Item = {
  id: string;
  type: string;
  title: string;
  description: string | null;
  category: string;
  city: string | null;
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
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      setLoading(true);
      let q = supabase
        .from("items")
        .select("id,type,title,description,category,city,event_date,status,image_url")
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

      <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {items.map((it) => (
          <article key={it.id} className="ticket flex flex-col">
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
              <h2 className="font-display font-bold text-lg leading-snug">{it.title}</h2>
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
    </main>
  );
}
__LF_EOF__

write "src/app/layout.tsx" <<'__LF_EOF__'
import type { Metadata } from "next";
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

write "src/app/login/page.tsx" <<'__LF_EOF__'
"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

export default function LoginPage() {
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

  const title = mode === "login" ? "Log in" : "Create account";

  return (
    <main className="max-w-md mx-auto px-5 py-12">
      <div className="ticket">
        <div className="ticket-band ticket-band-ink">
          <span className="ticket-hole" aria-hidden="true" />
          <span>{title}</span>
        </div>
        <form onSubmit={submit} className="p-5 space-y-4">
          <div>
            <label className="label" htmlFor="email">
              Email
            </label>
            <input
              id="email"
              className="field w-full"
              type="email"
              placeholder="name@example.com"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
          <div>
            <label className="label" htmlFor="password">
              Password
            </label>
            <input
              id="password"
              className="field w-full"
              type="password"
              placeholder="At least 6 characters"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
          <button disabled={loading} className="btn btn-primary w-full">
            {loading ? "Please wait..." : title}
          </button>
          {error && (
            <p role="alert" className="rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
              {error}
            </p>
          )}
        </form>
        <div className="ticket-perf mx-5" />
        <div className="p-5 text-sm">
          {mode === "login" ? "New here? " : "Already have an account? "}
          <button
            type="button"
            className="font-semibold text-rail-dark underline"
            onClick={() => setMode(mode === "login" ? "signup" : "login")}
          >
            {mode === "login" ? "Create an account" : "Log in"}
          </button>
        </div>
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
    if (!window.confirm(`Delete "${it.title}"?`)) return;
    setError("");
    const { error } = await supabase.from("items").delete().eq("id", it.id);
    if (error) return setError(error.message);
    setItems(items.filter((x) => x.id !== it.id));
  }

  if (loading) return <main className="max-w-3xl mx-auto px-5 py-8">Loading your reports...</main>;

  if (!loggedIn) {
    return (
      <main className="max-w-3xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">My reports</h1>
        <p className="mb-4 text-ink-soft">Log in to see your reports.</p>
        <Link href="/login" className="btn btn-primary">
          Log in
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-3xl mx-auto px-5 py-8">
      <div className="flex flex-wrap items-end justify-between gap-4 mb-6">
        <h1 className="font-display font-extrabold text-3xl">My reports</h1>
        <Link href="/report" className="btn btn-primary">
          Report an item
        </Link>
      </div>

      {error && (
        <p role="alert" className="mb-4 rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
          {error}
        </p>
      )}

      {items.length === 0 && (
        <div className="panel">
          <p className="font-semibold">You haven&apos;t reported anything yet.</p>
          <p className="text-ink-soft">
            Lost or found something?{" "}
            <Link href="/report" className="text-rail-dark underline">
              Report an item
            </Link>
            .
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
                  <img
                    src={it.image_url}
                    alt={it.title}
                    className="h-16 w-16 rounded-lg object-cover border-[1.5px] border-ink shrink-0"
                  />
                )}
                <div>
                  <h2 className="font-display font-bold text-lg leading-snug">{it.title}</h2>
                  <p className="text-sm text-ink-soft">
                    {it.category}, {it.city ?? "Unknown city"}, {formatDate(it.event_date)}
                  </p>
                </div>
              </div>

              <div className="ticket-perf mx-4" />

              <div className="p-4">
                <ol className="flex items-start" aria-label="Status">
                  {STAGES.map((s, i) => (
                    <li key={s} className="flex items-start flex-1 last:flex-none">
                      <span className="flex flex-col items-center gap-1">
                        <span
                          className={`grid place-items-center h-6 w-6 rounded-full border-[1.5px] border-ink text-xs font-bold ${
                            i <= current ? "bg-ink text-white" : "bg-card text-ink-soft"
                          }`}
                        >
                          {i < current ? "✓" : i + 1}
                        </span>
                        <span
                          className={`text-xs capitalize ${
                            i === current ? "font-bold" : "text-ink-soft"
                          }`}
                        >
                          {s}
                        </span>
                      </span>
                      {i < STAGES.length - 1 && (
                        <span
                          className={`h-[2px] flex-1 mx-2 mt-[11px] ${
                            i < current ? "bg-ink" : "bg-line-strong"
                          }`}
                        />
                      )}
                    </li>
                  ))}
                </ol>

                <div className="flex flex-wrap gap-3 mt-4">
                  {next && (
                    <button onClick={() => advance(it)} className="btn btn-primary btn-small">
                      Mark as {next}
                    </button>
                  )}
                  <button onClick={() => remove(it)} className="btn btn-danger btn-small">
                    Delete
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
import Link from "next/link";
import TicketBand from "@/components/TicketBand";

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

write "src/app/report/page.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import dynamic from "next/dynamic";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import TicketBand from "@/components/TicketBand";

const MapPicker = dynamic(() => import("@/components/MapPicker"), {
  ssr: false,
  loading: () => <p className="p-4 text-sm text-ink-soft">Loading map...</p>,
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
    const t = new URLSearchParams(window.location.search).get("type");
    if (t === "found") {
      Promise.resolve().then(() => setForm((f) => ({ ...f, type: "found" })));
    }
  }, []);

  useEffect(() => {
    if (matches) resultsRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [matches]);

  const set = (k: string, v: string) => setForm({ ...form, [k]: v });
  const setSec = (k: string, v: string) => setSecret({ ...secret, [k]: v });

  function useMyLocation() {
    if (!navigator.geolocation) {
      return setError("Your browser doesn't support location. Click the map instead.");
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => setPin({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => setError("Couldn't get your location. Click the map instead.")
    );
  }

  function pickFile(f: File | null) {
    setError("");
    if (f && !f.type.startsWith("image/")) {
      setError("Choose an image file.");
      return;
    }
    if (f && f.size > 5 * 1024 * 1024) {
      setError("The image must be under 5 MB.");
      return;
    }
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
      return setError("Log in first.");
    }

    let image_url: string | null = null;
    if (file) {
      const ext = file.name.split(".").pop() ?? "jpg";
      const path = `${crypto.randomUUID()}.${ext}`;
      const { error: upErr } = await supabase.storage
        .from("item-images")
        .upload(path, file);
      if (upErr) {
        setLoading(false);
        return setError("Image upload failed: " + upErr.message);
      }
      image_url = supabase.storage.from("item-images").getPublicUrl(path)
        .data.publicUrl;
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
      return setError(data.error ?? "Something went wrong. Try again.");
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
        return setError("Couldn't save the verification details: " + secErr.message);
      }
    }

    setLoading(false);
    setResultType(form.type);
    setMatches(data.matches ?? []);
  }

  const isFound = form.type === "found";

  if (checking) return <main className="max-w-3xl mx-auto px-5 py-8">Loading...</main>;

  if (!email) {
    return (
      <main className="max-w-3xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">Report an item</h1>
        <p className="mb-4 text-ink-soft">Log in to report a lost or found item.</p>
        <Link href="/login" className="btn btn-primary">
          Log in
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-3xl mx-auto px-5 py-8">
      <h1 className="font-display font-extrabold text-3xl">Report an item</h1>
      <p className="text-ink-soft mt-1 mb-6">The more detail you add, the better the matches.</p>

      <form onSubmit={submit} className="space-y-6">
        <div className="segmented w-full sm:w-auto" role="group" aria-label="Report type">
          <button type="button" aria-pressed={!isFound} onClick={() => set("type", "lost")}>
            I lost something
          </button>
          <button type="button" aria-pressed={isFound} onClick={() => set("type", "found")}>
            I found something
          </button>
        </div>

        <section className="panel space-y-4">
          <h2 className="font-display font-bold text-xl">About the item</h2>
          <div>
            <label className="label" htmlFor="title">Title</label>
            <input id="title" className="field w-full" required placeholder="Black Samsung phone"
              value={form.title} onChange={(e) => set("title", e.target.value)} />
          </div>
          <div>
            <label className="label" htmlFor="description">Description</label>
            <textarea id="description" className="field w-full" rows={3}
              placeholder="Cracked screen, dog wallpaper, blue case"
              value={form.description} onChange={(e) => set("description", e.target.value)} />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="label" htmlFor="category">Category</label>
              <select id="category" className="field w-full" value={form.category}
                onChange={(e) => set("category", e.target.value)}>
                {CATEGORIES.map((c) => (
                  <option key={c}>{c}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label" htmlFor="color">Colour</label>
              <input id="color" className="field w-full" placeholder="Black" value={form.color}
                onChange={(e) => set("color", e.target.value)} />
            </div>
          </div>
        </section>

        <section className="panel space-y-4">
          <h2 className="font-display font-bold text-xl">
            Where and when {isFound ? "you found it" : "you lost it"}
          </h2>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="label" htmlFor="city">City</label>
              <input id="city" className="field w-full" placeholder="Jalandhar" value={form.city}
                onChange={(e) => set("city", e.target.value)} />
            </div>
            <div>
              <label className="label" htmlFor="date">Date</label>
              <input id="date" className="field w-full" type="date" required value={form.event_date}
                onChange={(e) => set("event_date", e.target.value)} />
            </div>
          </div>
          <div>
            <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
              <span className="label mb-0">Pin the spot on the map (optional)</span>
              <button type="button" onClick={useMyLocation} className="btn btn-small">
                Use my location
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
                ? `Pin saved at ${pin.lat.toFixed(4)}, ${pin.lng.toFixed(4)}. Matches will show the distance.`
                : "Click the map to drop a pin. Matches will show the distance."}
            </p>
          </div>
        </section>

        <section className="panel space-y-3">
          <h2 className="font-display font-bold text-xl">Photo</h2>
          <input type="file" accept="image/*" aria-label="Photo, optional, max 5 MB"
            className="field w-full"
            onChange={(e) => pickFile(e.target.files?.[0] ?? null)} />
          <p className="text-sm text-ink-soft">Optional. Up to 5 MB.</p>
          {file && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={URL.createObjectURL(file)} alt="Preview of the chosen photo"
              className="h-36 rounded-lg object-cover border-[1.5px] border-ink" />
          )}
        </section>

        {isFound && (
          <section className="panel space-y-4 bg-[#fff6cc]">
            <div>
              <h2 className="font-display font-bold text-xl">Verification question</h2>
              <p className="text-sm text-ink-soft">
                Only the real owner should know the answer. They must answer it before they
                see your contact details.
              </p>
            </div>
            <div>
              <label className="label" htmlFor="q">Question</label>
              <input id="q" className="field w-full" required
                placeholder="What is the phone wallpaper?"
                value={secret.question} onChange={(e) => setSec("question", e.target.value)} />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="label" htmlFor="a">Correct answer</label>
                <input id="a" className="field w-full" required placeholder="Dog"
                  value={secret.answer} onChange={(e) => setSec("answer", e.target.value)} />
              </div>
              <div>
                <label className="label" htmlFor="c">Your contact</label>
                <input id="c" className="field w-full" required placeholder="Phone or email"
                  value={secret.contact} onChange={(e) => setSec("contact", e.target.value)} />
              </div>
            </div>
          </section>
        )}

        <button disabled={loading} className="btn btn-primary w-full sm:w-auto">
          {loading ? "Finding matches..." : "Save and find matches"}
        </button>
      </form>

      {error && (
        <p role="alert" className="mt-5 rounded-lg border border-lost bg-lost-tint px-4 py-3 text-lost-dark">
          {error}
        </p>
      )}

      {matches && (
        <section ref={resultsRef} className="mt-10 scroll-mt-24">
          <h2 className="font-display font-extrabold text-2xl">Possible matches</h2>
          <p className="text-ink-soft mb-4">
            Ranked by description, distance and date. Each card says why it matched.
          </p>

          {matches.length === 0 ? (
            <div className="panel">
              <p className="font-semibold">No matches yet.</p>
              <p className="text-ink-soft">
                Your report is saved. Anyone who reports a similar item will be able to find
                it.
              </p>
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
                        role="img" aria-label={`${pct}% match`}>
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
                          {m.city ?? "Unknown city"}, {formatDate(m.event_date)}
                        </p>
                      </div>
                    </div>
                    {m.reasons.length > 0 && (
                      <>
                        <div className="ticket-perf mx-4" />
                        <div className="flex flex-wrap items-center gap-2 px-4 py-3">
                          <span className="mr-1 text-sm font-semibold">Why it matched</span>
                          {m.reasons.map((r) => (
                            <span key={r} className="chip">{r}</span>
                          ))}
                        </div>
                      </>
                    )}
                    {resultType === "lost" && (
                      <div className="px-4 pb-4">
                        <Link href={`/claim/${m.id}`} className="btn btn-primary btn-small">
                          Claim this item
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

write "src/components/Navbar.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";

export default function Navbar() {
  const pathname = usePathname();
  const [email, setEmail] = useState<string | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setEmail(data.session?.user.email ?? null);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, session) => {
      setEmail(session?.user.email ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const links = [
    { href: "/report", label: "Report" },
    { href: "/items", label: "Browse" },
    ...(email ? [{ href: "/my-reports", label: "My reports" }] : []),
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
          Pan-India Lost &amp; Found
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
          {email ? (
            <>
              <span className="hidden sm:inline text-ink-soft">{email}</span>
              <button className="btn btn-small" onClick={() => supabase.auth.signOut()}>
                Log out
              </button>
            </>
          ) : (
            <Link href="/login" className="btn btn-small btn-primary">
              Log in
            </Link>
          )}
        </div>
      </nav>
    </header>
  );
}
__LF_EOF__

write "src/components/TicketBand.tsx" <<'__LF_EOF__'
export default function TicketBand({ type, id }: { type: string; id?: string }) {
  const lost = type === "lost";
  return (
    <div className={`ticket-band ${lost ? "ticket-band-lost" : "ticket-band-found"}`}>
      <span className="ticket-hole" aria-hidden="true" />
      <span>{lost ? "Lost" : "Found"}</span>
      {id && <span className="ticket-ref">No. {id.slice(0, 4).toUpperCase()}</span>}
    </div>
  );
}
__LF_EOF__

write "src/lib/format.ts" <<'__LF_EOF__'
export function formatDate(iso: string) {
  const d = new Date(`${iso}T00:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}
__LF_EOF__


echo ""
echo "Done. Your old files are saved in $BACKUP/."
echo "Restart the dev server (Ctrl + C, then npm run dev) and open http://localhost:3000"
