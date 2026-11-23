// Small SVG and CSS charts with no extra libraries.

const LOST = "#c23b20";
const FOUND = "#14815a";
const INK = "#0e1a3a";
const SOFT = "#4a5675";
const GRID = "#d7deec";

export type DayPoint = { day: string; lost: number; found: number };

const dayLabel = (iso: string) =>
  new Date(`${iso}T00:00:00`).toLocaleDateString("en-IN", { day: "numeric", month: "short" });

export function LineChart({ data }: { data: DayPoint[] }) {
  const W = 640;
  const H = 240;
  const L = 34;
  const R = 12;
  const T = 12;
  const B = 28;

  const max = Math.max(1, ...data.flatMap((d) => [d.lost, d.found]));
  const top = Math.max(4, Math.ceil(max / 4) * 4);
  const x = (i: number) => L + (data.length <= 1 ? 0 : (i * (W - L - R)) / (data.length - 1));
  const y = (v: number) => T + (H - T - B) * (1 - v / top);
  const path = (key: "lost" | "found") =>
    data.map((d, i) => `${i === 0 ? "M" : "L"}${x(i).toFixed(1)} ${y(d[key]).toFixed(1)}`).join(" ");
  const ticks = [0, 1, 2, 3, 4].map((k) => (top * k) / 4);

  return (
    <div>
      <svg
        viewBox={`0 0 ${W} ${H}`}
        width="100%"
        role="img"
        aria-label="Items lost and found per day over the last 30 days"
      >
        {ticks.map((t) => (
          <g key={t}>
            <line x1={L} x2={W - R} y1={y(t)} y2={y(t)} stroke={GRID} strokeWidth="1" />
            <text x={L - 6} y={y(t) + 4} fontSize="11" textAnchor="end" fill={SOFT}>
              {t}
            </text>
          </g>
        ))}
        {data.map((d, i) =>
          i % 5 === 0 || i === data.length - 1 ? (
            <text key={d.day} x={x(i)} y={H - 8} fontSize="11" textAnchor="middle" fill={SOFT}>
              {dayLabel(d.day)}
            </text>
          ) : null
        )}
        <path d={path("lost")} fill="none" stroke={LOST} strokeWidth="2.5" strokeLinejoin="round" />
        <path d={path("found")} fill="none" stroke={FOUND} strokeWidth="2.5" strokeLinejoin="round" />
        {data.map((d, i) => (
          <g key={d.day}>
            {d.lost > 0 && (
              <circle cx={x(i)} cy={y(d.lost)} r="3.5" fill={LOST} stroke={INK} strokeWidth="1">
                <title>{`${dayLabel(d.day)}: ${d.lost} lost`}</title>
              </circle>
            )}
            {d.found > 0 && (
              <circle cx={x(i)} cy={y(d.found)} r="3.5" fill={FOUND} stroke={INK} strokeWidth="1">
                <title>{`${dayLabel(d.day)}: ${d.found} found`}</title>
              </circle>
            )}
          </g>
        ))}
      </svg>
      <p className="mt-1 flex gap-4 text-sm text-ink-soft">
        <span>
          <span className="inline-block h-2.5 w-5 rounded-full align-middle" style={{ background: LOST }} />{" "}
          Lost
        </span>
        <span>
          <span className="inline-block h-2.5 w-5 rounded-full align-middle" style={{ background: FOUND }} />{" "}
          Found
        </span>
      </p>
    </div>
  );
}

export function Donut({
  parts,
  centerLabel,
}: {
  parts: { label: string; value: number; color: string }[];
  centerLabel: string;
}) {
  const r = 54;
  const c = 2 * Math.PI * r;
  const total = parts.reduce((s, p) => s + p.value, 0);
  let acc = 0;

  return (
    <div className="flex flex-col items-center gap-4 sm:flex-row lg:flex-col xl:flex-row">
      <svg viewBox="0 0 140 140" width="150" height="150" role="img" aria-label={`${centerLabel}: ${total}`}>
        <circle cx="70" cy="70" r={r} fill="none" stroke={GRID} strokeWidth="18" />
        {total > 0 &&
          parts.map((p) => {
            const len = (p.value / total) * c;
            const el = (
              <circle
                key={p.label}
                cx="70"
                cy="70"
                r={r}
                fill="none"
                stroke={p.color}
                strokeWidth="18"
                strokeDasharray={`${len.toFixed(2)} ${(c - len).toFixed(2)}`}
                strokeDashoffset={(-acc).toFixed(2)}
                transform="rotate(-90 70 70)"
              />
            );
            acc += len;
            return el;
          })}
        <text x="70" y="68" textAnchor="middle" fontSize="26" fontWeight="800" fill={INK}>
          {total}
        </text>
        <text x="70" y="86" textAnchor="middle" fontSize="11" fill={SOFT}>
          {centerLabel}
        </text>
      </svg>
      <ul className="space-y-1 text-sm">
        {parts.map((p) => (
          <li key={p.label} className="flex items-center gap-2">
            <span className="inline-block h-3 w-3 rounded-sm border border-ink" style={{ background: p.color }} />
            <span>
              {p.label}: <strong>{p.value}</strong>
              {total > 0 && <span className="text-ink-soft"> ({Math.round((p.value / total) * 100)}%)</span>}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

export function StackedBars({ rows }: { rows: { label: string; lost: number; found: number }[] }) {
  const max = Math.max(1, ...rows.map((r) => r.lost + r.found));
  return (
    <div className="space-y-3">
      {rows.map((r) => (
        <div key={r.label}>
          <div className="mb-1 flex justify-between text-sm">
            <span className="font-semibold capitalize">{r.label}</span>
            <span className="text-ink-soft">
              {r.lost} lost, {r.found} found
            </span>
          </div>
          <div className="flex h-5 overflow-hidden rounded-md border-[1.5px] border-ink bg-paper">
            <div style={{ width: `${(r.lost / max) * 100}%`, background: LOST }} />
            <div style={{ width: `${(r.found / max) * 100}%`, background: FOUND }} />
          </div>
        </div>
      ))}
      {rows.length === 0 && <p className="text-sm text-ink-soft">No data yet.</p>}
    </div>
  );
}

export function SimpleBars({
  rows,
  color,
}: {
  rows: { label: string; value: number }[];
  color: string;
}) {
  const max = Math.max(1, ...rows.map((r) => r.value));
  return (
    <div className="space-y-3">
      {rows.map((r) => (
        <div key={r.label}>
          <div className="mb-1 flex justify-between text-sm">
            <span className="font-semibold capitalize">{r.label}</span>
            <span className="text-ink-soft">{r.value}</span>
          </div>
          <div className="h-5 overflow-hidden rounded-md border-[1.5px] border-ink bg-paper">
            <div className="h-full" style={{ width: `${(r.value / max) * 100}%`, background: color }} />
          </div>
        </div>
      ))}
      {rows.length === 0 && <p className="text-sm text-ink-soft">No data yet.</p>}
    </div>
  );
}
