"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";

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
    const { error } = await supabase
      .from("items")
      .update({ status: next })
      .eq("id", it.id);
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

  if (loading) return <main className="p-6">Loading...</main>;

  if (!loggedIn) {
    return (
      <main className="max-w-2xl mx-auto p-6">
        <h1 className="text-2xl font-bold mb-2">My reports</h1>
        <p className="mb-4">Log in to see your reports.</p>
        <Link href="/login" className="bg-blue-600 text-white rounded px-4 py-2">
          Log in
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-2xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-4">My reports</h1>
      {error && <p className="text-red-600 mb-3 text-sm">{error}</p>}
      {items.length === 0 && (
        <p>
          You have no reports yet.{" "}
          <Link href="/report" className="text-blue-600 underline">
            Report an item
          </Link>
        </p>
      )}

      <div className="space-y-3">
        {items.map((it) => {
          const current = STAGES.indexOf(it.status);
          const next = STAGES[current + 1];
          return (
            <div key={it.id} className="border rounded-lg p-4">
              <div className="flex gap-3">
                {it.image_url && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={it.image_url} alt={it.title}
                    className="h-16 w-16 rounded object-cover shrink-0" />
                )}
                <div className="flex-1">
                  <div className="flex justify-between items-start gap-2">
                    <p className="font-medium">{it.title}</p>
                    <span className={`text-xs px-2 py-1 rounded ${
                      it.type === "lost"
                        ? "bg-red-100 text-red-700"
                        : "bg-green-100 text-green-700"
                    }`}>
                      {it.type}
                    </span>
                  </div>
                  <p className="text-xs text-gray-500">
                    {it.category} | {it.city ?? "Unknown city"} | {it.event_date}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-1 mt-3 flex-wrap">
                {STAGES.map((s, i) => (
                  <span key={s} className="flex items-center gap-1">
                    <span className={`text-xs px-2 py-1 rounded ${
                      i <= current
                        ? "bg-blue-100 text-blue-700 font-medium"
                        : "bg-gray-100 text-gray-500"
                    }`}>
                      {s}
                    </span>
                    {i < STAGES.length - 1 && (
                      <span className="text-gray-400 text-xs">→</span>
                    )}
                  </span>
                ))}
              </div>

              <div className="flex gap-3 mt-3 text-sm">
                {next && (
                  <button onClick={() => advance(it)}
                    className="bg-blue-600 text-white rounded px-3 py-1">
                    Mark as {next}
                  </button>
                )}
                <button onClick={() => remove(it)}
                  className="text-red-600 underline">
                  Delete
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </main>
  );
}