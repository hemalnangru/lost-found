"use client";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { supabase } from "@/lib/supabase";

export default function ClaimPage() {
  const { id } = useParams<{ id: string }>();
  const [loggedIn, setLoggedIn] = useState<boolean | null>(null);
  const [question, setQuestion] = useState<string | null>(null);
  const [loadingQ, setLoadingQ] = useState(true);
  const [answer, setAnswer] = useState("");
  const [contact, setContact] = useState<string | null>(null);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setLoggedIn(!!data.session));
    supabase.rpc("get_claim_question", { p_item: id }).then(({ data }) => {
      setQuestion((data as string | null) ?? null);
      setLoadingQ(false);
    });
  }, [id]);

  async function verify(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setMessage("");
    const { data, error } = await supabase.rpc("verify_claim", {
      p_item: id,
      p_answer: answer,
    });
    setBusy(false);
    if (error) return setMessage(error.message);
    if (data) setContact(data as string);
    else setMessage("That answer is not correct. Please try again.");
  }

  const input = "w-full border rounded p-2";

  if (loadingQ || loggedIn === null) return <main className="p-6">Loading...</main>;

  if (!loggedIn) {
    return (
      <main className="max-w-md mx-auto p-6">
        <h1 className="text-2xl font-bold mb-2">Claim this item</h1>
        <p className="mb-4">Please log in to claim an item.</p>
        <Link href="/login" className="bg-blue-600 text-white rounded px-4 py-2">Log in</Link>
      </main>
    );
  }

  if (!question) {
    return (
      <main className="max-w-md mx-auto p-6">
        <h1 className="text-2xl font-bold mb-2">Claim this item</h1>
        <p>This item has no verification question, so it cannot be claimed here.</p>
      </main>
    );
  }

  return (
    <main className="max-w-md mx-auto p-6">
      <h1 className="text-2xl font-bold mb-2">Claim this item</h1>

      {contact ? (
        <div className="border border-green-600 rounded p-4">
          <p className="font-medium text-green-600 mb-1">Verified! Contact the finder:</p>
          <p className="text-lg">{contact}</p>
        </div>
      ) : (
        <form onSubmit={verify} className="space-y-3">
          <p className="text-sm text-gray-500">
            Only the real owner knows this. Answer correctly to see the finder&apos;s contact.
          </p>
          <p className="font-medium">{question}</p>
          <input className={input} required placeholder="Your answer"
            value={answer} onChange={(e) => setAnswer(e.target.value)} />
          <button disabled={busy} className="bg-blue-600 text-white rounded px-4 py-2">
            {busy ? "Checking..." : "Verify"}
          </button>
          {message && <p className="text-red-600 text-sm">{message}</p>}
        </form>
      )}
    </main>
  );
}