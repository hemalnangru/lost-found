"use client";
import { useT } from "@/lib/i18n";

export default function Footer() {
  const { t } = useT();
  return (
    <footer className="mt-auto border-t border-line py-6 text-sm text-ink-soft">
      <div className="max-w-6xl mx-auto px-5">{t("footer.text")}</div>
    </footer>
  );
}
