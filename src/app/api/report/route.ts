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
