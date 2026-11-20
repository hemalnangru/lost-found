"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import dynamic from "next/dynamic";
import { supabase } from "@/lib/supabase";

const MapPicker = dynamic(() => import("@/components/MapPicker"), {
  ssr: false,
  loading: () => <p className="text-sm text-gray-500">Loading map...</p>,
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

  const set = (k: string, v: string) => setForm({ ...form, [k]: v });
  const setSec = (k: string, v: string) => setSecret({ ...secret, [k]: v });

  function useMyLocation() {
    if (!navigator.geolocation) {
      return setError("Your browser does not support location");
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => setPin({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => setError("Could not get your location. Click on the map instead.")
    );
  }

  function pickFile(f: File | null) {
    setError("");
    if (f && !f.type.startsWith("image/")) {
      setError("Please choose an image file");
      return;
    }
    if (f && f.size > 5 * 1024 * 1024) {
      setError("Image must be under 5 MB");
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
      return setError("Please log in first");
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
      return setError(data.error ?? "Something went wrong");
    }

    // Found items: save the hidden question, answer and contact
    if (form.type === "found") {
      const { error: secErr } = await supabase.from("item_secrets").insert({
        item_id: data.item.id,
        question: secret.question.trim(),
        answer: secret.answer.trim(),
        contact: secret.contact.trim(),
      });
      if (secErr) {
        setLoading(false);
        return setError("Could not save verification details: " + secErr.message);
      }
    }

    setLoading(false);
    setResultType(form.type);
    setMatches(data.matches ?? []);
  }

  const input = "w-full border rounded p-2";
  const isFound = form.type === "found";

  if (checking) return <main className="p-6">Loading...</main>;

  if (!email) {
    return (
      <main className="max-w-xl mx-auto p-6">
        <h1 className="text-2xl font-bold mb-2">Report an item</h1>
        <p className="mb-4">You need to log in to report a lost or found item.</p>
        <Link href="/login" className="bg-blue-600 text-white rounded px-4 py-2">
          Log in / Sign up
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-xl mx-auto p-6">
      <div className="flex justify-between items-center mb-4">
        <h1 className="text-2xl font-bold">Report an item</h1>
        <div className="text-right text-xs">
          <p className="text-gray-500">{email}</p>
          <button className="text-blue-600 underline"
            onClick={() => supabase.auth.signOut()}>
            Log out
          </button>
        </div>
      </div>

      <form onSubmit={submit} className="space-y-3">
        <select className={input} value={form.type} onChange={(e) => set("type", e.target.value)}>
          <option value="lost">I lost something</option>
          <option value="found">I found something</option>
        </select>
        <input className={input} placeholder="Title (e.g. Black Samsung phone)" required
          value={form.title} onChange={(e) => set("title", e.target.value)} />
        <textarea className={input} placeholder="Description (scratches, wallpaper, contents...)"
          value={form.description} onChange={(e) => set("description", e.target.value)} />
        <select className={input} value={form.category} onChange={(e) => set("category", e.target.value)}>
          {["phone", "wallet", "bag", "keys", "documents", "laptop", "other"].map((c) => (
            <option key={c}>{c}</option>
          ))}
        </select>
        <input className={input} placeholder="Colour" value={form.color}
          onChange={(e) => set("color", e.target.value)} />
        <input className={input} placeholder="City" value={form.city}
          onChange={(e) => set("city", e.target.value)} />
        <input className={input} type="date" required value={form.event_date}
          onChange={(e) => set("event_date", e.target.value)} />

        <div>
          <div className="flex justify-between items-center mb-1">
            <label className="block text-sm">
              Where? Click the map to drop a pin (optional)
            </label>
            <button type="button" onClick={useMyLocation}
              className="text-xs text-blue-600 underline">
              Use my location
            </button>
          </div>
          <MapPicker
            lat={pin?.lat ?? null}
            lng={pin?.lng ?? null}
            onPick={(lat, lng) => setPin({ lat, lng })}
          />
          {pin && (
            <p className="text-xs text-gray-500 mt-1">
              Pin saved: {pin.lat.toFixed(4)}, {pin.lng.toFixed(4)}
            </p>
          )}
        </div>

        <div>
          <label className="block text-sm mb-1">Photo (optional, max 5 MB)</label>
          <input type="file" accept="image/*" className={input}
            onChange={(e) => pickFile(e.target.files?.[0] ?? null)} />
          {file && (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={URL.createObjectURL(file)} alt="Preview"
              className="mt-2 h-32 rounded object-cover" />
          )}
        </div>

        {isFound && (
          <div className="border rounded p-3 space-y-2 bg-yellow-50 text-black">
            <p className="text-sm font-medium">
              Verification (hidden). The owner must answer this before seeing your contact.
            </p>
            <input className={input} required
              placeholder="Question (e.g. What is the phone wallpaper?)"
              value={secret.question} onChange={(e) => setSec("question", e.target.value)} />
            <input className={input} required
              placeholder="Correct answer (e.g. dog)"
              value={secret.answer} onChange={(e) => setSec("answer", e.target.value)} />
            <input className={input} required
              placeholder="Your contact (phone or email), shared only after a correct answer"
              value={secret.contact} onChange={(e) => setSec("contact", e.target.value)} />
          </div>
        )}

        <button disabled={loading} className="bg-blue-600 text-white rounded px-4 py-2">
          {loading ? "Searching..." : "Submit and find matches"}
        </button>
      </form>

      {error && <p className="text-red-600 mt-4">{error}</p>}

      {matches && (
        <section className="mt-6">
          <h2 className="font-semibold mb-2">Possible matches</h2>
          {matches.length === 0 && <p>No matches yet. We will keep looking.</p>}
          {matches.map((m) => (
            <div key={m.id} className="border rounded p-3 mb-2 flex gap-3">
              {m.image_url && (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={m.image_url} alt={m.title}
                  className="h-20 w-20 rounded object-cover shrink-0" />
              )}
              <div className="flex-1">
                <div className="flex justify-between items-start">
                  <p className="font-medium">{m.title}</p>
                  <span className="text-sm font-bold text-green-600">
                    {Math.round(m.score * 100)}% match
                  </span>
                </div>
                {m.description && (
                  <p className="text-sm text-gray-500">{m.description}</p>
                )}
                <p className="text-xs text-gray-500 mt-1">
                  {m.city ?? "Unknown city"} | {m.event_date}
                </p>
                {m.reasons.length > 0 && (
                  <div className="flex flex-wrap gap-1 mt-2">
                    {m.reasons.map((r) => (
                      <span key={r} className="text-xs bg-blue-100 text-blue-700 rounded px-2 py-0.5">
                        {r}
                      </span>
                    ))}
                  </div>
                )}
                {resultType === "lost" && (
                  <Link href={`/claim/${m.id}`}
                    className="inline-block mt-2 text-sm bg-green-600 text-white rounded px-3 py-1">
                    This is mine, claim it
                  </Link>
                )}
              </div>
            </div>
          ))}
        </section>
      )}
    </main>
  );
}