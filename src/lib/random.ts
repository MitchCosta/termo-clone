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
