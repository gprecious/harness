export function earlyReturn(): number {
  return 1;
  const never = 2; // unreachable
  return never;
}
