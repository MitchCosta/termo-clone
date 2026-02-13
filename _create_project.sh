#!/usr/bin/env bash
set -euo pipefail

mkdir -p src/app src/components src/lib public

cat > package.json <<'EOF'
{
  "name": "termo-clone",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1"
  },
  "devDependencies": {
    "@types/node": "20.12.12",
    "@types/react": "18.3.3",
    "@types/react-dom": "18.3.0",
    "autoprefixer": "10.4.19",
    "eslint": "8.57.0",
    "eslint-config-next": "14.2.5",
    "postcss": "8.4.38",
    "tailwindcss": "3.4.7",
    "typescript": "5.5.4"
  }
}
EOF

cat > next.config.mjs <<'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true
};
export default nextConfig;
EOF

cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

cat > next-env.d.ts <<'EOF'
/// <reference types="next" />
/// <reference types="next/image-types/global" />
EOF

cat > postcss.config.mjs <<'EOF'
const config = {
  plugins: { tailwindcss: {}, autoprefixer: {} }
};
export default config;
EOF

cat > tailwind.config.ts <<'EOF'
import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./src/components/**/*.{ts,tsx}", "./src/app/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        "tile-absent": "#3a3a3c",
        "tile-present": "#b59f3b",
        "tile-correct": "#538d4e"
      }
    }
  },
  plugins: []
};
export default config;
EOF

cat > src/app/globals.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root { color-scheme: dark; }
body { @apply bg-black text-zinc-100; }
EOF

cat > src/app/layout.tsx <<'EOF'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Termo Clone",
  description: "A simple Wordle/Termo-style clone"
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt">
      <body className="min-h-screen">{children}</body>
    </html>
  );
}
EOF

cat > src/app/page.tsx <<'EOF'
import Game from "@/components/Game";

export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col gap-6 px-4 py-8">
      <header className="flex items-baseline justify-between border-b border-zinc-800 pb-3">
        <h1 className="text-xl font-semibold tracking-tight">Termo Clone</h1>
      </header>

      <Game />

      <footer className="pt-2 text-xs text-zinc-500">
        Modes: daily + unlimited. Word list: <code>src/lib/words-pt.ts</code>
      </footer>
    </main>
  );
}
EOF

cat > src/lib/words-pt.ts <<'EOF'
export const WORDS_PT_5 = [
  "amigo","canto","carta","certo","coisa","corpo","dente","fazer","festa","folha",
  "gosto","linha","livro","mundo","noite","nuvem","parte","pedra","ponto","praia",
  "quase","ratos","sabor","sinal","sonho","tempo","terra","traco","valor","verde","vento"
] as const;
EOF

cat > src/lib/daily.ts <<'EOF'
import { WORDS_PT_5 } from "@/lib/words-pt";

