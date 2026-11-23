import { createClient } from "@supabase/supabase-js";
import { sendMail } from "@/lib/mailer";

// Only strong matches trigger an email, and at most a few per new report
export const ALERT_MIN_SCORE = 0.6;
const MAX_ALERTS = 3;

type MatchLike = { id: string; title: string; score: number; reasons: string[] };
type NewItem = {
  id: string;
  type: string;
  title: string;
  city: string | null;
  event_date: string;
};

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

// Emails the owners of existing reports that strongly match a new report.
// Needs SUPABASE_SERVICE_ROLE_KEY on the server to look up their email addresses.
export async function notifyMatches({
  item,
  matches,
  submitterId,
  origin,
}: {
  item: NewItem;
  matches: MatchLike[];
  submitterId: string;
  origin: string;
}) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    console.warn("[alerts] SUPABASE_SERVICE_ROLE_KEY is not set. Skipping email alerts.");
    return;
  }

  const strong = matches.filter((m) => m.score >= ALERT_MIN_SCORE).slice(0, MAX_ALERTS);
  if (strong.length === 0) return;

  const admin = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: rows } = await admin
    .from("items")
    .select("id,user_id")
    .in("id", strong.map((m) => m.id));
  const owners = new Map<string, string | null>(
    (rows ?? []).map((r: { id: string; user_id: string | null }) => [r.id, r.user_id])
  );

  const link = `${origin}/items/${item.id}`;
  const whereWhen = `${item.city ?? "an unknown city"} on ${item.event_date}`;
  const notified = new Set<string>();

  for (const m of strong) {
    const uid = owners.get(m.id);
    if (!uid || uid === submitterId || notified.has(uid)) continue;

    try {
      const { data: u } = await admin.auth.admin.getUserById(uid);
      const to = u.user?.email;
      if (!to) continue;
      notified.add(uid);

      const pct = Math.round(m.score * 100);
      const found = item.type === "found";
      const subject = found
        ? `Good news: a report may match your lost "${m.title}"`
        : `Someone is looking for something like your found "${m.title}"`;
      const intro = found
        ? `Someone reported finding "${item.title}" (${whereWhen}). It may be your lost "${m.title}".`
        : `Someone reported losing "${item.title}" (${whereWhen}). It may match the "${m.title}" you found.`;
      const why = m.reasons.length > 0 ? `Why it matched: ${m.reasons.join(", ")}.` : "";

      const text = [
        intro,
        `Match score: ${pct}%.`,
        why,
        `See the report: ${link}`,
        "",
        "You got this email because you reported an item on Pan-India Lost & Found.",
      ]
        .filter(Boolean)
        .join("\n");

      const html = `
        <div style="font-family:Arial,sans-serif;max-width:480px;color:#0e1a3a">
          <p style="font-size:16px">${esc(intro)}</p>
          <p style="font-size:28px;font-weight:bold;margin:12px 0">${pct}% match</p>
          ${why ? `<p>${esc(why)}</p>` : ""}
          <p><a href="${link}" style="display:inline-block;background:#1e40d8;color:#fff;padding:10px 18px;border-radius:8px;text-decoration:none;font-weight:bold">View the report</a></p>
          <p style="font-size:12px;color:#4a5675">You got this email because you reported an item on Pan-India Lost &amp; Found.</p>
        </div>`;

      await sendMail({ to, subject, text, html });
    } catch (e) {
      console.error("[alerts] could not email one owner:", e);
    }
  }
}
