#!/bin/bash
# Adds the admin dashboard: charts, an Admin link for admins, and supabase/admin.sql.
# Run it from inside the lost-found folder (the one with package.json).
set -e

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "Run this inside the lost-found folder (the one that has package.json)."
  exit 1
fi

BACKUP="backup-before-admin"
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

write "src/app/admin/page.tsx" <<'__LF_EOF__'
"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import dynamic from "next/dynamic";
import { supabase } from "@/lib/supabase";
import { Donut, LineChart, SimpleBars, StackedBars, type DayPoint } from "@/components/charts";
import type { MapPoint } from "@/components/MapView";

const MapView = dynamic(() => import("@/components/MapView"), {
  ssr: false,
  loading: () => <p className="p-4 text-sm text-ink-soft">Loading map...</p>,
});

type Stats = {
  totals: {
    reports: number;
    lost: number;
    found: number;
    open: number;
    matched: number;
    claimed: number;
    returned: number;
  };
  users: number;
  conversations: number;
  messages: number;
  per_day: DayPoint[];
  by_category: { category: string; lost: number; found: number }[];
  top_cities: { city: string; total: number }[];
  points: MapPoint[];
};

export default function AdminPage() {
  const [state, setState] = useState<"loading" | "login" | "denied" | "ready">("loading");
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState("");
  const [refreshing, setRefreshing] = useState(false);

  const loadStats = useCallback(async () => {
    setError("");
    const { data, error } = await supabase.rpc("admin_stats");
    if (error) {
      setError(error.message);
      return false;
    }
    setStats(data as Stats);
    return true;
  }, []);

  useEffect(() => {
    async function init() {
      const { data: s } = await supabase.auth.getSession();
      if (!s.session) return setState("login");
      const { data: isAdmin } = await supabase.rpc("is_admin");
      if (isAdmin !== true) return setState("denied");
      const ok = await loadStats();
      setState(ok ? "ready" : "denied");
    }
    init();
  }, [loadStats]);

  async function refresh() {
    setRefreshing(true);
    await loadStats();
    setRefreshing(false);
  }

  const mapPoints = useMemo(() => stats?.points ?? [], [stats]);

  if (state === "loading") {
    return <main className="max-w-6xl mx-auto px-5 py-8">Loading dashboard...</main>;
  }

  if (state === "login") {
    return (
      <main className="max-w-6xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">Admin dashboard</h1>
        <p className="mb-4 text-ink-soft">Log in with an admin account to continue.</p>
        <Link href="/login" className="btn btn-primary">
          Log in
        </Link>
      </main>
    );
  }

  if (state === "denied" || !stats) {
    return (
      <main className="max-w-6xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">Admins only</h1>
        <p className="mb-4 text-ink-soft">This page is only for admin accounts.</p>
        {error && <p className="text-sm text-ink-soft">{error}</p>}
        <Link href="/" className="btn mt-4">
          Back to home
        </Link>
      </main>
    );
  }

  const t = stats.totals;
  const recovery = t.reports > 0 ? Math.round((t.returned / t.reports) * 100) : 0;

  const kpis: [string, string | number, string][] = [
    ["Reports", t.reports, "All lost and found reports"],
    ["Users", stats.users, "Registered accounts"],
    ["Recovery rate", `${recovery}%`, "Returned reports out of all reports"],
    ["Open now", t.open, "Reports still waiting"],
    ["Conversations", stats.conversations, "Chats started"],
    ["Messages", stats.messages, "Messages sent"],
  ];

  return (
    <main className="max-w-6xl mx-auto px-5 py-8">
      <div className="flex flex-wrap items-end justify-between gap-4 mb-6">
        <div>
          <h1 className="font-display font-extrabold text-3xl">Admin dashboard</h1>
          <p className="text-ink-soft">Live numbers from the database.</p>
        </div>
        <button onClick={refresh} disabled={refreshing} className="btn">
          {refreshing ? "Refreshing..." : "Refresh"}
        </button>
      </div>

      {error && (
        <p role="alert" className="mb-4 rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
          {error}
        </p>
      )}

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-3 xl:grid-cols-6">
        {kpis.map(([label, value, hint]) => (
          <div key={label} className="ticket px-4 py-3">
            <p className="font-display font-extrabold text-3xl">{value}</p>
            <p className="font-semibold">{label}</p>
            <p className="text-xs text-ink-soft">{hint}</p>
          </div>
        ))}
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-3">
        <section className="panel lg:col-span-2">
          <h2 className="font-display font-bold text-xl mb-3">Items lost or found per day</h2>
          <LineChart data={stats.per_day} />
        </section>
        <section className="panel">
          <h2 className="font-display font-bold text-xl mb-3">Lost and found</h2>
          <Donut
            centerLabel="reports"
            parts={[
              { label: "Lost", value: t.lost, color: "#c23b20" },
              { label: "Found", value: t.found, color: "#14815a" },
            ]}
          />
        </section>
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <section className="panel">
          <h2 className="font-display font-bold text-xl mb-3">Reports by category</h2>
          <StackedBars
            rows={stats.by_category.map((c) => ({
              label: c.category,
              lost: c.lost,
              found: c.found,
            }))}
          />
        </section>
        <section className="panel">
          <h2 className="font-display font-bold text-xl mb-1">From report to return</h2>
          <p className="text-sm text-ink-soft mb-3">How many reports are at each stage.</p>
          <SimpleBars
            color="#1e40d8"
            rows={[
              { label: "open", value: t.open },
              { label: "matched", value: t.matched },
              { label: "claimed", value: t.claimed },
              { label: "returned", value: t.returned },
            ]}
          />
        </section>
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <section className="panel">
          <h2 className="font-display font-bold text-xl mb-3">Top cities</h2>
          <SimpleBars
            color="#0e1a3a"
            rows={stats.top_cities.map((c) => ({ label: c.city, value: c.total }))}
          />
        </section>
        <section className="panel">
          <h2 className="font-display font-bold text-xl mb-3">Where reports happen</h2>
          <div className="isolate overflow-hidden rounded-xl border-[1.5px] border-ink">
            <MapView points={mapPoints} height={340} popups={false} />
          </div>
          <p className="mt-2 text-sm text-ink-soft">
            Red is lost, green is found. Shows the latest {mapPoints.length} reports with a pin.
          </p>
        </section>
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
  const [isAdmin, setIsAdmin] = useState(false);

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
    { href: "/report", label: "Report" },
    { href: "/items", label: "Browse" },
    ...(email
      ? [
          { href: "/my-reports", label: "My reports" },
          { href: "/messages", label: "Messages" },
        ]
      : []),
    ...(isAdmin ? [{ href: "/admin", label: "Admin" }] : []),
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

write "src/components/charts.tsx" <<'__LF_EOF__'
// Small SVG and CSS charts with no extra libraries.

const LOST = "#c23b20";
const FOUND = "#14815a";
const INK = "#0e1a3a";
const SOFT = "#4a5675";
const GRID = "#d7deec";

export type DayPoint = { day: string; lost: number; found: number };

const dayLabel = (iso: string) =>
  new Date(`${iso}T00:00:00`).toLocaleDateString("en-IN", { day: "numeric", month: "short" });

export function LineChart({ data }: { data: DayPoint[] }) {
  const W = 640;
  const H = 240;
  const L = 34;
  const R = 12;
  const T = 12;
  const B = 28;

  const max = Math.max(1, ...data.flatMap((d) => [d.lost, d.found]));
  const top = Math.max(4, Math.ceil(max / 4) * 4);
  const x = (i: number) => L + (data.length <= 1 ? 0 : (i * (W - L - R)) / (data.length - 1));
  const y = (v: number) => T + (H - T - B) * (1 - v / top);
  const path = (key: "lost" | "found") =>
    data.map((d, i) => `${i === 0 ? "M" : "L"}${x(i).toFixed(1)} ${y(d[key]).toFixed(1)}`).join(" ");
  const ticks = [0, 1, 2, 3, 4].map((k) => (top * k) / 4);

  return (
    <div>
      <svg
        viewBox={`0 0 ${W} ${H}`}
        width="100%"
        role="img"
        aria-label="Items lost and found per day over the last 30 days"
      >
        {ticks.map((t) => (
          <g key={t}>
            <line x1={L} x2={W - R} y1={y(t)} y2={y(t)} stroke={GRID} strokeWidth="1" />
            <text x={L - 6} y={y(t) + 4} fontSize="11" textAnchor="end" fill={SOFT}>
              {t}
            </text>
          </g>
        ))}
        {data.map((d, i) =>
          i % 5 === 0 || i === data.length - 1 ? (
            <text key={d.day} x={x(i)} y={H - 8} fontSize="11" textAnchor="middle" fill={SOFT}>
              {dayLabel(d.day)}
            </text>
          ) : null
        )}
        <path d={path("lost")} fill="none" stroke={LOST} strokeWidth="2.5" strokeLinejoin="round" />
        <path d={path("found")} fill="none" stroke={FOUND} strokeWidth="2.5" strokeLinejoin="round" />
        {data.map((d, i) => (
          <g key={d.day}>
            {d.lost > 0 && (
              <circle cx={x(i)} cy={y(d.lost)} r="3.5" fill={LOST} stroke={INK} strokeWidth="1">
                <title>{`${dayLabel(d.day)}: ${d.lost} lost`}</title>
              </circle>
            )}
            {d.found > 0 && (
              <circle cx={x(i)} cy={y(d.found)} r="3.5" fill={FOUND} stroke={INK} strokeWidth="1">
                <title>{`${dayLabel(d.day)}: ${d.found} found`}</title>
              </circle>
            )}
          </g>
        ))}
      </svg>
      <p className="mt-1 flex gap-4 text-sm text-ink-soft">
        <span>
          <span className="inline-block h-2.5 w-5 rounded-full align-middle" style={{ background: LOST }} />{" "}
          Lost
        </span>
        <span>
          <span className="inline-block h-2.5 w-5 rounded-full align-middle" style={{ background: FOUND }} />{" "}
          Found
        </span>
      </p>
    </div>
  );
}

export function Donut({
  parts,
  centerLabel,
}: {
  parts: { label: string; value: number; color: string }[];
  centerLabel: string;
}) {
  const r = 54;
  const c = 2 * Math.PI * r;
  const total = parts.reduce((s, p) => s + p.value, 0);
  let acc = 0;

  return (
    <div className="flex flex-col items-center gap-4 sm:flex-row lg:flex-col xl:flex-row">
      <svg viewBox="0 0 140 140" width="150" height="150" role="img" aria-label={`${centerLabel}: ${total}`}>
        <circle cx="70" cy="70" r={r} fill="none" stroke={GRID} strokeWidth="18" />
        {total > 0 &&
          parts.map((p) => {
            const len = (p.value / total) * c;
            const el = (
              <circle
                key={p.label}
                cx="70"
                cy="70"
                r={r}
                fill="none"
                stroke={p.color}
                strokeWidth="18"
                strokeDasharray={`${len.toFixed(2)} ${(c - len).toFixed(2)}`}
                strokeDashoffset={(-acc).toFixed(2)}
                transform="rotate(-90 70 70)"
              />
            );
            acc += len;
            return el;
          })}
        <text x="70" y="68" textAnchor="middle" fontSize="26" fontWeight="800" fill={INK}>
          {total}
        </text>
        <text x="70" y="86" textAnchor="middle" fontSize="11" fill={SOFT}>
          {centerLabel}
        </text>
      </svg>
      <ul className="space-y-1 text-sm">
        {parts.map((p) => (
          <li key={p.label} className="flex items-center gap-2">
            <span className="inline-block h-3 w-3 rounded-sm border border-ink" style={{ background: p.color }} />
            <span>
              {p.label}: <strong>{p.value}</strong>
              {total > 0 && <span className="text-ink-soft"> ({Math.round((p.value / total) * 100)}%)</span>}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

export function StackedBars({ rows }: { rows: { label: string; lost: number; found: number }[] }) {
  const max = Math.max(1, ...rows.map((r) => r.lost + r.found));
  return (
    <div className="space-y-3">
      {rows.map((r) => (
        <div key={r.label}>
          <div className="mb-1 flex justify-between text-sm">
            <span className="font-semibold capitalize">{r.label}</span>
            <span className="text-ink-soft">
              {r.lost} lost, {r.found} found
            </span>
          </div>
          <div className="flex h-5 overflow-hidden rounded-md border-[1.5px] border-ink bg-paper">
            <div style={{ width: `${(r.lost / max) * 100}%`, background: LOST }} />
            <div style={{ width: `${(r.found / max) * 100}%`, background: FOUND }} />
          </div>
        </div>
      ))}
      {rows.length === 0 && <p className="text-sm text-ink-soft">No data yet.</p>}
    </div>
  );
}

export function SimpleBars({
  rows,
  color,
}: {
  rows: { label: string; value: number }[];
  color: string;
}) {
  const max = Math.max(1, ...rows.map((r) => r.value));
  return (
    <div className="space-y-3">
      {rows.map((r) => (
        <div key={r.label}>
          <div className="mb-1 flex justify-between text-sm">
            <span className="font-semibold capitalize">{r.label}</span>
            <span className="text-ink-soft">{r.value}</span>
          </div>
          <div className="h-5 overflow-hidden rounded-md border-[1.5px] border-ink bg-paper">
            <div className="h-full" style={{ width: `${(r.value / max) * 100}%`, background: color }} />
          </div>
        </div>
      ))}
      {rows.length === 0 && <p className="text-sm text-ink-soft">No data yet.</p>}
    </div>
  );
}
__LF_EOF__

write "supabase/admin.sql" <<'__LF_EOF__'
-- Admin dashboard: who is an admin, and the numbers the dashboard shows.
-- Run in Supabase -> SQL Editor.

create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

alter table admins enable row level security;
-- no policies on purpose: nobody can read or edit this table from the app

create or replace function is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;

grant execute on function is_admin() to authenticated;

create or replace function admin_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'Admins only';
  end if;

  return jsonb_build_object(
    'totals', (
      select jsonb_build_object(
        'reports', count(*),
        'lost', count(*) filter (where type = 'lost'),
        'found', count(*) filter (where type = 'found'),
        'open', count(*) filter (where status = 'open'),
        'matched', count(*) filter (where status = 'matched'),
        'claimed', count(*) filter (where status = 'claimed'),
        'returned', count(*) filter (where status = 'returned')
      ) from items
    ),
    'users', (select count(*) from auth.users),
    'conversations', (select count(*) from conversations),
    'messages', (select count(*) from messages),
    'per_day', (
      select coalesce(
        jsonb_agg(jsonb_build_object('day', d.day, 'lost', d.lost, 'found', d.found) order by d.day),
        '[]'::jsonb
      )
      from (
        select to_char(g::date, 'YYYY-MM-DD') as day,
               count(i.id) filter (where i.type = 'lost') as lost,
               count(i.id) filter (where i.type = 'found') as found
        from generate_series(current_date - 29, current_date, interval '1 day') as g
        left join items i on i.event_date = g::date
        group by g
      ) d
    ),
    'by_category', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object('category', c.category, 'lost', c.lost, 'found', c.found)
          order by c.total desc
        ),
        '[]'::jsonb
      )
      from (
        select category,
               count(*) filter (where type = 'lost') as lost,
               count(*) filter (where type = 'found') as found,
               count(*) as total
        from items
        group by category
      ) c
    ),
    'top_cities', (
      select coalesce(
        jsonb_agg(jsonb_build_object('city', t.city, 'total', t.total) order by t.total desc),
        '[]'::jsonb
      )
      from (
        select initcap(lower(trim(city))) as city, count(*) as total
        from items
        where city is not null and trim(city) <> ''
        group by 1
        order by 2 desc
        limit 8
      ) t
    ),
    'points', (
      select coalesce(
        jsonb_agg(jsonb_build_object('id', p.id, 'lat', p.lat, 'lng', p.lng, 'type', p.type, 'title', p.title)),
        '[]'::jsonb
      )
      from (
        select id, lat, lng, type, title
        from items
        where lat is not null and lng is not null
        order by created_at desc
        limit 300
      ) p
    )
  );
end $$;

grant execute on function admin_stats() to authenticated;

-- Make yourself an admin (change the email, then run this line once):
-- insert into admins (user_id) select id from auth.users where email = 'you@example.com' on conflict do nothing;
__LF_EOF__


echo ""
echo "Done. Next: run supabase/admin.sql in the Supabase SQL Editor,"
echo "then make yourself an admin (the last line of that file)."
