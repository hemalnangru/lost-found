"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";

export default function Navbar() {
  const pathname = usePathname();
  const [email, setEmail] = useState<string | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setEmail(data.session?.user.email ?? null);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, session) => {
      setEmail(session?.user.email ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const links = [
    { href: "/report", label: "Report" },
    { href: "/items", label: "Browse" },
    ...(email ? [{ href: "/my-reports", label: "My reports" }] : []),
  ];

  return (
    <header className="sticky top-0 z-30 bg-card border-b-[1.5px] border-ink">
      <nav className="max-w-6xl mx-auto px-5 py-3 flex flex-wrap items-center gap-x-6 gap-y-2">
        <Link href="/" className="flex items-center gap-2 font-display font-extrabold text-lg">
          <svg width="26" height="26" viewBox="0 0 24 24" aria-hidden="true">
            <path
              d="M21 7a3 3 0 0 0-3-3h-7l-8 8 8 8h7a3 3 0 0 0 3-3z"
              fill="#ffc20e"
              stroke="#0e1a3a"
              strokeWidth="1.8"
              strokeLinejoin="round"
            />
            <circle cx="9" cy="12" r="1.8" fill="#fff" stroke="#0e1a3a" strokeWidth="1.5" />
          </svg>
          Pan-India Lost &amp; Found
        </Link>

        <div className="flex items-center gap-5 text-[0.95rem] font-semibold">
          {links.map((l) => {
            const active = pathname.startsWith(l.href);
            return (
              <Link
                key={l.href}
                href={l.href}
                className={`py-1 border-b-[3px] ${
                  active ? "border-signal" : "border-transparent hover:border-line-strong"
                }`}
              >
                {l.label}
              </Link>
            );
          })}
        </div>

        <div className="ml-auto flex items-center gap-3 text-sm">
          {email ? (
            <>
              <span className="hidden sm:inline text-ink-soft">{email}</span>
              <button className="btn btn-small" onClick={() => supabase.auth.signOut()}>
                Log out
              </button>
            </>
          ) : (
            <Link href="/login" className="btn btn-small btn-primary">
              Log in
            </Link>
          )}
        </div>
      </nav>
    </header>
  );
}
