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
