"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";

export default function Navbar() {
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

  return (
    <nav className="flex flex-wrap items-center gap-4 px-6 py-3 border-b text-sm">
      <Link href="/" className="font-semibold">Pan-India Lost &amp; Found</Link>
      <Link href="/report" className="text-gray-500 hover:underline">Report</Link>
      <Link href="/items" className="text-gray-500 hover:underline">Browse</Link>
      {email && <Link href="/my-reports" className="text-gray-500 hover:underline">My reports</Link>}
      <div className="ml-auto flex items-center gap-3">
        {email ? (
          <>
            <span className="text-xs text-gray-500">{email}</span>
            <button className="text-blue-600 underline"
              onClick={() => supabase.auth.signOut()}>
              Log out
            </button>
          </>
        ) : (
          <Link href="/login" className="text-blue-600 underline">Log in</Link>
        )}
      </div>
    </nav>
  );
}