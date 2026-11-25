"use client";
import { setLang, useLang, useT } from "@/lib/i18n";

export default function LanguageSwitch() {
  const lang = useLang();
  const { t } = useT();
  return (
    <div className="segmented segmented-sm" role="group" aria-label={t("nav.language")}>
      <button type="button" aria-pressed={lang === "en"} onClick={() => setLang("en")} lang="en">
        English
      </button>
      <button type="button" aria-pressed={lang === "hi"} onClick={() => setLang("hi")} lang="hi">
        हिन्दी
      </button>
    </div>
  );
}
