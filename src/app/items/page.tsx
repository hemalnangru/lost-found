"use client";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

type Item = {
  id: string;
  type: string;
  title: string;
  description: string | null;
  category: string;
  city: string | null;
  event_date: string;
  status: string;
};

export default function ItemsPage() {
  const [items, setItems] = useState<Item[]>([]);
  const [type, setType] = useState("all");
  const [category, setCategory] = useState("all");
  const [city, setCity] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      setLoading(true);
      let q = supabase
        .from("items")
        .select("id,type,title,description,category,city,event_date,status")
        .order("created_at", { ascending: false })
        .limit(50);
      if (type !== "all") q = q.eq("type", type);
      if (category !== "all") q = q.eq("category", category);
      if (city.trim()) q = q.ilike("city", `%${city.trim()}%`);
      const { data } = await q;
      setItems((data as Item[]) ?? []);
      setLoading(false);
    }
    load();
  }, [type, category, city]);

  const input = "border rounded p-2";

  return (
    <main className="max-w-3xl mx-auto p-6">
      <h1 className="text-2xl font-bold mb-4">Lost and found items</h1>

      <div className="flex flex-wrap gap-2 mb-4">
        <select className={input} value={type} onChange={(e) => setType(e.target.value)}>
          <option value="all">Lost + Found</option>
          <option value="lost">Lost</option>
          <option value="found">Found</option>
        </select>
        <select className={input} value={category} onChange={(e) => setCategory(e.target.value)}>
          <option value="all">All categories</option>
          {["phone", "wallet", "bag", "keys", "documents", "laptop", "other"].map((c) => (
            <option key={c}>{c}</option>
          ))}
        </select>
        <input className={input} placeholder="Search city" value={city}
          onChange={(e) => setCity(e.target.value)} />
      </div>

      {loading && <p>Loading...</p>}
      {!loading && items.length === 0 && <p>No items found.</p>}

      <div className="space-y-2">
        {items.map((it) => (
          <div key={it.id} className="border rounded p-3">
            <div className="flex justify-between">
              <p className="font-medium">{it.title}</p>
              <span className={`text-xs px-2 py-1 rounded ${
                it.type === "lost" ? "bg-red-100 text-red-700" : "bg-green-100 text-green-700"
              }`}>
                {it.type}
              </span>
            </div>
            {it.description && <p className="text-sm text-gray-600">{it.description}</p>}
            <p className="text-xs text-gray-500 mt-1">
              {it.category} | {it.city ?? "Unknown city"} | {it.event_date} | {it.status}
            </p>
          </div>
        ))}
      </div>
    </main>
  );
}