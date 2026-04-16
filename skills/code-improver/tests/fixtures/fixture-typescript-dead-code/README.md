# fixture-typescript-dead-code

Contains 10 dead-code patterns across 6 files. Expected: auditor detects all 10 as Priority 1 dead-code issues.

## Convention

In `src/unused-export.ts`, an `export` is considered "unused internal" only when the declaration carries the inline comment `// no callers in-project`. Exports without that comment (e.g. `usedExport`) are treated as presumed public API and must NOT be flagged even if no sibling file in the fixture imports them. The auditor prompt must honor this convention.
