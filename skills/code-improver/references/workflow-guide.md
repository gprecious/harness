---
name: workflow-guide
description: 4-phase workflow (AUDIT → PRIORITIZE → APPLY → VERIFY) orchestration detail.
---

# Workflow Guide

The code-improver skill operates as an iterative 4-phase loop preceded by a preflight pass. Each iteration produces a single `iteration-N.md` under `docs/code-improvement/YYYY-MM-DD/`. State is persisted in `docs/code-improver/code-improver-state.md` so iterations resume cleanly.

## Phase 0: PREFLIGHT

Load state, check freshness, and validate the environment before doing any work.

- Load `docs/code-improver/code-improver-state.md`
  - If absent → stop and instruct the user to run `/improve --init`
  - If present but `last_refreshed_at` > 30 days → emit the monthly refresh reminder (see below) and continue
- Validate git environment:
  - Working tree clean (no uncommitted changes outside the improver itself)
  - `git remote -v` resolves and the configured PR base branch exists
- Validate `gh` CLI:
  - Installed and authenticated → normal path (PR creation enabled)
  - Missing or unauthenticated → degrade to local-only mode (branches + commits, no PR)
- Decide iteration number `N` = (max existing `iteration-*.md` number) + 1 in today's dated folder, or `1` if none

Phase 0 is idempotent and always runs first — including on `--resume`.

## Phase 1: AUDIT

Scan the project for issues and emit an audit report.

Dispatch the codebase-auditor subagent. Pass it `.code-improver-ignore` path, the categories to check, and paths to category-catalog.md + priority-matrix.md. The auditor outputs an audit-report.md which the orchestrator stitches into iteration-N.md.

The auditor:
- Applies `.code-improver-ignore` to exclude paths
- Scans each of the 9 categories (see `category-catalog.md`) independently — ideally in parallel
- Assigns each detected issue a Priority 1-5 (see `priority-matrix.md`)
- Records quantitative metrics (cognitive complexity distribution, coupling, coverage, file-size distribution, etc.) for use in plateau detection and PR bodies
- Emits `audit-report.md` listing every issue with: file path, line range, category, priority, one-line description

The orchestrator stitches the audit report into the audit section of `iteration-N.md`.

## Phase 2: PRIORITIZE

Classify the audit output into actionable buckets and obtain user approval.

- Split issues:
  - Priority 1-2 → candidate auto-fix bucket
  - Priority 3-5 → suggestion-only bucket (recorded, never auto-applied)
- Group auto-fix candidates by category
- For each category, draft a PR plan:
  - Files touched, estimated line delta
  - If > 20 files OR > 500 lines → mark for splitting (see `pr-strategy.md`)
- Present the user with a per-category approval menu:
  - Which categories to apply this iteration
  - Explicit confirmation for any single-file change that exceeds the line limit
- Record the approved plan into iteration-N.md's prioritize section

## Phase 3: APPLY

Apply approved fixes, verify them, and open PRs.

For each approved category, first dispatch improvement-applier (creates branch, applies fixes, runs tests/lint/typecheck, binary-search rollback on failure). On success dispatch pr-creator (reads pr-strategy.md, detects commit convention via `git log -50 --format=%s`, opens PR).

The improvement-applier:
- Creates a category-scoped feature branch using the naming in `pr-strategy.md`
- Applies Priority 1-2 fixes for the category
- Runs project test, lint, and typecheck commands
- On any failure: binary-search rollback across the fix set to isolate the offending change, drop it, demote its issue to Priority 3 in the iteration report, and retry
- Records before/after metrics for the category

The pr-creator:
- Reads `pr-strategy.md`
- Detects commit convention via `git log -50 --format=%s`
- Opens one PR per category (or multiple split PRs when volume limits trip)
- Writes PR URL + before/after metrics back into iteration-N.md

If `gh` is unavailable, the pr-creator records the branch and marks the PR "pending (local-only mode)".

## Phase 4: VERIFY

Detect progress, plateau, or completion by re-auditing.

Re-dispatch codebase-auditor. Compare new audit to previous iteration's metrics. Apply plateau-detection.md algorithm. On plateau: present the 4-option menu (Halt default / Continue / Refresh / Reduce scope).

The verifier:
- Re-runs the codebase-auditor against the current tree (typically after merges)
- Computes, for the last two iteration pairs: `resolved`, `new`, and `ratio = new / max(resolved, 1)`
- Writes the comparison into iteration-N.md's verify section
- Increments `consecutive_plateau_iterations` when `ratio ≥ 0.80`; resets it otherwise
- When plateau is confirmed (2 consecutive), presents the 4-option menu described in `plateau-detection.md` and, on Halt, emits `summary.md`

## Command Modes

| Command | Behavior |
|---|---|
| `/improve --init` | Run full initialization: detect language/framework, research best practices, write 5 reference files and `code-improver-state.md` with `last_refreshed_at = today`. |
| `/improve --init --refresh` | Re-run initialization, overwriting existing reference files and resetting `last_refreshed_at`. |
| `/improve` | Run all 4 phases: AUDIT → PRIORITIZE → APPLY → VERIFY for one iteration. |
| `/improve --audit` | Run Phase 0 + Phase 1 only. Produce audit section of iteration-N.md; stop before prioritize. |
| `/improve --apply` | Assume the latest iteration-N.md has an audit section and a prioritize plan; run Phase 3 only. |
| `/improve --category <name>` | Same as `/improve` but restrict APPLY to the named category (e.g., `dead-code`). Audit still covers all 9 categories. |
| `/improve --verify` | Run Phase 4 only — re-audit and compare against the previous iteration. |
| `/improve --resume` | Load state, detect where the last iteration stopped, and resume at that phase. |

## Monthly Refresh Reminder

Every `/improve` execution checks `last_refreshed_at` in the state file.

- If the value is more than 30 days old, emit a non-blocking message, e.g.:
  > ⚠ Reference files were last refreshed N days ago. Consider running `/improve --init --refresh` to pull the latest best practices.
- The current command continues regardless — the reminder never halts execution.
- The reminder is emitted at most once per `/improve` invocation.
