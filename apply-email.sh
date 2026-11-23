#!/bin/bash
# Adds email alerts: when a new report strongly matches an existing one,
# the owner of the existing report gets an email.
# Run it from inside the lost-found folder (the one with package.json).
set -e

if [ ! -f package.json ] || [ ! -d src/app ]; then
  echo "Run this inside the lost-found folder (the one that has package.json)."
  exit 1
fi

BACKUP="backup-before-email"
mkdir -p "$BACKUP"
if ! grep -qx "$BACKUP/" .gitignore 2>/dev/null; then
  printf "\n%s/\n" "$BACKUP" >> .gitignore
fi

write() {
  local f="$1"
  mkdir -p "$(dirname "$f")"
  if [ -f "$f" ]; then
    mkdir -p "$BACKUP/$(dirname "$f")"
    cp "$f" "$BACKUP/$f"
  fi
  cat > "$f"
  echo "wrote $f"
}

write "scripts/test-email.mjs" <<'__LF_EOF__'
import nodemailer from "nodemailer";

const user = process.env.GMAIL_USER;
const pass = process.env.GMAIL_APP_PASSWORD?.replace(/\s/g, "");

if (!user || !pass) {
  console.error("Set GMAIL_USER and GMAIL_APP_PASSWORD in .env.local first.");
  process.exit(1);
}

const transporter = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 465,
  secure: true,
  auth: { user, pass },
});

try {
  await transporter.sendMail({
    from: `Pan-India Lost & Found <${user}>`,
    to: user,
    subject: "Test email from Pan-India Lost & Found",
    text: "If you can read this, email alerts are set up correctly.",
  });
  console.log(`Sent. Check the inbox of ${user} (and the spam folder).`);
} catch (e) {
  console.error("Failed:", e.message);
  if (/self.signed|certificate/i.test(e.message)) {
    console.error("Your network is intercepting secure connections. Try your phone hotspot.");
  }
  if (/Invalid login|Username and Password|535/i.test(e.message)) {
    console.error("Use a Gmail app password (16 letters), not your normal password.");
  }
  process.exit(1);
}
__LF_EOF__

write "src/app/api/report/route.ts" <<'__LF_EOF__'
import { NextResponse, after } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { pipeline } from "@huggingface/transformers";
import { notifyMatches } from "@/lib/alerts";

type Extractor = (
  text: string,
  opts: { pooling: string; normalize: boolean }
) => Promise<{ data: Float32Array }>;

let extractor: Extractor | null = null;

async function embed(text: string): Promise<number[]> {
  if (!extractor) {
    extractor = (await pipeline(
      "feature-extraction",
      "Xenova/all-MiniLM-L6-v2"
    )) as unknown as Extractor;
  }
  const out = await extractor(text, { pooling: "mean", normalize: true });
  return Array.from(out.data);
}

type Candidate = {
  id: string;
  title: string;
  description: string | null;
  color: string | null;
  city: string | null;
  lat: number | null;
  lng: number | null;
  event_date: string;
  image_url: string | null;
  similarity: number;
};

