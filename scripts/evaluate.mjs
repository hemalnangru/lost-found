import { createClient } from "@supabase/supabase-js";

const { NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SEED_EMAIL, SEED_PASSWORD } =
  process.env;

if (!SEED_EMAIL || !SEED_PASSWORD) {
  console.error("Set SEED_EMAIL and SEED_PASSWORD.");
  process.exit(1);
}

const supabase = createClient(NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY);

const { error: signErr } = await supabase.auth.signInWithPassword({
  email: SEED_EMAIL,
  password: SEED_PASSWORD,
});
if (signErr) {
  console.error("Login failed:", signErr.message);
  process.exit(1);
}
const { data: u } = await supabase.auth.getUser();

const { data: items, error } = await supabase
  .from("items")
  .select("id,type,title,category,city,color,lat,lng,event_date,text_embedding,created_at")
  .eq("user_id", u.user.id)
  .order("created_at", { ascending: true });
if (error) {
  console.error(error.message);
  process.exit(1);
}

// The seed script inserts each lost item and then its found twin, so a
// lost item followed directly by a found item is one ground-truth pair.
const pairs = [];
for (let i = 0; i < items.length - 1; i++) {
  if (items[i].type === "lost" && items[i + 1].type === "found") {
    pairs.push({ lost: items[i], found: items[i + 1] });
  }
}
if (pairs.length === 0) {
  console.error("No lost/found pairs found. Run the seed script first.");
  process.exit(1);
}

function distanceKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

// Same formula as the app: 60% text + 20% location + 20% date
function combinedScore(c, mine) {
  const text = Math.max(0, Math.min(1, c.similarity));
  let loc = 0;
  if ([mine.lat, mine.lng, c.lat, c.lng].every((v) => typeof v === "number")) {
    loc = Math.max(0, 1 - distanceKm(mine.lat, mine.lng, c.lat, c.lng) / 20);
  } else if (mine.city && c.city && mine.city.toLowerCase() === c.city.toLowerCase()) {
    loc = 1;
  }
  const gap = Math.abs(new Date(c.event_date) - new Date(mine.event_date)) / 86400000;
  return 0.6 * text + 0.2 * loc + 0.2 * Math.max(0, 1 - gap / 30);
}

const hits = { text: { 1: 0, 3: 0, 5: 0 }, combined: { 1: 0, 3: 0, 5: 0 } };
const misses = [];

for (const { lost, found } of pairs) {
  const embedding =
    typeof lost.text_embedding === "string"
      ? JSON.parse(lost.text_embedding)
      : lost.text_embedding;

  const { data: cands, error: rpcErr } = await supabase.rpc("match_items", {
    query_embedding: embedding,
    item_type: "found",
    item_category: lost.category,
    min_date: lost.event_date,
    match_count: 50,
  });
  if (rpcErr) {
    console.error("match_items failed:", rpcErr.message);
    process.exit(1);
  }

  // a result is correct if it is the twin (or an identical re-seeded copy)
  const isRight = (c) => c.id === found.id || c.title === found.title;

  const textRank = [...cands].sort((a, b) => b.similarity - a.similarity);
  const combRank = [...cands].sort(
    (a, b) => combinedScore(b, lost) - combinedScore(a, lost)
  );

  for (const k of [1, 3, 5]) {
    if (textRank.slice(0, k).some(isRight)) hits.text[k]++;
    if (combRank.slice(0, k).some(isRight)) hits.combined[k]++;
  }
  if (!combRank.slice(0, 5).some(isRight)) {
    misses.push(`${lost.title}  (expected: ${found.title})`);
  }
}

const n = pairs.length;
const pct = (x) => `${((x / n) * 100).toFixed(0)}%`;

console.log(`\nTested ${n} lost items against all open found items in the same category.\n`);
console.log("Method                       Top-1   Top-3   Top-5");
console.log(
  `Text meaning only            ${pct(hits.text[1]).padEnd(7)} ${pct(hits.text[3]).padEnd(7)} ${pct(hits.text[5])}`
);
console.log(
  `Combined (text+place+date)   ${pct(hits.combined[1]).padEnd(7)} ${pct(hits.combined[3]).padEnd(7)} ${pct(hits.combined[5])}`
);
if (misses.length) {
  console.log("\nNot in the top 5:");
  misses.forEach((m) => console.log(" -", m));
}
process.exit(0);