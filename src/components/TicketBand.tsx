"use client";
import { useT } from "@/lib/i18n";

export default function TicketBand({ type, id }: { type: string; id?: string }) {
  const { t } = useT();
  const lost = type === "lost";
  return (
    <div className={`ticket-band ${lost ? "ticket-band-lost" : "ticket-band-found"}`}>
      <span className="ticket-hole" aria-hidden="true" />
      <span>{lost ? t("common.lost") : t("common.found")}</span>
      {id && (
        <span className="ticket-ref">
          {t("ticket.no")} {id.slice(0, 4).toUpperCase()}
        </span>
      )}
    </div>
  );
}
