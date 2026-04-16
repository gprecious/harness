export function compute(n: number): number {
  const unused1 = "this is never read";  // unused
  const unused2 = 42;                     // unused
  return n * 2;
}
