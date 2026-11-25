"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { useT } from "@/lib/i18n";
import LanguageSwitch from "@/components/LanguageSwitch";

export default function Navbar() {
  const pathname = usePathname();
  const { t, lang } = useT();
  const [email, setEmail] = useState<string | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);

  useEffect(() => {
    function checkAdmin(loggedIn: boolean) {
      if (!loggedIn) return setIsAdmin(false);
      supabase.rpc("is_admin").then(({ data }) => setIsAdmin(data === true));
    }
    supabase.auth.getSession().then(({ data }) => {
      setEmail(data.session?.user.email ?? null);
      checkAdmin(!!data.session);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, session) => {
      setEmail(session?.user.email ?? null);
      checkAdmin(!!session);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const links = [
    { href: "/report", label: t("nav.report") },
    { href: "/items", label: t("nav.browse") },
    ...(email
      ? [
          { href: "/my-reports", label: t("nav.myReports") },
          { href: "/messages", label: t("nav.messages") },
        ]
      : []),
    ...(isAdmin ? [{ href: "/admin", label: t("nav.admin") }] : []),
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
          {t("brand")}
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
          <LanguageSwitch />
          {email ? (
            <>
              <span className="hidden lg:inline text-ink-soft">{email}</span>
              <button className="btn btn-small" onClick={() => supabase.auth.signOut()}>
                {t("nav.logout")}
              </button>
            </>
          ) : (
            <Link href="/login" className="btn btn-small btn-primary">
              {t("nav.login")}
            </Link>
          )}
        </div>
      </nav>
    </header>
  );
}
