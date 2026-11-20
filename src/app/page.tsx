import Link from "next/link";

const steps = [
  { n: "1", title: "Report", text: "Say what you lost or found, with a photo and a map pin." },
  { n: "2", title: "Match", text: "AI compares descriptions, distance and dates, and shows why items match." },
  { n: "3", title: "Claim", text: "Answer the finder's hidden question to get their contact safely." },
];

export default function Home() {
  return (
    <main className="max-w-3xl mx-auto p-6 sm:p-10">
      <div className="text-center py-10">
        <h1 className="text-3xl sm:text-4xl font-bold mb-3">Pan-India Lost &amp; Found</h1>
        <p className="text-gray-500 mb-6">
          Report a lost or found item. AI finds likely matches for you.
        </p>
        <div className="flex gap-3 justify-center">
          <Link href="/report" className="bg-blue-600 text-white rounded px-5 py-2">
            Report an item
          </Link>
          <Link href="/items" className="border rounded px-5 py-2">
            Browse items
          </Link>
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        {steps.map((s) => (
          <div key={s.n} className="border rounded-lg p-4">
            <p className="text-sm text-blue-600 font-medium mb-1">Step {s.n}</p>
            <p className="font-semibold mb-1">{s.title}</p>
            <p className="text-sm text-gray-500">{s.text}</p>
          </div>
        ))}
      </div>
    </main>
  );
}