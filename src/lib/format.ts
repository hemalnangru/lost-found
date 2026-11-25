import type { Lang } from "@/lib/dictionary";

const locale = (lang: Lang) => (lang === "hi" ? "hi-IN" : "en-IN");

export function formatDate(iso: string, lang: Lang = "en") {
  const d = new Date(`${iso}T00:00:00`);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString(locale(lang), {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

export function formatTime(iso: string, lang: Lang = "en") {
  return new Date(iso).toLocaleTimeString(locale(lang), { hour: "numeric", minute: "2-digit" });
}
