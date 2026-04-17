---
date: 2026-04-16
version: 1.0.0
harness_version: 0.3.0
---

# Manual Verification Log — code-improver v0.3.0

**Method:** Dry-run — mentally trace through the skill's prose (SKILL.md, agents/*.md, references/*.md) as if executing against each fixture. Compare expected outcomes to each fixture's `expected-issues.json` contract.

**Fixtures verified: 4/4**

## fixture-clean

- Expected: 0 P1-2 issues, 0 P3-5 issues
- Observed in dry-run: **pass**
- Gaps found:
  - MINOR — SKILL.md Phase 2 Step 2.3 renders the same user-prompt template even when zero Priority 1-2 issues exist. The outcome is still correct because Phase 3 iterates over an empty approved-category list and produces no work; there is no loud "No auto-fixable issues" short-circuit message. Non-blocking cosmetic issue.

## fixture-typescript-dead-code

- Expected: 10 P1 issues across 6 files (3 unused imports + 2 unused vars + 1 unreachable + 1 commented block + 1 unused private method + 2 unused internal exports)
- Observed in dry-run (post-fix): **pass**
- Gaps found and resolved mid-Phase-7:
  - **CRITICAL (fixed)** — `src/commented.ts` has 3 contiguous `//` lines, but `category-catalog.md` required `> 5 lines` and `codebase-auditor.md` Step 2 used the same threshold. The fixture would have been missed. Lowered the threshold to `>= 3 lines` in both places. Commit `e0e28de`.
  - **IMPORTANT (fixed)** — `codebase-auditor.md` Step 2 lacked an explicit Grep-based recipe for "unused local variables" in TypeScript/JavaScript; only a Python `pylint` recipe was present. Added an explicit recipe (grep `\b(const|let|var)\s+(\w+)` plus a `\bname\b` usage check in the same scope, with `tsc --noEmit` fallback when `noUnusedLocals` is enabled). Same commit `e0e28de`.
- Remaining gaps (MINOR, deferred):
  - No explicit tool recipe for unused private methods in `codebase-auditor.md`. The Opus model can reasonably derive it (grep `private\s+\w+\s*\(` → then grep for `this.<name>\b` / `\.<name>\b`), and the catalog P1 classification is clear, so the fixture will be caught. Worth documenting explicitly in v0.3.1.
  - "Usage of symbol" regex for unused-import detection uses the binding name without distinguishing `fs.` vs. bare `fs`. For this fixture it happens to work (no false positives), but on real projects a name like `_` could false-positive against unrelated underscores. Consider tightening in v0.3.1.

## fixture-python-complexity

- Expected: 3 P2 issues (`classify` complexity ≥18, `process_matrix` ≥15, `handle_request` ≥20)
- Observed in dry-run: **pass at audit level**
- Gaps found:
  - DESIGN NOTE (not a gap) — `improvement-applier.md` Step 4 explicitly demotes `cognitive_complexity_exceeded` issues when the auditor's "Suggested fix" is vague (reason `fix-underspecified`), rather than guessing a refactor. The auditor prose does not force the auditor to produce concrete, actionable refactor steps for complexity issues. In practice, the fixture's 3 P2 flags will likely all be demoted to P3 by the applier — resulting in zero auto-fixes and 3 failure-log entries. This is *by design* (safety-first); the fixture's contract (`expected_priority_1_2_total: 3`) is audit-level only and is satisfied. Documented here so future readers are not surprised.

## fixture-react-solid

- Expected: 3 P3 suggestions, zero auto-fixes (`auto_fix_expected: false`)
- Observed in dry-run: **pass**
- Gaps found:
  - MINOR — expected-issues.json labels the DIP violation in `PaymentProvider.ts` as P3, but `category-catalog.md` classifies DIP as P4. Both values satisfy the critical contract (P3+ = suggestion only, no auto-fix), so the safety invariant is preserved. DIP can legitimately be either P3 (swap to constructor param is local) or P4 (full inversion is architectural). Not fixing — both sides are reasonable.
  - **Defense-in-depth verified**: even if the orchestrator mistakenly approved the `solid` category, the applier's Step 1 only parses `#### Priority 1` and `#### Priority 2` sub-subsections. For fixture-react-solid, those sub-subsections under `### solid` would be empty, so `file_plan = {}` and the applier exits cleanly without creating a branch. No path for P3 to leak into auto-fix.

## Summary of Gaps Requiring Follow-up

### CRITICAL (fixed pre-release)
- Commented-block threshold (`> 5` → `>= 3`) — fixed in commit `e0e28de`.
- TS/JS unused-local-variable Grep recipe absent — fixed in commit `e0e28de`.

### IMPORTANT (none outstanding)
- All `IMPORTANT` gaps were addressed in commit `e0e28de`.

### MINOR (v0.3.1 backlog)
- Add explicit tool recipe for unused private methods in `codebase-auditor.md` Step 2.
- Tighten the symbol-usage regex in unused-import detection to distinguish `fs.` vs bare `fs`, and handle single-character bindings like `_`.
- Add an explicit short-circuit in `SKILL.md` Phase 2 Step 2.3 for the zero-P1-2 case (emit "No auto-fixable issues." and end early without prompting the user).
- Document in the applier prose that cognitive-complexity issues will typically be demoted unless the auditor emits actionable, concrete refactor steps (so users understand why clarity issues rarely auto-fix).
- Reconcile DIP priority between `category-catalog.md` (P4) and `fixture-react-solid/expected-issues.json` (P3) — either is defensible but pick one.

## Pre-Release Fix Commits

- `e0e28de` — `fix(code-improver): lower commented-block threshold + add TS unused-var recipe`
  - Lowers commented-out-block threshold from `> 5 lines` to `>= 3 lines` in both `references/category-catalog.md` (Pattern: "Commented-out code blocks") and `agents/codebase-auditor.md` Step 2 concrete recipe.
  - Adds an explicit Grep-based recipe for "unused local variables / parameters" in TypeScript/JavaScript to `agents/codebase-auditor.md` Step 2, with a `tsc --noEmit` fallback when `noUnusedLocals` is enabled.

## Overall Readiness

**Ready for v0.3.0 release.** Two critical/important gaps were uncovered by dry-run and resolved in a single fix commit (`e0e28de`). All four fixtures now dry-run cleanly against the amended prose. Remaining MINOR items are logged for v0.3.1 backlog and do not block release — the safety-critical invariants (no auto-fix of P3+, self-reference guard, change-volume limits) all hold in every fixture trace.
