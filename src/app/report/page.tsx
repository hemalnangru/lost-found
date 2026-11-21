"use client";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import dynamic from "next/dynamic";
import { supabase } from "@/lib/supabase";
import { formatDate } from "@/lib/format";
import TicketBand from "@/components/TicketBand";

const MapPicker = dynamic(() => import("@/components/MapPicker"), {
  ssr: false,
  loading: () => <p className="p-4 text-sm text-ink-soft">Loading map...</p>,
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
    const t = new URLSearchParams(window.location.search).get("type");
    if (t === "found") {
      Promise.resolve().then(() => setForm((f) => ({ ...f, type: "found" })));
    }
  }, []);

  useEffect(() => {
    if (matches) resultsRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [matches]);

  const set = (k: string, v: string) => setForm({ ...form, [k]: v });
  const setSec = (k: string, v: string) => setSecret({ ...secret, [k]: v });

  function useMyLocation() {
    if (!navigator.geolocation) {
      return setError("Your browser doesn't support location. Click the map instead.");
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => setPin({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => setError("Couldn't get your location. Click the map instead.")
    );
  }

  function pickFile(f: File | null) {
    setError("");
    if (f && !f.type.startsWith("image/")) {
      setError("Choose an image file.");
      return;
    }
    if (f && f.size > 5 * 1024 * 1024) {
      setError("The image must be under 5 MB.");
      return;
    }
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
      return setError("Log in first.");
    }

    let image_url: string | null = null;
    if (file) {
      const ext = file.name.split(".").pop() ?? "jpg";
      const path = `${crypto.randomUUID()}.${ext}`;
      const { error: upErr } = await supabase.storage
        .from("item-images")
        .upload(path, file);
      if (upErr) {
        setLoading(false);
        return setError("Image upload failed: " + upErr.message);
      }
      image_url = supabase.storage.from("item-images").getPublicUrl(path)
        .data.publicUrl;
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
      return setError(data.error ?? "Something went wrong. Try again.");
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
        return setError("Couldn't save the verification details: " + secErr.message);
      }
    }

    setLoading(false);
    setResultType(form.type);
    setMatches(data.matches ?? []);
  }

  const isFound = form.type === "found";

  if (checking) return <main className="max-w-3xl mx-auto px-5 py-8">Loading...</main>;

  if (!email) {
    return (
      <main className="max-w-3xl mx-auto px-5 py-8">
        <h1 className="font-display font-extrabold text-3xl mb-2">Report an item</h1>
        <p className="mb-4 text-ink-soft">Log in to report a lost or found item.</p>
        <Link href="/login" className="btn btn-primary">
          Log in
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-3xl mx-auto px-5 py-8">
      <h1 className="font-display font-extrabold text-3xl">Report an item</h1>
      <p className="text-ink-soft mt-1 mb-6">The more detail you add, the better the matches.</p>

      <form onSubmit={submit} className="space-y-6">
        <div className="segmented w-full sm:w-auto" role="group" aria-label="Report type">
          <button type="button" aria-pressed={!isFound} onClick={() => set("type", "lost")}>
            I lost something
          </button>
          <button type="button" aria-pressed={isFound} onClick={() => set("type", "found")}>
            I found something
          </button>
        </div>

        <section className="panel space-y-4">
          <h2 className="font-display font-bold text-xl">About the item</h2>
          <div>
            <label className="label" htmlFor="title">Title</label>
            <input id="title" className="field w-full" required placeholder="Black Samsung phone"
              value={form.title} onChange={(e) => set("title", e.target.value)} />
          </div>
          <div>
            <label className="label" htmlFor="description">Description</label>
            <textarea id="description" className="field w-full" rows={3}
              placeholder="Cracked screen, dog wallpaper, blue case"
              value={form.description} onChange={(e) => set("description", e.target.value)} />
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="label" htmlFor="category">Category</label>
              <select id="category" className="field w-full" value={form.category}
                onChange={(e) => set("category", e.target.value)}>
                {CATEGORIES.map((c) => (
                  <option key={c}>{c}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label" htmlFor="color">Colour</label>
              <input id="color" className="field w-full" placeholder="Black" value={form.color}
                onChange={(e) => set("color", e.target.value)} />
            </div>
          </div>
        </section>

        <section className="panel space-y-4">
          <h2 className="font-display font-bold text-xl">
            Where and when {isFound ? "you found it" : "you lost it"}
          </h2>
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label className="label" htmlFor="city">City</label>
              <input id="city" className="field w-full" placeholder="Jalandhar" value={form.city}
                onChange={(e) => set("city", e.target.value)} />
            </div>
            <div>
              <label className="label" htmlFor="date">Date</label>
              <input id="date" className="field w-full" type="date" required value={form.event_date}
                onChange={(e) => set("event_date", e.target.value)} />
            </div>
          </div>
          <div>
            <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
              <span className="label mb-0">Pin the spot on the map (optional)</span>
              <button type="button" onClick={useMyLocation} className="btn btn-small">
                Use my location
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
                ? `Pin saved at ${pin.lat.toFixed(4)}, ${pin.lng.toFixed(4)}. Matches will show the distance.`
                : "Click the map to drop a pin. Matches will show the distance."}
            </p>
          </div>
        </section>

        <section className="panel space-y-3">
          <h2 className="font-display font-bold text-xl">Photo</h2>
          <input type="file" accept="image/*" aria-label="Photo, optional, max 5 MB"
            className="field w-full"
            onChange={(e) => pickFile(e.target.files?.[0] ?? null)} />
          <p className="text-sm text-ink-soft">Optional. Up to 5 MB.</p>
          {file && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={URL.createObjectURL(file)} alt="Preview of the chosen photo"
              className="h-36 rounded-lg object-cover border-[1.5px] border-ink" />
          )}
        </section>

        {isFound && (
          <section className="panel space-y-4 bg-[#fff6cc]">
            <div>
              <h2 className="font-display font-bold text-xl">Verification question</h2>
              <p className="text-sm text-ink-soft">
                Only the real owner should know the answer. They must answer it before they
                see your contact details.
              </p>
            </div>
            <div>
              <label className="label" htmlFor="q">Question</label>
              <input id="q" className="field w-full" required
                placeholder="What is the phone wallpaper?"
                value={secret.question} onChange={(e) => setSec("question", e.target.value)} />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="label" htmlFor="a">Correct answer</label>
                <input id="a" className="field w-full" required placeholder="Dog"
                  value={secret.answer} onChange={(e) => setSec("answer", e.target.value)} />
              </div>
              <div>
                <label className="label" htmlFor="c">Your contact</label>
                <input id="c" className="field w-full" required placeholder="Phone or email"
                  value={secret.contact} onChange={(e) => setSec("contact", e.target.value)} />
              </div>
            </div>
          </section>
        )}

        <button disabled={loading} className="btn btn-primary w-full sm:w-auto">
          {loading ? "Finding matches..." : "Save and find matches"}
        </button>
      </form>

      {error && (
        <p role="alert" className="mt-5 rounded-lg border border-lost bg-lost-tint px-4 py-3 text-lost-dark">
          {error}
        </p>
      )}

      {matches && (
        <section ref={resultsRef} className="mt-10 scroll-mt-24">
          <h2 className="font-display font-extrabold text-2xl">Possible matches</h2>
          <p className="text-ink-soft mb-4">
            Ranked by description, distance and date. Each card says why it matched.
          </p>

          {matches.length === 0 ? (
            <div className="panel">
              <p className="font-semibold">No matches yet.</p>
              <p className="text-ink-soft">
                Your report is saved. Anyone who reports a similar item will be able to find
                it.
              </p>
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
                        role="img" aria-label={`${pct}% match`}>
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
                          {m.city ?? "Unknown city"}, {formatDate(m.event_date)}
                        </p>
                      </div>
                    </div>
                    {m.reasons.length > 0 && (
                      <>
                        <div className="ticket-perf mx-4" />
                        <div className="flex flex-wrap items-center gap-2 px-4 py-3">
                          <span className="mr-1 text-sm font-semibold">Why it matched</span>
                          {m.reasons.map((r) => (
                            <span key={r} className="chip">{r}</span>
                          ))}
                        </div>
                      </>
                    )}
                    {resultType === "lost" && (
                      <div className="px-4 pb-4">
                        <Link href={`/claim/${m.id}`} className="btn btn-primary btn-small">
                          Claim this item
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
