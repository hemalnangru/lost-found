"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

export default function LoginPage() {
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

  const input = "w-full border rounded p-2";

  return (
    <main className="max-w-sm mx-auto p-6">
      <h1 className="text-2xl font-bold mb-4">
        {mode === "login" ? "Log in" : "Create account"}
      </h1>
      <form onSubmit={submit} className="space-y-3">
        <input className={input} type="email" placeholder="Email" required
          value={email} onChange={(e) => setEmail(e.target.value)} />
        <input className={input} type="password" placeholder="Password (min 6 characters)"
          required minLength={6} value={password}
          onChange={(e) => setPassword(e.target.value)} />
        <button disabled={loading} className="w-full bg-blue-600 text-white rounded px-4 py-2">
          {loading ? "Please wait..." : mode === "login" ? "Log in" : "Sign up"}
        </button>
      </form>
      {error && <p className="text-red-600 mt-3 text-sm">{error}</p>}
      <button
        className="text-sm text-blue-600 mt-4 underline"
        onClick={() => setMode(mode === "login" ? "signup" : "login")}
      >
        {mode === "login" ? "New here? Create an account" : "Already have an account? Log in"}
      </button>
    </main>
  );
}