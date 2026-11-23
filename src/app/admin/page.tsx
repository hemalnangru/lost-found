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
