export function usedExport(): number {
  return 1;
}

export function unusedInternalExport1(): void {} // no callers in-project
export function unusedInternalExport2(): void {} // no callers in-project
