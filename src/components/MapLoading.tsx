"use client";
import { useT } from "@/lib/i18n";

export default function MapLoading() {
  const { t } = useT();
  return <p className="p-4 text-sm text-ink-soft">{t("common.loadingMap")}</p>;
}
