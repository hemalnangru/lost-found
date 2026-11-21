import Link from "next/link";
import TicketBand from "@/components/TicketBand";
import HomeLive from "@/components/HomeLive";

const steps = [
  {
    n: "1",
    title: "Report",
    text: "Say what you lost or found. Add a photo and drop a pin on the map.",
  },
  {
    n: "2",
    title: "Match",
    text: "We compare descriptions, distance and dates, and show why two reports look alike.",
  },
  {
    n: "3",
    title: "Claim",
    text: "The finder sets a question. Answer it correctly and you get their contact details.",
  },
];

export default function Home() {
  return (
    <main className="max-w-6xl mx-auto px-5">
      <section className="grid gap-12 lg:grid-cols-2 items-center py-14 lg:py-20">
        <div>
          <h1 className="font-display font-extrabold text-4xl sm:text-5xl lg:text-[3.4rem] leading-[1.05]">
            Lost it somewhere in India? Someone may already have found it.
          </h1>
          <p className="mt-5 text-lg text-ink-soft max-w-prose">
            Report what you lost or found. We compare descriptions, places and dates, and
            tell you why two reports match.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/report" className="btn btn-primary">
              Report a lost item
            </Link>
            <Link href="/report?type=found" className="btn">
              I found something
            </Link>
          </div>
          <p className="mt-5 text-sm text-ink-soft max-w-md">
            Contact details stay hidden until the owner answers a question only they would
            know.
          </p>
        </div>

        <div className="relative mx-auto w-full max-w-md py-6" aria-hidden="true">
          <div className="ticket -rotate-2">
            <TicketBand type="lost" id="A7K2" />
            <div className="p-4">
              <p className="font-display font-bold text-lg">Black Samsung phone</p>
              <p className="text-sm text-ink-soft">Cracked screen, dog wallpaper</p>
              <p className="mt-2 text-xs text-ink-soft">Hisar, 14 Nov</p>
            </div>
          </div>
          <div className="ticket rotate-[1.5deg] mt-5 ml-8">
            <TicketBand type="found" id="Q93M" />
            <div className="p-4">
              <p className="font-display font-bold text-lg">Dark mobile phone</p>
              <p className="text-sm text-ink-soft">Broken display, puppy lock screen</p>
              <p className="mt-2 text-xs text-ink-soft">Hisar, 15 Nov</p>
            </div>
          </div>
          <div className="match-stamp absolute right-0 top-1/2 -translate-y-1/2 text-lg">
            82% match
          </div>
        </div>
      </section>

      <HomeLive />

      <section className="pb-16">
        <h2 className="font-display font-extrabold text-2xl mb-6">How it works</h2>
        <div className="grid gap-6 sm:grid-cols-3">
          {steps.map((s) => (
            <div key={s.n} className="border-t-[3px] border-ink pt-4">
              <p className="font-display font-extrabold text-4xl text-rail">{s.n}</p>
              <h3 className="font-display font-bold text-xl mt-1">{s.title}</h3>
              <p className="mt-1 text-ink-soft">{s.text}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="mb-16 rounded-2xl bg-ink text-white p-8 sm:p-10 grid gap-6 sm:grid-cols-[1fr_auto] items-center">
        <div>
          <h2 className="font-display font-extrabold text-2xl">You can judge every match yourself</h2>
          <p className="mt-2 text-white/85 max-w-2xl">
            Each match lists its reasons, such as 400 m away or same colour. A finder&apos;s
            contact details are stored separately and never reach your browser until you
            pass the check.
          </p>
        </div>
        <Link href="/items" className="btn">
          Browse found items
        </Link>
      </section>
    </main>
  );
}
