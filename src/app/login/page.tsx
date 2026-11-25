"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { useT } from "@/lib/i18n";

export default function LoginPage() {
  const { t } = useT();
  const router = useRouter();
  const [mode, setMode] = useState<"login" | "signup">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    const { error } =
      mode === "login"
        ? await supabase.auth.signInWithPassword({ email, password })
        : await supabase.auth.signUp({ email, password });
    setLoading(false);
    if (error) return setError(error.message);
    router.push("/report");
  }

  const title = mode === "login" ? t("login.logIn") : t("login.create");

  return (
    <main className="max-w-md mx-auto px-5 py-12">
      <div className="ticket">
        <div className="ticket-band ticket-band-ink">
          <span className="ticket-hole" aria-hidden="true" />
          <span>{title}</span>
        </div>
        <form onSubmit={submit} className="p-5 space-y-4">
          <div>
            <label className="label" htmlFor="email">{t("login.email")}</label>
            <input id="email" className="field w-full" type="email" placeholder="name@example.com"
              required value={email} onChange={(e) => setEmail(e.target.value)} />
          </div>
          <div>
            <label className="label" htmlFor="password">{t("login.password")}</label>
            <input id="password" className="field w-full" type="password"
              placeholder={t("login.passPh")} required minLength={6} value={password}
              onChange={(e) => setPassword(e.target.value)} />
          </div>
          <button disabled={loading} className="btn btn-primary w-full">
            {loading ? t("login.wait") : title}
          </button>
          {error && (
            <p role="alert" className="rounded-lg border border-lost bg-lost-tint px-3 py-2 text-sm text-lost-dark">
              {error}
            </p>
          )}
        </form>
        <div className="ticket-perf mx-5" />
        <div className="p-5 text-sm">
          {mode === "login" ? t("login.newHere") : t("login.already")}
          <button type="button" className="font-semibold text-rail-dark underline"
            onClick={() => setMode(mode === "login" ? "signup" : "login")}>
            {mode === "login" ? t("login.createLink") : t("login.logIn")}
          </button>
        </div>
      </div>
    </main>
  );
}
