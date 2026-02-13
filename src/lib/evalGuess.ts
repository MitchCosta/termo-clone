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
