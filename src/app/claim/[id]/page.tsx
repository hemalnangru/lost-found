"use client";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { useT } from "@/lib/i18n";

export default function ClaimPage() {
  const { t } = useT();
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
    const { data, error } = await supabase.rpc("verify_claim", { p_item: id, p_answer: answer });
    setBusy(false);
    if (error) return setMessage(error.message);
    if (data) setContact(data as string);
    else setMessage(t("claim.wrong"));
  }

  if (loadingQ || loggedIn === null) {
    return <main className="max-w-md mx-auto px-5 py-12">{t("common.loading")}</main>;
  }

  return (
    <main className="max-w-md mx-auto px-5 py-12">
      <div className="ticket">
        <div className="ticket-band ticket-band-ink">
          <span className="ticket-hole" aria-hidden="true" />
          <span>{t("claim.title")}</span>
        </div>

        <div className="p-5">
          {!loggedIn ? (
            <>
              <p className="mb-4 text-ink-soft">{t("claim.loginPrompt")}</p>
              <Link href="/login" className="btn btn-primary">{t("nav.login")}</Link>
            </>
          ) : !question ? (
            <p className="text-ink-soft">{t("claim.noQuestion")}</p>
          ) : contact ? (
            <div className="rounded-xl border-[1.5px] border-found bg-found-tint p-4">
              <p className="font-bold text-found-dark">{t("claim.verified")}</p>
              <p className="mt-1 text-2xl font-display font-extrabold break-words">{contact}</p>
            </div>
          ) : (
            <form onSubmit={verify} className="space-y-4">
              <p className="text-sm text-ink-soft">{t("claim.intro")}</p>
              <p className="font-display font-bold text-xl leading-snug">{question}</p>
              <div>
                <label className="label" htmlFor="answer">{t("claim.yourAnswer")}</label>
                <input id="answer" className="field w-full" required value={answer}
                  onChange={(e) => setAnswer(e.target.value)} />
              </div>
              <button disabled={busy} className="btn btn-primary w-full">
                {busy ? t("claim.checking") : t("claim.verifyBtn")}
              </button>
              {message && (
                <p role="alert" className="rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
                  {message}
                </p>
              )}
            </form>
          )}
        </div>
      </div>
    </main>
  );
}
