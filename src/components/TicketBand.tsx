export default function TicketBand({ type, id }: { type: string; id?: string }) {
  const lost = type === "lost";
  return (
    <div className={`ticket-band ${lost ? "ticket-band-lost" : "ticket-band-found"}`}>
      <span className="ticket-hole" aria-hidden="true" />
      <span>{lost ? "Lost" : "Found"}</span>
      {id && <span className="ticket-ref">No. {id.slice(0, 4).toUpperCase()}</span>}
    </div>
  );
}
