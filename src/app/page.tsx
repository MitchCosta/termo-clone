import Game from "@/components/Game";

export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col gap-6 px-4 py-8">
      <header className="flex items-baseline justify-between border-b border-zinc-800 pb-3">
        <h1 className="text-xl font-semibold tracking-tight">Termo Clone</h1>
      </header>

      <Game />

      <footer className="pt-2 text-xs text-zinc-500">
        Modes: daily + unlimited. Word list: <code>src/lib/words-pt-new.ts</code>
      </footer>
    </main>
  );
}
