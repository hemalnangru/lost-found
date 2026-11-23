"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";

type Conv = {
  id: string;
  item_id: string;
  owner_id: string;
  starter_id: string;
  created_at: string;
  items: { title: string; type: string } | null;
};

type Last = { body: string; created_at: string; sender_id: string };

function when(iso: string) {
  const d = new Date(iso);
  const today = new Date();
  return d.toDateString() === today.toDateString()
    ? d.toLocaleTimeString("en-IN", { hour: "numeric", minute: "2-digit" })
    : d.toLocaleDateString("en-IN", { day: "numeric", month: "short" });
}

export default function MessagesPage() {
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

  if (loading) return <main className="max-w-2xl mx-auto px-5 py-8">Loading messages...</main>;

  if (!me) {
    return (
      <main className="max-w-2xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">Messages</h1>
        <p className="mb-4 text-ink-soft">Log in to see your messages.</p>
        <Link href="/login" className="btn btn-primary">
          Log in
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-2xl mx-auto px-5 py-8">
      <h1 className="font-display font-extrabold text-3xl">Messages</h1>
      <p className="text-ink-soft mt-1 mb-6">
        Chat with the owner or finder without sharing your phone number.
      </p>

      {error && (
        <p role="alert" className="mb-4 rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
          {error}
        </p>
      )}

      {convs.length === 0 && !error && (
        <div className="panel">
          <p className="font-semibold">No conversations yet.</p>
          <p className="text-ink-soft">
            Open a report and choose{" "}
            <Link href="/items" className="text-rail-dark underline">
              Message the finder or Message the owner
            </Link>
            .
          </p>
        </div>
      )}

      <div className="space-y-3">
        {convs.map((c) => {
          const l = last[c.id];
          const who =
            me === c.owner_id
              ? "Someone interested in this item"
              : c.items?.type === "found"
              ? "The finder"
              : "The owner";
          return (
            <Link key={c.id} href={`/messages/${c.id}`} className="ticket block hover:bg-rail-tint">
              <div className="px-4 py-3">
                <div className="flex items-baseline justify-between gap-3">
                  <p className="font-display font-bold text-lg leading-snug">
                    {c.items?.title ?? "Report"}
                  </p>
                  <span className="text-xs text-ink-soft shrink-0">
                    {when(l?.created_at ?? c.created_at)}
                  </span>
                </div>
                <p className="text-sm text-ink-soft">{who}</p>
                <p className="mt-1 text-sm truncate">
                  {l ? `${l.sender_id === me ? "You: " : ""}${l.body}` : "No messages yet"}
                </p>
              </div>
            </Link>
          );
        })}
      </div>
    </main>
  );
}
