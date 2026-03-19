import { WORDS_PT_5 } from "@/lib/words-pt-new";

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
