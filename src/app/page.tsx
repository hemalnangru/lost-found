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
