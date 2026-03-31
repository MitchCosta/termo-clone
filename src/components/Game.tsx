"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { getDailyAnswer, todayKeyUTC } from "@/lib/daily";
import { evaluateGuess, normalizeInput, type TileState } from "@/lib/evalGuess";
import { randomChoice } from "@/lib/random";
import { WORDS_PT_5 } from "@/lib/words-pt-new";
import { useSearchParams } from "next/navigation";

const WORD_LEN = 5;
const MAX_GUESSES = 6;

type Row = { guess: string; states: TileState[] | null; };
type Mode = "daily" | "unlimited";
type Persisted = { key: string; mode: Mode; answerOriginal: string; rows: Row[]; current: string; done: boolean; won: boolean; };

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
  const [answerOriginal, setAnswerOriginal] = useState<string>(() => getDailyAnswer(WORDS_PT_5));
  const answer = useMemo(() => normalizeInput(answerOriginal), [answerOriginal]);
  const [rows, setRows] = useState<Row[]>(() => emptyRows());
  const [current, setCurrent] = useState("");
  const [done, setDone] = useState(false);
  const [won, setWon] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const hiddenInputRef = useRef<HTMLInputElement | null>(null);
  const wordSetNormalized = useMemo(() => new Set(WORDS_PT_5.map((w) => normalizeInput(w))), []);
  const searchParams = useSearchParams();
  const testAnswerParam = searchParams.get("testAnswer");

  useEffect(() => {
    // #region agent log
    fetch("http://127.0.0.1:7433/ingest/2199d2ee-5fc6-424c-9806-4832b8f6e1e0", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Debug-Session-Id": "1f904a" },
      body: JSON.stringify({
        sessionId: "1f904a",
        location: "Game.tsx:mount",
        message: "game_client_mounted",
        data: { testAnswer: testAnswerParam ?? null },
        timestamp: Date.now(),
        hypothesisId: "H2",
        runId: "post-suspense",
      }),
    }).catch(() => {});
    // #endregion
  }, [testAnswerParam]);

  function showToast(msg: string) { setToast(msg); window.setTimeout(() => setToast(null), 1800); }

  function startDaily() {
    const k = todayKeyUTC();
    setMode("daily"); setGameKey(k);
    setAnswerOriginal(getDailyAnswer(WORDS_PT_5, k));
    setRows(emptyRows()); setCurrent(""); setDone(false); setWon(false);
  }

  function startUnlimitedNewGame() {
    const k = newUnlimitedKey();
    setMode("unlimited"); setGameKey(k);
    setAnswerOriginal(randomChoice(WORDS_PT_5).toUpperCase());
    setRows(emptyRows()); setCurrent(""); setDone(false); setWon(false);
  }

  function startForcedAnswer(original: string) {
    const normalized = normalizeInput(original);
    if (normalized.length !== WORD_LEN) {
      showToast("testAnswer precisa de 5 letras");
      return;
    }
    if (!wordSetNormalized.has(normalized)) {
      showToast("testAnswer não está na lista");
      return;
    }

    // Use "unlimited" mode so it doesn't overwrite daily progress.
    setMode("unlimited");
    setGameKey(`test-${normalized}-${Date.now()}`);
    setAnswerOriginal(original.toUpperCase());
    setRows(emptyRows());
    setCurrent("");
    setDone(false);
    setWon(false);
  }

  useEffect(() => {
    if (testAnswerParam) {
      try {
        startForcedAnswer(testAnswerParam);
        return;
      } catch {
        // fall through to normal restore
      }
    }

    try {
      const rawDaily = localStorage.getItem(storageKey("daily"));
      if (rawDaily) {
        const p = JSON.parse(rawDaily) as Persisted | (Persisted & { answer?: string });
        if (p.mode === "daily" && p.key === dailyKey) {
          const restoredAnswerOriginal = (p as any).answerOriginal ?? (p as any).answer;
          setMode("daily"); setGameKey(p.key); setAnswerOriginal(restoredAnswerOriginal);
          setRows(p.rows); setCurrent(p.current); setDone(p.done); setWon(p.won);
          return;
        }
      }
      const rawUnl = localStorage.getItem(storageKey("unlimited"));
      if (rawUnl) {
        const p = JSON.parse(rawUnl) as Persisted | (Persisted & { answer?: string });
        if (p.mode === "unlimited") {
          const restoredAnswerOriginal = (p as any).answerOriginal ?? (p as any).answer;
          setMode("unlimited"); setGameKey(p.key); setAnswerOriginal(restoredAnswerOriginal);
          setRows(p.rows); setCurrent(p.current); setDone(p.done); setWon(p.won);
          return;
        }
      }
      startDaily();
    } catch { startDaily(); }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [testAnswerParam]);

  useEffect(() => {
    const data: Persisted = { mode, key: gameKey, answerOriginal, rows, current, done, won };
    try { localStorage.setItem(storageKey(mode), JSON.stringify(data)); } catch {}
  }, [mode, gameKey, answerOriginal, rows, current, done, won]);

  function onTypeLetter(ch: string) { if (!done && current.length < WORD_LEN) setCurrent(c => (c + ch).slice(0, WORD_LEN)); }
  function onBackspace() { if (!done) setCurrent(c => c.slice(0, -1)); }

  function submit() {
    if (done) return;
    const guess = normalizeInput(current);
    if (guess.length !== WORD_LEN) return showToast("Precisa de 5 letras");
    if (!wordSetNormalized.has(guess)) return showToast("Palavra não está na lista (demo)");

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
    if (used >= MAX_GUESSES) { setDone(true); setWon(false); showToast(`Acabou — era ${answerOriginal}`); }
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
          <div className="text-zinc-400">Answer: {answerOriginal}</div>
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