// Distance between two map points in km (haversine formula)
function distanceKm(lat1: number, lng1: number, lat2: number, lng2: number) {
  const R = 6371;
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

function formatDistance(km: number) {
  return km < 1 ? `${Math.round(km * 1000)} m away` : `${km.toFixed(1)} km away`;
}

// Final score = 60% text meaning + 20% location + 20% date closeness
function scoreMatch(
  c: Candidate,
  mine: {
    city?: string;
    color?: string;
    lat?: number | null;
    lng?: number | null;
    event_date: string;
  }
) {
  const reasons: string[] = [];

  const text = Math.max(0, Math.min(1, c.similarity));
  if (text >= 0.6) reasons.push("very similar description");
  else if (text >= 0.4) reasons.push("similar description");

  // Location: real distance if both have a map pin, otherwise same city
  let locationScore = 0;
  const hasPins =
    typeof mine.lat === "number" &&
    typeof mine.lng === "number" &&
    typeof c.lat === "number" &&
    typeof c.lng === "number";

  if (hasPins) {
    const km = distanceKm(
      mine.lat as number,
      mine.lng as number,
      c.lat as number,
      c.lng as number
    );
    locationScore = Math.max(0, 1 - km / 20); // 0 km = 1, 20 km or more = 0
    if (km <= 20) reasons.push(formatDistance(km));
  } else {
    const sameCity =
      !!mine.city &&
      !!c.city &&
      mine.city.trim().toLowerCase() === c.city.trim().toLowerCase();
    if (sameCity) {
      locationScore = 1;
      reasons.push("same city");
    }
  }

  const gapDays = Math.round(
    Math.abs(
      new Date(c.event_date).getTime() - new Date(mine.event_date).getTime()
    ) / 86400000
  );
  const timeScore = Math.max(0, 1 - gapDays / 30);
  if (gapDays === 0) reasons.push("same day");
  else if (gapDays <= 7)
    reasons.push(`${gapDays} day${gapDays > 1 ? "s" : ""} apart`);

  if (
    mine.color &&
    c.color &&
    mine.color.trim().toLowerCase() === c.color.trim().toLowerCase()
  ) {
    reasons.push("same colour");
  }

  const score = 0.6 * text + 0.2 * locationScore + 0.2 * timeScore;
  return { ...c, score, reasons };
}

export async function POST(req: Request) {
  try {
    const token = req.headers.get("authorization")?.replace("Bearer ", "");
    if (!token) {
      return NextResponse.json({ error: "Please log in first" }, { status: 401 });
    }

    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { global: { headers: { Authorization: `Bearer ${token}` } } }
    );

    const { data: userData, error: userError } = await supabase.auth.getUser(token);
    if (userError || !userData.user) {
      return NextResponse.json(
        { error: "Session expired, please log in again" },
        { status: 401 }
      );
    }
    const user_id = userData.user.id;

    const body = await req.json();
    const {
      type,
      title,
      description,
      category,
      color,
      city,
      lat,
      lng,
      event_date,
      image_url,
    } = body;

    if (!type || !title || !category || !event_date) {
      return NextResponse.json(
        { error: "type, title, category and event_date are required" },
        { status: 400 }
      );
    }

    const embedding = await embed(
      `${title}. ${description ?? ""} ${color ?? ""}`
    );

    const { data: item, error } = await supabase
      .from("items")
      .insert({
        type,
        title,
        description,
        category,
        color,
        city,
        lat,
        lng,
        event_date,
        user_id,
        image_url,
        text_embedding: embedding,
      })
      .select()
      .single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    const { data: candidates, error: matchError } = await supabase.rpc(
      "match_items",
      {
        query_embedding: embedding,
        item_type: type === "lost" ? "found" : "lost",
        item_category: category,
        min_date: type === "lost" ? event_date : "1970-01-01",
        match_count: 10,
      }
    );

    if (matchError) {
      return NextResponse.json({
        item,
        matches: [],
        matchError: matchError.message,
      });
    }

    const matches = ((candidates ?? []) as Candidate[])
      .map((c) => scoreMatch(c, { city, color, lat, lng, event_date }))
      .sort((a, b) => b.score - a.score)
      .slice(0, 5);

    // Email the owners of strongly matching reports. This runs after the response
    // is sent, so a slow or failing email never delays or breaks the report.
    const origin = new URL(req.url).origin;
    after(async () => {
      try {
        await notifyMatches({
          item: { id: item.id, type, title, city, event_date },
          matches,
          submitterId: user_id,
          origin,
        });
      } catch (e) {
        console.error("[alerts]", e);
      }
    });

    return NextResponse.json({ item, matches });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Something went wrong";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
__LF_EOF__

write "src/lib/alerts.ts" <<'__LF_EOF__'
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
__LF_EOF__

write "src/lib/mailer.ts" <<'__LF_EOF__'
import nodemailer from "nodemailer";

type Mail = { to: string; subject: string; text: string; html: string };

// Sends through Gmail with an app password. Returns false when the
// credentials are not configured, so the rest of the app keeps working.
export async function sendMail({ to, subject, text, html }: Mail): Promise<boolean> {
  const user = process.env.GMAIL_USER;
  const pass = process.env.GMAIL_APP_PASSWORD?.replace(/\s/g, "");
  if (!user || !pass) {
    console.warn("[mail] GMAIL_USER or GMAIL_APP_PASSWORD is not set. Skipping email.");
    return false;
  }

  const transporter = nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: { user, pass },
  });

  await transporter.sendMail({
    from: `Pan-India Lost & Found <${user}>`,
    to,
    subject,
    text,
    html,
  });
  return true;
}
__LF_EOF__


echo ""
echo "Done. Next steps:"
echo "  1. npm install nodemailer"
echo "  2. npm install -D @types/nodemailer"
echo "  3. Add GMAIL_USER, GMAIL_APP_PASSWORD and SUPABASE_SERVICE_ROLE_KEY to .env.local"
echo "  4. node --env-file=.env.local scripts/test-email.mjs"
