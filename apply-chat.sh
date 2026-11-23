#!/bin/bash
# Adds in-app chat: Messages inbox, chat page, a "Message" button on report pages,
# a Messages link in the menu, and supabase/chat.sql.
# Run it from inside the lost-found folder (the one with package.json).
set -e

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "Run this inside the lost-found folder (the one that has package.json)."
  exit 1
fi

BACKUP="backup-before-chat"
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

write "src/app/items/[id]/page.tsx" <<'__LF_EOF__'
"use client";
import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
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
            {me && item.user_id && item.user_id !== me && (
              <button type="button" onClick={startChat} disabled={chatBusy} className="btn">
                {chatBusy
                  ? "Opening chat..."
                  : item.type === "found"
                  ? "Message the finder"
                  : "Message the owner"}
              </button>
            )}
            {!me && (
              <Link href="/login" className="btn">
                Log in to send a message
              </Link>
            )}
            <button type="button" onClick={copyLink} className="btn">
              {copied ? "Link copied" : "Copy link"}
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

write "src/app/messages/[id]/page.tsx" <<'__LF_EOF__'
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
__LF_EOF__

write "src/app/messages/page.tsx" <<'__LF_EOF__'
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
    ...(email
      ? [
          { href: "/my-reports", label: "My reports" },
          { href: "/messages", label: "Messages" },
        ]
      : []),
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

write "supabase/chat.sql" <<'__LF_EOF__'
-- In-app chat between the owner of a report and someone who contacts them.
-- Run in Supabase -> SQL Editor.

create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references items(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  starter_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  unique (item_id, starter_id)
);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz default now()
);

create index if not exists messages_conv_idx on messages (conversation_id, created_at);

alter table conversations enable row level security;
alter table messages enable row level security;

-- Only the two people in a conversation can read it
drop policy if exists "participants read conversations" on conversations;
create policy "participants read conversations" on conversations
  for select to authenticated
  using (auth.uid() in (owner_id, starter_id));

drop policy if exists "participants read messages" on messages;
create policy "participants read messages" on messages
  for select to authenticated
  using (exists (
    select 1 from conversations c
    where c.id = conversation_id and auth.uid() in (c.owner_id, c.starter_id)
  ));

-- ...and only they can write, always as themselves
drop policy if exists "participants send messages" on messages;
create policy "participants send messages" on messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from conversations c
      where c.id = conversation_id and auth.uid() in (c.owner_id, c.starter_id)
    )
  );

-- Starting a chat goes through a function, so nobody can invent a conversation
-- with someone else's report
create or replace function start_conversation(p_item uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Log in to send a message';
  end if;
  select user_id into v_owner from items where id = p_item;
  if v_owner is null then
    raise exception 'This report has no owner to message';
  end if;
  if v_owner = auth.uid() then
    raise exception 'This is your own report';
  end if;
  select id into v_id from conversations
    where item_id = p_item and starter_id = auth.uid();
  if v_id is null then
    insert into conversations (item_id, owner_id, starter_id)
      values (p_item, v_owner, auth.uid())
      returning id into v_id;
  end if;
  return v_id;
end $$;

grant execute on function start_conversation(uuid) to authenticated;

-- Live updates for new messages
do $$
begin
  alter publication supabase_realtime add table messages;
exception when duplicate_object then null;
end $$;
__LF_EOF__


echo ""
echo "Done. Next: run supabase/chat.sql in the Supabase SQL Editor."
echo "Then restart the dev server (Ctrl + C, then npm run dev)."
