import { useCallback, useSyncExternalStore } from "react";
import { dictionaries, type Key, type Lang } from "@/lib/dictionary";

type Vars = Record<string, string | number>;
export type T = (key: Key, vars?: Vars) => string;

// The chosen language lives in localStorage. useSyncExternalStore keeps every
// component in step and shows English on the server, so the page never mismatches.
const listeners = new Set<() => void>();

function subscribe(cb: () => void) {
  listeners.add(cb);
  window.addEventListener("storage", cb);
  return () => {
    listeners.delete(cb);
    window.removeEventListener("storage", cb);
  };
}

function getSnapshot(): Lang {
  try {
    return localStorage.getItem("lang") === "hi" ? "hi" : "en";
  } catch {
    return "en";
  }
}

const getServerSnapshot = (): Lang => "en";

export function setLang(lang: Lang) {
  try {
    localStorage.setItem("lang", lang);
  } catch {
    // storage can be blocked; the switch still works until the page reloads
  }
  document.documentElement.lang = lang;
  listeners.forEach((f) => f());
}

export function useLang(): Lang {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}

function fill(text: string, vars?: Vars) {
  if (!vars) return text;
  return text.replace(/\{(\w+)\}/g, (_, k: string) => String(vars[k] ?? `{${k}}`));
}

export function useT() {
  const lang = useLang();
  const t: T = useCallback(
    (key, vars) => fill(dictionaries[lang][key] ?? dictionaries.en[key] ?? key, vars),
    [lang]
  );
  // for values that come from the database (status, category) with a safe fallback
  const td = useCallback(
    (key: string, fallback: string) => (dictionaries[lang] as Record<string, string>)[key] ?? fallback,
    [lang]
  );
  return { t, td, lang };
}

// The server sends match reasons in English. This turns them into the chosen language.
export function reasonText(r: string, t: T): string {
  const exact: Record<string, Key> = {
    "very similar description": "reason.verySimilar",
    "similar description": "reason.similar",
    "same city": "reason.sameCity",
    "same colour": "reason.sameColour",
    "same day": "reason.sameDay",
  };
  if (exact[r]) return t(exact[r]);
  let m = r.match(/^(\d+) days? apart$/);
  if (m) return t(m[1] === "1" ? "reason.dayApart" : "reason.daysApart", { n: m[1] });
  m = r.match(/^(\d+) m away$/);
  if (m) return t("reason.mAway", { n: m[1] });
  m = r.match(/^([\d.]+) km away$/);
  if (m) return t("reason.kmAway", { n: m[1] });
  return r;
}
