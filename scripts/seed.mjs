import { createClient } from "@supabase/supabase-js";
import { pipeline } from "@huggingface/transformers";

const { NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SEED_EMAIL, SEED_PASSWORD } =
  process.env;

if (!SEED_EMAIL || !SEED_PASSWORD) {
  console.error("Set SEED_EMAIL and SEED_PASSWORD (an account you already created in the app).");
  process.exit(1);
}

const supabase = createClient(NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY);

// Dates relative to today, so the demo always looks recent
const daysAgo = (n) => new Date(Date.now() - n * 86400000).toISOString().slice(0, 10);

// Each pair: the same item described in two different ways
// [category, city, lat, lng, lost{title,desc,color}, found{title,desc,color}, question, answer]
const pairs = [
  ["phone", "Delhi", 28.6139, 77.209,
    { t: "Black Samsung phone", d: "cracked screen, dog wallpaper", c: "black" },
    { t: "Dark mobile phone", d: "broken display, puppy lock screen", c: "black" }, "What is the wallpaper?", "dog"],
  ["phone", "Mumbai", 19.076, 72.8777,
    { t: "iPhone 15 with blue case", d: "silver phone, transparent blue cover, small dent on corner", c: "silver" },
    { t: "Apple phone found at station", d: "light grey iPhone in a blue back cover", c: "silver" }, "What colour is the case?", "blue"],
  ["phone", "Hyderabad", 17.385, 78.4867,
    { t: "OnePlus Nord", d: "green back panel, tempered glass cracked at top", c: "green" },
    { t: "Green smartphone", d: "OnePlus brand, glass guard broken near the top", c: "green" }, "Which brand is it?", "oneplus"],
  ["phone", "Jalandhar", 31.326, 75.5762,
    { t: "Redmi Note 12", d: "black phone with a cricket sticker on the back", c: "black" },
    { t: "Xiaomi mobile", d: "dark coloured, cricket bat sticker behind", c: "black" }, "What sticker is on the back?", "cricket"],
  ["wallet", "Delhi", 28.6304, 77.2177,
    { t: "Brown leather wallet", d: "contains driving licence and two debit cards", c: "brown" },
    { t: "Gents purse", d: "tan leather, DL and bank cards inside", c: "brown" }, "Which card is inside besides bank cards?", "driving licence"],
  ["wallet", "Bengaluru", 12.9716, 77.5946,
    { t: "Black wallet", d: "zip pocket, metro card and 500 rupee notes", c: "black" },
    { t: "Black money pouch", d: "has zipper, metro smart card and some cash", c: "black" }, "Which card is inside?", "metro"],
  ["wallet", "Chennai", 13.0827, 80.2707,
    { t: "Red ladies wallet", d: "small clutch with gold clasp", c: "red" },
    { t: "Maroon women purse", d: "short clutch style, golden lock", c: "red" }, "What colour is the clasp?", "gold"],
  ["bag", "Pune", 18.5204, 73.8567,
    { t: "Blue backpack", d: "college bag with laptop sleeve and a keychain of a panda", c: "blue" },
    { t: "Navy rucksack", d: "student bag, panda toy hanging from the zip", c: "blue" }, "What animal keychain is on it?", "panda"],
  ["bag", "Kolkata", 22.5726, 88.3639,
    { t: "Black Wildcraft bag", d: "sports duffle bag with gym clothes inside", c: "black" },
    { t: "Gym duffel", d: "black sports bag, shorts and towel inside", c: "black" }, "What is inside the bag?", "gym clothes"],
  ["bag", "Jaipur", 26.9124, 75.7873,
    { t: "Green tote bag", d: "cloth shopping bag with printed elephant", c: "green" },
    { t: "Canvas carry bag", d: "light green cloth, elephant picture on it", c: "green" }, "What is printed on it?", "elephant"],
  ["keys", "Delhi", 28.5355, 77.391,
    { t: "Car keys with Honda logo", d: "black remote key and a red tag", c: "black" },
    { t: "Honda car key", d: "remote fob with a red tag attached", c: "black" }, "What colour is the tag?", "red"],
  ["keys", "Mumbai", 19.1197, 72.8464,
    { t: "House keys bunch", d: "three keys on a ring with a bottle opener", c: "silver" },
    { t: "Key ring found near bus stop", d: "3 keys, small bottle opener attached", c: "silver" }, "What tool is on the ring?", "bottle opener"],
  ["keys", "Chandigarh", 30.7333, 76.7794,
    { t: "Bike key", d: "Royal Enfield key with a leather strap", c: "brown" },
    { t: "Motorcycle key", d: "Enfield logo, brown leather keychain", c: "brown" }, "Which bike brand?", "royal enfield"],
  ["documents", "Lucknow", 26.8467, 80.9462,
    { t: "College ID card", d: "Lovely Professional University student card in a blue lanyard", c: "blue" },
    { t: "Student identity card", d: "LPU card with blue neck strap", c: "blue" }, "Which university is on the card?", "lpu"],
  ["documents", "Ahmedabad", 23.0225, 72.5714,
    { t: "Blue file folder", d: "marksheets and certificates in a plastic folder", c: "blue" },
    { t: "Certificate folder", d: "plastic blue file with mark sheets inside", c: "blue" }, "What papers are inside?", "marksheets"],
  ["documents", "Jalandhar", 31.3256, 75.5792,
    { t: "Passport in black cover", d: "Indian passport with boarding pass inside", c: "black" },
    { t: "Travel document", d: "passport in dark cover, flight boarding pass tucked in", c: "black" }, "What is tucked inside?", "boarding pass"],
  ["laptop", "Bengaluru", 12.9352, 77.6245,
    { t: "HP laptop in grey sleeve", d: "15 inch, sticker of Python logo on lid", c: "grey" },
    { t: "Grey notebook computer", d: "HP brand, snake logo sticker on the cover, in a sleeve", c: "grey" }, "Which logo sticker?", "python"],
  ["laptop", "Delhi", 28.7041, 77.1025,
    { t: "MacBook Air", d: "silver, small scratch near trackpad, charger in bag", c: "silver" },
    { t: "Apple laptop found in cafe", d: "silver MacBook with a scratch below keyboard", c: "silver" }, "Where is the scratch?", "trackpad"],
  ["other", "Chennai", 13.0674, 80.2376,
    { t: "Prescription glasses", d: "black round frame in a brown case", c: "black" },
    { t: "Spectacles with case", d: "round dark frame, tan hard case", c: "black" }, "What shape is the frame?", "round"],
  ["other", "Hyderabad", 17.4399, 78.4983,
    { t: "Water bottle", d: "steel flask with name Rohan engraved", c: "silver" },
    { t: "Steel thermos", d: "silver bottle, the name Rohan is carved on it", c: "silver" }, "What name is engraved?", "rohan"],
];

