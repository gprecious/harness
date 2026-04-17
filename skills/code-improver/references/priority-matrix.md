---
name: priority-matrix
description: Priority-based classification of issues. Priority 1-2 auto-fix; 3-5 suggestion-only.
---

# Priority Matrix

## Priority Levels

| Priority | Classification | Auto-Fix | Example |
|---|---|---|---|
| 1 | Quick Wins | YES | Unused import, magic number extraction, naming typo |
| 2 | Clarity | YES | Cognitive complexity reduction, guard clauses, boolean simplification |
| 3 | Structure | NO (suggestion) | Extract Class for SRP, Feature Envy, fat interface |
| 4 | Design | NO (suggestion) | DI introduction, inheritance→composition, parameter object |
| 5 | Architecture | NO (suggestion) | Module boundary redesign, package restructuring, API redesign |

## Auto-Fix Safety Rule

A Priority 1-2 fix is ONLY auto-applied when:
1. Project tests pass before fix
2. Project tests pass after fix
3. Project lint passes after fix
4. Project typecheck passes after fix (if typecheck command exists)

If ANY check fails → rollback + demote to Priority 3 in this iteration's report.

## Forbidden Auto-Fixes

Even when a change LOOKS like Priority 1, NEVER auto-modify:

- Files matched by `.code-improver-ignore`
- Files containing secrets (AWS key patterns, GitHub token patterns, `.env*`)
- Files > 1MB or detected-binary
- Files inside `harness/skills/code-improver/**` (self-reference guard)
- Files inside `docs/code-improver/**` or `docs/code-improvement/**`

## Change-Volume Limits Per PR

- Max 20 files changed per PR
- Max 500 lines changed per PR

If a category's fixes exceed either limit, split the PR by top-level directory within the category (e.g., `src/auth/` vs `src/api/`). Each split PR title appends `(1/N)`, `(2/N)`.

If a single file's fixes exceed the line limit (e.g., removing 600 lines of dead code from one file), request user confirmation before proceeding.

## Fixture Heuristic Clarifications

- For "unused export" detection: exports WITHOUT an inline `// no callers in-project` (or equivalent intent marker) should be treated as presumed public API and NOT flagged, when the project lacks a clear consumer. See `tests/fixtures/fixture-typescript-dead-code/README.md` for the fixture-level convention.
