import { createClient } from "@supabase/supabase-js";
import { pipeline } from "@huggingface/transformers";

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
const user_id = u.user.id;

// Look-alike found items per category. They share words and colours with the
// real targets, so text alone can be fooled.
const lookalikes = {
  phone: [
    ["Black Samsung Galaxy phone", "scratches on the back, no case"],
    ["Dark smartphone", "small crack in corner, black cover"],
    ["Black mobile phone", "screen guard peeling, cartoon wallpaper"],
    ["Samsung mobile", "black, cracked back glass, blue case"],
    ["Black Xiaomi phone", "landscape wallpaper, cracked screen"],
  ],
  wallet: [
    ["Brown leather wallet", "a few cash notes and a library card"],
    ["Black leather wallet", "debit card and metro card inside"],
    ["Tan gents wallet", "ID card and some coins"],
    ["Brown purse", "zipper pocket, bank cards inside"],
  ],
  bag: [
    ["Blue backpack", "school bag with water bottle holder"],
    ["Black sports bag", "gym towel inside"],
    ["Navy laptop bag", "college books inside, keychain attached"],
    ["Green cloth bag", "shopping bag with a print"],
  ],
  keys: [
    ["Car key with black fob", "silver ring, no tag"],
    ["Bunch of keys", "four keys on a ring with a small torch"],
    ["Bike key", "black rubber head, metal ring"],
    ["House key set", "two keys with a green tag"],
  ],
  documents: [
    ["ID card with lanyard", "college identity card, red strap"],
    ["Plastic file folder", "certificates and photographs inside"],
    ["Passport cover", "black travel pouch with tickets"],
    ["Student card", "blue neck strap, no university name visible"],
  ],
  laptop: [
    ["Grey laptop in sleeve", "14 inch, sticker on lid"],
    ["Silver laptop", "scratch on the lid, charger inside bag"],
    ["HP notebook", "black, 15 inch, no stickers"],
    ["Apple MacBook", "space grey, small dent on corner"],
  ],
  other: [
    ["Spectacles", "square black frame in blue case"],
    ["Steel water bottle", "dented, no engraving"],
    ["Black frame glasses", "round lenses, no case"],
    ["Silver flask", "name sticker on the side"],
  ],
};

const farCities = [
  ["Nagpur", 21.1458, 79.0882],
  ["Indore", 22.7196, 75.8577],
  ["Patna", 25.5941, 85.1376],
  ["Surat", 21.1702, 72.8311],
];

const { data: losts, error } = await supabase
  .from("items")
  .select("title,category,color,city,lat,lng,event_date")
  .eq("user_id", user_id)
  .eq("type", "lost");
if (error) {
  console.error(error.message);
  process.exit(1);
}

console.log("Loading the AI model...");
const extractor = await pipeline("feature-extraction", "Xenova/all-MiniLM-L6-v2");
const embed = async (t, d, c) => {
  const out = await extractor(`${t}. ${d ?? ""} ${c ?? ""}`, { pooling: "mean", normalize: true });
  return Array.from(out.data);
};

const today = new Date().toISOString().slice(0, 10);
const plusDays = (iso, n) => {
  const d = new Date(new Date(iso).getTime() + n * 86400000).toISOString().slice(0, 10);
  return d > today ? today : d;
};
const near = () => (Math.random() - 0.5) * 0.02; // about 1 km

let count = 0;
for (const [i, lost] of losts.entries()) {
  const pool = lookalikes[lost.category] ?? lookalikes.other;
  // 3 look-alikes per lost item: two in the same city (hard for location),
  // one in a faraway city (location should help)
  for (let k = 0; k < 3; k++) {
    const [title, description] = pool[(i + k) % pool.length];
    const far = k === 2;
    let city = lost.city;
    let lat = lost.lat != null ? lost.lat + near() : null;
    let lng = lost.lng != null ? lost.lng + near() : null;
    if (far) {
      let [c, la, ln] = farCities[i % farCities.length];
      if (c === lost.city) [c, la, ln] = farCities[(i + 1) % farCities.length];
      city = c; lat = la; lng = ln;
    }
    const { data: row, error: e1 } = await supabase
      .from("items")
      .insert({
        user_id, type: "found", title, description, category: lost.category,
        color: lost.color, city, lat, lng,
        event_date: plusDays(lost.event_date, 1 + k),
        text_embedding: await embed(title, description, lost.color),
      })
      .select()
      .single();
    if (e1) { console.error(e1.message); process.exit(1); }
    const { error: e2 } = await supabase.from("item_secrets").insert({
      item_id: row.id,
      question: "What is special about it?",
      answer: "nothing",
      contact: "Demo contact: hard-set",
    });
    if (e2) { console.error(e2.message); process.exit(1); }
    count++;
  }
  console.log(`Lost item ${i + 1}/${losts.length} done`);
}
console.log(`Done. Added ${count} look-alike found items.`);
process.exit(0);