export function todayKeyUTC(): string {
  const d = new Date();
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function hashStringToInt(str: string): number {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function getDailyAnswer(wordList = WORDS_PT_5, key = todayKeyUTC()): string {
  const idx = hashStringToInt(key) % wordList.length;
  return wordList[idx]!.toUpperCase();
}
EOF

cat > src/lib/evalGuess.ts <<'EOF'
export type TileState = "absent" | "present" | "correct";

export function normalizeInput(raw: string): string {
  return raw.toUpperCase().replace(/[^A-Z]/g, "");
}

export function evaluateGuess(guess: string, answer: string): TileState[] {
  const g = guess.split("");
  const a = answer.split("");
  const res: TileState[] = Array(g.length).fill("absent");
  const used = Array(a.length).fill(false);

  for (let i = 0; i < g.length; i++) {
    if (g[i] === a[i]) { res[i] = "correct"; used[i] = true; }
  }

  for (let i = 0; i < g.length; i++) {
    if (res[i] === "correct") continue;
    const ch = g[i];
    let found = -1;
    for (let j = 0; j < a.length; j++) {
      if (!used[j] && a[j] === ch) { found = j; break; }
    }
    if (found !== -1) { res[i] = "present"; used[found] = true; }
  }
  return res;
}
EOF

cat > src/lib/random.ts <<'EOF'
export function randomInt(maxExclusive: number): number {
  if (maxExclusive <= 0) return 0;
  if (typeof crypto !== "undefined" && "getRandomValues" in crypto) {
    const arr = new Uint32Array(1);
    crypto.getRandomValues(arr);
    return arr[0]! % maxExclusive;
  }
  return Math.floor(Math.random() * maxExclusive);
}
export function randomChoice<T>(arr: readonly T[]): T {
  return arr[randomInt(arr.length)]!;
}
EOF

cat > src/components/Game.tsx <<'EOF'
"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { getDailyAnswer, todayKeyUTC } from "@/lib/daily";
import { evaluateGuess, normalizeInput, type TileState } from "@/lib/evalGuess";
import { randomChoice } from "@/lib/random";
import { WORDS_PT_5 } from "@/lib/words-pt";

const WORD_LEN = 5;
const MAX_GUESSES = 6;

type Row = { guess: string; states: TileState[] | null; };
type Mode = "daily" | "unlimited";
type Persisted = { key: string; mode: Mode; answer: string; rows: Row[]; current: string; done: boolean; won: boolean; };

function storageKey(mode: Mode) { return `termo-clone:v1:${mode}`; }
function emptyRows(): Row[] { return Array.from({ length: MAX_GUESSES }, () => ({ guess: "", states: null })); }
function newUnlimitedKey() { return `unlimited-${Date.now()}`; }

function tileClass(s: TileState | null) {
  if (!s) return "bg-zinc-900 border-zinc-700";
  if (s === "absent") return "bg-tile-absent border-tile-absent";
  if (s === "present") return "bg-tile-present border-tile-present";
  return "bg-tile-correct border-tile-correct";
}

export default function Game() {
  const dailyKey = useMemo(() => todayKeyUTC(), []);
  const [mode, setMode] = useState<Mode>("daily");
  const [gameKey, setGameKey] = useState<string>(dailyKey);
  const [answer, setAnswer] = useState<string>(() => getDailyAnswer(WORDS_PT_5));
  const [rows, setRows] = useState<Row[]>(() => emptyRows());
  const [current, setCurrent] = useState("");
  const [done, setDone] = useState(false);
  const [won, setWon] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const hiddenInputRef = useRef<HTMLInputElement | null>(null);

  function showToast(msg: string) { setToast(msg); window.setTimeout(() => setToast(null), 1800); }

  function startDaily() {
    const k = todayKeyUTC();
    setMode("daily"); setGameKey(k);
    setAnswer(getDailyAnswer(WORDS_PT_5, k));
    setRows(emptyRows()); setCurrent(""); setDone(false); setWon(false);
  }

  function startUnlimitedNewGame() {
    const k = newUnlimitedKey();
    setMode("unlimited"); setGameKey(k);
    setAnswer(randomChoice(WORDS_PT_5).toUpperCase());
    setRows(emptyRows()); setCurrent(""); setDone(false); setWon(false);
  }

  useEffect(() => {
    try {
      const rawDaily = localStorage.getItem(storageKey("daily"));
      if (rawDaily) {
        const p = JSON.parse(rawDaily) as Persisted;
        if (p.mode === "daily" && p.key === dailyKey) {
          setMode("daily"); setGameKey(p.key); setAnswer(p.answer);
          setRows(p.rows); setCurrent(p.current); setDone(p.done); setWon(p.won);
          return;
        }
      }
      const rawUnl = localStorage.getItem(storageKey("unlimited"));
      if (rawUnl) {
        const p = JSON.parse(rawUnl) as Persisted;
        if (p.mode === "unlimited") {
          setMode("unlimited"); setGameKey(p.key); setAnswer(p.answer);
          setRows(p.rows); setCurrent(p.current); setDone(p.done); setWon(p.won);
          return;
        }
      }
      startDaily();
    } catch { startDaily(); }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const data: Persisted = { mode, key: gameKey, answer, rows, current, done, won };
    try { localStorage.setItem(storageKey(mode), JSON.stringify(data)); } catch {}
  }, [mode, gameKey, answer, rows, current, done, won]);

  function onTypeLetter(ch: string) { if (!done && current.length < WORD_LEN) setCurrent(c => (c + ch).slice(0, WORD_LEN)); }
  function onBackspace() { if (!done) setCurrent(c => c.slice(0, -1)); }

  function submit() {
    if (done) return;
    const guess = normalizeInput(current);
    if (guess.length !== WORD_LEN) return showToast("Precisa de 5 letras");
    if (!WORDS_PT_5.includes(guess.toLowerCase() as any)) return showToast("Palavra não está na lista (demo)");

    setRows(prev => {
      const next = [...prev];
      const idx = next.findIndex(r => r.states === null);
      if (idx === -1) return prev;
      next[idx] = { guess, states: evaluateGuess(guess, answer) };
      return next;
    });
    setCurrent("");

    if (guess === answer) { setDone(true); setWon(true); return showToast("Boa!"); }
    const used = rows.filter(r => r.states !== null).length + 1;
    if (used >= MAX_GUESSES) { setDone(true); setWon(false); showToast(`Acabou — era ${answer}`); }
  }

  function onKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter") { e.preventDefault(); return submit(); }
    if (e.key === "Backspace") { e.preventDefault(); return onBackspace(); }
    if (/^[a-zA-Z]$/.test(e.key)) { e.preventDefault(); onTypeLetter(e.key.toUpperCase()); }
  }

  const filledRows = useMemo(() => {
    const usedCount = rows.filter(r => r.states !== null).length;
    return rows.map((r, i) => (i === usedCount && !done)
      ? { guess: current.padEnd(WORD_LEN, " ").slice(0, WORD_LEN).toUpperCase(), states: null }
      : r
    );
  }, [rows, current, done]);

  return (
    <section className="flex flex-col items-center gap-4">
      <div className="w-full">
        <div className="mb-2 flex items-center justify-between gap-2">
          <div className="text-sm text-zinc-400">
            {mode === "daily" ? `Daily: ${gameKey} (UTC)` : "Unlimited"}
          </div>

          <div className="flex items-center gap-2">
            <div className="flex overflow-hidden rounded border border-zinc-700">
              <button type="button"
                className={"px-2 py-1 text-xs " + (mode === "daily" ? "bg-zinc-800 text-zinc-100" : "text-zinc-300 hover:bg-zinc-900")}
                onClick={startDaily}>daily</button>
              <button type="button"
                className={"px-2 py-1 text-xs " + (mode === "unlimited" ? "bg-zinc-800 text-zinc-100" : "text-zinc-300 hover:bg-zinc-900")}
                onClick={() => { setMode("unlimited"); startUnlimitedNewGame(); }}>unlimited</button>
            </div>

            {mode === "unlimited" ? (
              <button className="rounded border border-zinc-700 px-2 py-1 text-xs text-zinc-200 hover:bg-zinc-900"
                onClick={startUnlimitedNewGame} type="button">new</button>
            ) : (
              <button className="rounded border border-zinc-700 px-2 py-1 text-xs text-zinc-200 hover:bg-zinc-900"
                onClick={() => { try { localStorage.removeItem(storageKey("daily")); } catch {} startDaily(); }}
                type="button">reset</button>
            )}
          </div>
        </div>

        <div className="grid gap-2" style={{ gridTemplateRows: `repeat(${MAX_GUESSES}, minmax(0, 1fr))` }}
          onClick={() => hiddenInputRef.current?.focus()}>
          {filledRows.map((row, rIdx) => (
            <div key={rIdx} className="grid grid-cols-5 gap-2">
              {Array.from({ length: WORD_LEN }).map((_, cIdx) => {
                const ch = row.guess[cIdx] ?? "";
                const state = row.states ? row.states[cIdx] : null;
                return (
                  <div key={cIdx}
                    className={"flex h-14 items-center justify-center rounded border text-2xl font-semibold " + tileClass(state)}>
                    {ch === " " ? "" : ch}
                  </div>
                );
              })}
            </div>
          ))}
        </div>

        <input ref={hiddenInputRef} className="absolute left-[-9999px] top-[-9999px]"
          value={current} onChange={() => {}} onKeyDown={onKeyDown} autoFocus inputMode="text" />
      </div>

      <Keyboard onKey={(k) => { if (k === "ENTER") submit(); else if (k === "⌫") onBackspace(); else onTypeLetter(k); }} rows={rows} />

      {done && (
        <div className="w-full rounded border border-zinc-800 bg-zinc-950 p-3 text-sm">
          <div className="font-semibold">{won ? "You won." : "Game over."}</div>
          <div className="text-zinc-400">Answer: {answer}</div>
        </div>
      )}

      {toast && (
        <div className="fixed bottom-6 rounded bg-zinc-900 px-3 py-2 text-sm text-zinc-100 shadow">
          {toast}
        </div>
      )}
    </section>
  );
}

function Keyboard({ onKey, rows }: { onKey: (k: string) => void; rows: Row[]; }) {
  const used = useMemo(() => {
    const m = new Map<string, TileState>();
    const rank = (x: TileState) => (x === "correct" ? 3 : x === "present" ? 2 : 1);
    for (const r of rows) {
      if (!r.states) continue;
      for (let i = 0; i < r.guess.length; i++) {
        const ch = r.guess[i];
        const st = r.states[i]!;
        const prev = m.get(ch);
        if (!prev || rank(st) > rank(prev)) m.set(ch, st);
      }
    }
    return m;
  }, [rows]);

  const line1 = "QWERTYUIOP".split("");
  const line2 = "ASDFGHJKL".split("");
  const line3 = ["ENTER", ..."ZXCVBNM".split(""), "⌫"];

  function keyClass(ch: string) {
    if (ch === "ENTER" || ch === "⌫") return "bg-zinc-800 hover:bg-zinc-700";
    const st = used.get(ch);
    if (!st) return "bg-zinc-800 hover:bg-zinc-700";
    if (st === "absent") return "bg-tile-absent";
    if (st === "present") return "bg-tile-present";
    return "bg-tile-correct";
  }

  return (
    <div className="flex w-full flex-col gap-2 select-none">
      {[line1, line2, line3].map((line, idx) => (
        <div key={idx} className="flex justify-center gap-1">
          {line.map((k) => (
            <button key={k} type="button" onClick={() => onKey(k)}
              className={"h-11 rounded px-2 text-sm font-semibold text-zinc-100 " + keyClass(k)}
              style={{ minWidth: k === "ENTER" ? 64 : k === "⌫" ? 48 : 36 }}>
              {k}
            </button>
          ))}
        </div>
      ))}
    </div>
  );
}
EOF

cat > .gitignore <<'EOF'
node_modules
.next
out
dist
.vercel
.env*
.DS_Store
EOF

cat > README.md <<'EOF'
# termo-clone
Run:
npm install
npm run dev
EOF

echo "Created termo-clone project files."
