"use client";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import dynamic from "next/dynamic";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import { reasonText, useT } from "@/lib/i18n";
import TicketBand from "@/components/TicketBand";
import MapLoading from "@/components/MapLoading";

const MapPicker = dynamic(() => import("@/components/MapPicker"), {
  ssr: false,
  loading: () => <MapLoading />,
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
  const { t, td, lang } = useT();
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
    const q = new URLSearchParams(window.location.search).get("type");
    if (q === "found") {
      Promise.resolve().then(() => setForm((f) => ({ ...f, type: "found" })));
    }
  }, []);

  useEffect(() => {
    if (matches) resultsRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [matches]);

  const set = (k: string, v: string) => setForm({ ...form, [k]: v });
  const setSec = (k: string, v: string) => setSecret({ ...secret, [k]: v });

  function useMyLocation() {
    if (!navigator.geolocation) return setError(t("report.errNoLoc"));
    navigator.geolocation.getCurrentPosition(
      (pos) => setPin({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => setError(t("report.errLoc"))
    );
  }

  function pickFile(f: File | null) {
    setError("");
    if (f && !f.type.startsWith("image/")) return setError(t("report.errImage"));
    if (f && f.size > 5 * 1024 * 1024) return setError(t("report.errSize"));
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
      return setError(t("report.errLogin"));
    }

    let image_url: string | null = null;
    if (file) {
      const ext = file.name.split(".").pop() ?? "jpg";
      const path = `${crypto.randomUUID()}.${ext}`;
      const { error: upErr } = await supabase.storage.from("item-images").upload(path, file);
      if (upErr) {
        setLoading(false);
        return setError(t("report.errUpload", { msg: upErr.message }));
      }
      image_url = supabase.storage.from("item-images").getPublicUrl(path).data.publicUrl;
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
      return setError(data.error ?? t("report.errGeneric"));
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
        return setError(t("report.errSecret", { msg: secErr.message }));
      }
    }

    setLoading(false);
    setResultType(form.type);
    setMatches(data.matches ?? []);
  }

  const isFound = form.type === "found";

  if (checking) return <main className="max-w-3xl mx-auto px-5 py-8">{t("common.loading")}</main>;

  if (!email) {
    return (
      <main className="max-w-3xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">{t("report.title")}</h1>
        <p className="mb-4 text-ink-soft">{t("report.loginPrompt")}</p>
        <Link href="/login" className="btn btn-primary">
          {t("nav.login")}
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-3xl mx-auto px-5 py-8">
      <h1 className="font-display font-extrabold text-3xl">{t("report.title")}</h1>
      <p className="text-ink-soft mt-1 mb-6">{t("report.sub")}</p>

      <form onSubmit={submit} className="space-y-6">
        <div className="segmented w-full sm:w-auto" role="group" aria-label={t("report.typeAria")}>
          <button type="button" aria-pressed={!isFound} onClick={() => set("type", "lost")}>
            {t("report.iLost")}
          </button>
          <button type="button" aria-pressed={isFound} onClick={() => set("type", "found")}>
            {t("report.iFound")}
          </button>
        </div>

        <section className="panel space-y-4">
          <h2 className="font-display font-bold text-xl">{t("report.about")}</h2>
          <div>
            <label className="label" htmlFor="title">{t("report.fTitle")}</label>
            <input id="title" className="field w-full" required placeholder={t("report.titlePh")}
              value={form.title} onChange={(e) => set("title", e.target.value)} />
          </div>
          <div>
            <label className="label" htmlFor="description">{t("report.fDesc")}</label>
            <textarea id="description" className="field w-full" rows={3}
              placeholder={t("report.descPh")}
              value={form.description} onChange={(e) => set("description", e.target.value)} />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="label" htmlFor="category">{t("report.fCategory")}</label>
              <select id="category" className="field w-full" value={form.category}
                onChange={(e) => set("category", e.target.value)}>
                {CATEGORIES.map((c) => (
                  <option key={c} value={c}>{td(`cat.${c}`, c)}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label" htmlFor="color">{t("report.fColour")}</label>
              <input id="color" className="field w-full" placeholder={t("report.colourPh")}
                value={form.color} onChange={(e) => set("color", e.target.value)} />
            </div>
          </div>
        </section>

        <section className="panel space-y-4">
          <h2 className="font-display font-bold text-xl">
            {isFound ? t("report.whereFound") : t("report.whereLost")}
          </h2>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="label" htmlFor="city">{t("report.fCity")}</label>
              <input id="city" className="field w-full" placeholder={t("report.cityPh")}
                value={form.city} onChange={(e) => set("city", e.target.value)} />
            </div>
            <div>
              <label className="label" htmlFor="date">{t("report.fDate")}</label>
              <input id="date" className="field w-full" type="date" required value={form.event_date}
                onChange={(e) => set("event_date", e.target.value)} />
            </div>
          </div>
          <div>
            <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
              <span className="label mb-0">{t("report.pinLabel")}</span>
              <button type="button" onClick={useMyLocation} className="btn btn-small">
                {t("report.useLocation")}
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
                ? t("report.pinSaved", { lat: pin.lat.toFixed(4), lng: pin.lng.toFixed(4) })
                : t("report.pinHint")}
            </p>
          </div>
        </section>

        <section className="panel space-y-3">
          <h2 className="font-display font-bold text-xl">{t("report.photo")}</h2>
          <input type="file" accept="image/*" aria-label={t("report.photoAria")}
            className="field w-full"
            onChange={(e) => pickFile(e.target.files?.[0] ?? null)} />
          <p className="text-sm text-ink-soft">{t("report.photoHint")}</p>
          {file && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={URL.createObjectURL(file)} alt={t("report.photoPreview")}
              className="h-36 rounded-lg object-cover border-[1.5px] border-ink" />
          )}
        </section>

        {isFound && (
          <section className="panel space-y-4 bg-[#fff6cc]">
            <div>
              <h2 className="font-display font-bold text-xl">{t("report.verifyTitle")}</h2>
              <p className="text-sm text-ink-soft">{t("report.verifyHelp")}</p>
            </div>
            <div>
              <label className="label" htmlFor="q">{t("report.fQuestion")}</label>
              <input id="q" className="field w-full" required placeholder={t("report.qPh")}
                value={secret.question} onChange={(e) => setSec("question", e.target.value)} />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="label" htmlFor="a">{t("report.fAnswer")}</label>
                <input id="a" className="field w-full" required placeholder={t("report.aPh")}
                  value={secret.answer} onChange={(e) => setSec("answer", e.target.value)} />
              </div>
              <div>
                <label className="label" htmlFor="c">{t("report.fContact")}</label>
                <input id="c" className="field w-full" required placeholder={t("report.cPh")}
                  value={secret.contact} onChange={(e) => setSec("contact", e.target.value)} />
              </div>
            </div>
          </section>
        )}

        <button disabled={loading} className="btn btn-primary w-full sm:w-auto">
          {loading ? t("report.submitting") : t("report.submit")}
        </button>
      </form>

      {error && (
        <p role="alert" className="mt-5 rounded-lg border border-lost bg-lost-tint px-4 py-3 text-lost-dark">
          {error}
        </p>
      )}

      {matches && (
        <section ref={resultsRef} className="mt-10 scroll-mt-24">
          <h2 className="font-display font-extrabold text-2xl">{t("report.matches")}</h2>
          <p className="text-ink-soft mb-4">{t("report.matchesSub")}</p>

          {matches.length === 0 ? (
            <div className="panel">
              <p className="font-semibold">{t("report.noMatches")}</p>
              <p className="text-ink-soft">{t("report.noMatchesText")}</p>
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
                        role="img" aria-label={t("report.matchAria", { pct })}>
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
                          {m.city ?? t("common.unknownCity")}, {formatDate(m.event_date, lang)}
                        </p>
                      </div>
                    </div>
                    {m.reasons.length > 0 && (
                      <>
                        <div className="ticket-perf mx-4" />
                        <div className="flex flex-wrap items-center gap-2 px-4 py-3">
                          <span className="mr-1 text-sm font-semibold">{t("report.why")}</span>
                          {m.reasons.map((r) => (
                            <span key={r} className="chip">{reasonText(r, t)}</span>
                          ))}
                        </div>
                      </>
                    )}
                    {resultType === "lost" && (
                      <div className="px-4 pb-4">
                        <Link href={`/claim/${m.id}`} className="btn btn-primary btn-small">
                          {t("detail.claim")}
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
