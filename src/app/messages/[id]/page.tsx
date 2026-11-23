"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { supabase } from "@/lib/supabase";

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

const time = (iso: string) =>
  new Date(iso).toLocaleTimeString("en-IN", { hour: "numeric", minute: "2-digit" });

export default function ChatPage() {
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
        {
          event: "INSERT",
          schema: "public",
          table: "messages",
          filter: `conversation_id=eq.${id}`,
        },
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

  if (loading) return <main className="max-w-2xl mx-auto px-5 py-8">Loading chat...</main>;

  if (!me) {
    return (
      <main className="max-w-2xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">Messages</h1>
        <p className="mb-4 text-ink-soft">Log in to read your messages.</p>
        <Link href="/login" className="btn btn-primary">
          Log in
        </Link>
      </main>
    );
  }

  if (!conv) {
    return (
      <main className="max-w-2xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">Chat not found</h1>
        <p className="mb-4 text-ink-soft">
          This chat doesn&apos;t exist, or it belongs to other people.
        </p>
        <Link href="/messages" className="btn btn-primary">
          Back to messages
        </Link>
      </main>
    );
  }

  const otherLabel =
    me === conv.owner_id
      ? "Someone interested in this item"
      : conv.items?.type === "found"
      ? "The finder"
      : "The owner";

  return (
    <main className="max-w-2xl mx-auto px-5 py-8">
      <Link href="/messages" className="text-sm text-rail-dark underline">
        Back to messages
      </Link>

      <div className="ticket mt-4">
        <div className="ticket-band ticket-band-ink">
          <span className="ticket-hole" aria-hidden="true" />
          <span>{otherLabel}</span>
        </div>
        <div className="px-4 py-3 text-sm border-b-[1.5px] border-ink">
          About{" "}
          <Link href={`/items/${conv.item_id}`} className="font-semibold text-rail-dark underline">
            {conv.items?.title ?? "this report"}
          </Link>
          . Keep your phone number private until you are sure it is the right item.
        </div>

        <div ref={boxRef} className="h-[26rem] overflow-y-auto bg-paper p-4 space-y-3" aria-live="polite">
          {messages.length === 0 && (
            <p className="text-center text-sm text-ink-soft pt-10">
              No messages yet. Say hello and describe the item.
            </p>
          )}
          {messages.map((m) => {
            const mine = m.sender_id === me;
            return (
              <div key={m.id} className={`flex ${mine ? "justify-end" : "justify-start"}`}>
                <div
                  className={`max-w-[80%] rounded-2xl px-4 py-2 border-[1.5px] border-ink ${
                    mine ? "bg-rail text-white" : "bg-card"
                  }`}
                >
                  <p className="whitespace-pre-wrap break-words">{m.body}</p>
                  <p className={`mt-1 text-xs ${mine ? "text-white/80" : "text-ink-soft"}`}>
                    {time(m.created_at)}
                  </p>
                </div>
              </div>
            );
          })}
        </div>

        <form onSubmit={send} className="flex gap-2 p-3 border-t-[1.5px] border-ink bg-card">
          <input
            className="field flex-1"
            aria-label="Message"
            placeholder="Write a message"
            maxLength={1000}
            value={text}
            onChange={(e) => setText(e.target.value)}
          />
          <button disabled={sending || !text.trim()} className="btn btn-primary">
            {sending ? "Sending..." : "Send"}
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