// Extra found items that should NOT match anything (distractors)
const distractors = [
  ["phone", "Delhi", 28.61, 77.2, "White Vivo phone", "pink flower case, no screen guard", "white"],
  ["wallet", "Mumbai", 19.08, 72.88, "Blue canvas wallet", "velcro closing, empty", "blue"],
  ["bag", "Pune", 18.52, 73.86, "Red school bag", "cartoon print, small size", "red"],
  ["keys", "Jaipur", 26.91, 75.79, "Single door key", "gold colour, no keychain", "gold"],
  ["laptop", "Chennai", 13.08, 80.27, "Dell laptop", "black, 14 inch, no sticker", "black"],
  ["documents", "Kolkata", 22.57, 88.36, "Electricity bill", "paper bill in a white envelope", "white"],
];

const jitter = () => (Math.random() - 0.5) * 0.008; // roughly 400 m

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

console.log("Loading the AI model (first run downloads about 90 MB)...");
const extractor = await pipeline("feature-extraction", "Xenova/all-MiniLM-L6-v2");
const embed = async (title, description, color) => {
  const out = await extractor(`${title}. ${description ?? ""} ${color ?? ""}`, {
    pooling: "mean",
    normalize: true,
  });
  return Array.from(out.data);
};

async function addItem(row, secret) {
  const { data, error } = await supabase.from("items").insert(row).select().single();
  if (error) throw new Error(error.message);
  if (secret) {
    const { error: e2 } = await supabase
      .from("item_secrets")
      .insert({ item_id: data.id, ...secret });
    if (e2) throw new Error(e2.message);
  }
  return data;
}

let count = 0;
for (const [i, p] of pairs.entries()) {
  const [category, city, lat, lng, lost, found, question, answer] = p;
  const lostDay = 9 - (i % 5); // 5 to 9 days ago
  const foundDay = lostDay - 1 - (i % 2); // 1 or 2 days later

  await addItem({
    user_id, type: "lost", title: lost.t, description: lost.d, category, color: lost.c,
    city, lat: lat + jitter(), lng: lng + jitter(), event_date: daysAgo(lostDay),
    text_embedding: await embed(lost.t, lost.d, lost.c),
  });
  await addItem(
    {
      user_id, type: "found", title: found.t, description: found.d, category, color: found.c,
      city, lat: lat + jitter(), lng: lng + jitter(), event_date: daysAgo(foundDay),
      text_embedding: await embed(found.t, found.d, found.c),
    },
    { question, answer, contact: `Demo contact: 90000 000${String(i + 10)}` }
  );
  count += 2;
  console.log(`Pair ${i + 1}/${pairs.length} added`);
}

for (const [i, d] of distractors.entries()) {
  const [category, city, lat, lng, title, description, color] = d;
  await addItem(
    {
      user_id, type: "found", title, description, category, color, city,
      lat: lat + jitter(), lng: lng + jitter(), event_date: daysAgo(2 + (i % 3)),
      text_embedding: await embed(title, description, color),
    },
    { question: "What is special about it?", answer: "nothing", contact: "Demo contact: 90000 00099" }
  );
  count++;
}

console.log(`Done. Added ${count} demo reports.`);
process.exit(0);