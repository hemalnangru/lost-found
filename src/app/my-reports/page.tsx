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
