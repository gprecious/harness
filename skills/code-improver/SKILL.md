---
name: code-improver
description: Iterative codebase improvement orchestrator. Audits → prioritizes → auto-fixes Priority 1-2 via category-split PRs → tracks plateau across iterations. Independent of harness-orchestrator.
version: 1.0.0
tools: Read, Write, Edit, Bash, Grep, Glob, Agent, WebFetch, TodoWrite
---

# code-improver

## Overview

An independent, iterative codebase improvement orchestrator. On `/improve --init`, it detects the project's language, frameworks, tooling, and conventions, then runs thorough web research to produce 5 project-specific reference documents. On subsequent `/improve` runs it executes a 4-phase loop — AUDIT (codebase-auditor subagent scans 9 categories) → PRIORITIZE (Priority 1-2 auto-fix vs Priority 3-5 suggestion) → APPLY (improvement-applier subagent per category, then pr-creator subagent opens category-split PRs) → VERIFY (re-audit and plateau detection). Every decision is persisted to disk (`code-improver-state.md` + `iteration-N.md`) so any interruption is safely resumable via `/improve --resume`. This skill is **independent of `harness-orchestrator`**: it does not dispatch `/feature`, it is not dispatched by `/feature`, and it can be installed and used in isolation. Its ethos is report-first, safe-only-automation, and plateau-aware termination.

## When to Use

- Existing codebase feels messy or bloated
- Before major feature work (clean up first, then build)
- After a large change (sweep for regressions in code quality)
- Periodic maintenance (monthly cycles aligned with reference refresh)

Don't use this skill for:

- New feature development (use `/feature` — harness-orchestrator)
- One-off bug fixes (direct edit, no need for full audit)
- Security incidents (manual triage, don't rely on automated fixes)

## Command Modes

| Command | Action |
|---|---|
| `/improve --init` | First-time setup. Detects environment, runs web research, generates 5 project-reference files + state + `.code-improver-ignore`. |
| `/improve --init --refresh` | Regenerate references with latest research (triggered by 30-day reminder or manually). Preserves `initialized_at` and `metrics_history`. |
| `/improve` | Full flow: PREFLIGHT → AUDIT → PRIORITIZE → APPLY (→ VERIFY on request). |
| `/improve --audit` | Audit only. Writes iteration report, no fixes, no PR, no user prompt. |
| `/improve --apply` | Read latest audit; apply Priority 1-2 fixes per category; open PRs. |
| `/improve --category <name>` | Run full flow but restrict APPLY to one category (e.g. `--category dead-code`). AUDIT still covers all 9 categories. |
| `/improve --verify` | Re-audit after PR merges, compare to previous iteration, check plateau. |
| `/improve --resume` | Recover from interruption using `code-improver-state.md`. |

Argument parsing is left-to-right; the first recognized mode flag wins. `--category <name>` may combine with `--audit`, `--apply`, or the default full flow. `--refresh` is only valid with `--init`.

## Phase 0: PREFLIGHT

Runs before every command (except the first-ever `--init` invocation, which has no state file yet).

### Step 0.1: Load state

Read `docs/code-improver/code-improver-state.md`.

- If the file is **missing**:
  - If the current command is `/improve --init`: proceed to the `--init` section below.
  - Otherwise: print a clear message ("Run `/improve --init` first — no state file at `docs/code-improver/code-improver-state.md`.") and abort.
- If present: parse the YAML frontmatter (`current_iteration`, `current_phase`, `last_refreshed_at`, `harness_version`) and the body sections (Detected Environment, Commands, Git / PR Config, Metrics History, Plateau Tracking, Resume Context).

### Step 0.2: Refresh reminder (non-blocking)

Compute `(today − last_refreshed_at)` in days. If greater than 30:

```
⚠ Your code-improver references are N days old.
Run `/improve --init --refresh` to regenerate with latest research.
(Continuing with current references — this is non-blocking.)
```

Emit at most once per command invocation. Never halt execution.

### Step 0.3: Git + gh verification

Run preflight checks:

```bash
git rev-parse --is-inside-work-tree  # confirm we are in a git repo
git remote -v                        # confirm remote exists
git rev-parse --abbrev-ref origin/HEAD 2>/dev/null  # detect PR base branch (strip "origin/")
gh auth status                       # confirm gh authenticated
```

Interpretation:

- Inside a git repo AND remote exists AND `gh auth status` exits 0 → `full_mode = true` (PR creation enabled).
- Any of the above fails → `full_mode = false` (local-only mode — branches + commits only, PR creation deferred to the user).

Update `gh_auth_status` in the state file's `Git / PR Config` section with the observed result (`authenticated (user: <login>)`, `unauthenticated`, or `not_installed`). If the PR base branch could not be detected automatically, prompt the user for it and persist their choice to `pr_base_branch`.

### Step 0.4: Dirty working tree check (for mutating modes only)

For `/improve`, `/improve --apply`, and `/improve --category <name>`: run `git status --porcelain`. If output is non-empty, abort with a message listing the dirty paths — APPLY must start from a clean tree so the applier can branch safely.

For `/improve --audit`, `/improve --verify`, `/improve --init`, `/improve --init --refresh`, and `/improve --resume`: skip this check (they do not mutate source files).

## `--init` (First-Time Setup)

Produces 5 project-reference files, the state file, and `.code-improver-ignore`. Runs when the state file does not yet exist, or when `--refresh` is supplied to regenerate references.

### Step I.1: Environment detection

Detect the project's tech stack by inspecting well-known manifest files at the project root. Use `Read` and `Glob` only — never mutate.

- **Language**:
  - `package.json` present → `typescript` if `tsconfig.json` also present, else `javascript`
  - `pyproject.toml` / `requirements.txt` / `setup.py` / `setup.cfg` → `python`
  - `go.mod` → `go`
  - `Cargo.toml` → `rust`
  - `pom.xml` → `java`; `build.gradle` / `build.gradle.kts` → `java` or `kotlin` depending on sources
  - `Gemfile` → `ruby`; `composer.json` → `php`
  - If multiple match, pick the one with the most source files (via `Glob` counts).
- **Frameworks** (from the relevant dependency file):
  - TS/JS: `next`, `react`, `vue`, `svelte`, `angular`, `nuxt`, `remix`, `tailwindcss`
  - Python: `django`, `fastapi`, `flask`, `pydantic`, `sqlalchemy`, `pytest`
  - Go: `gin`, `echo`, `fiber`
  - Others: detect from the idiomatic dependency file for that language.
- **Package manager** (lockfile presence, first match wins):
  - `pnpm-lock.yaml` → `pnpm`; `yarn.lock` → `yarn`; `package-lock.json` → `npm`; `bun.lockb` → `bun`
  - `poetry.lock` → `poetry`; `uv.lock` → `uv`; `pipfile.lock` → `pipenv`
  - `go.sum` → `go`; `Cargo.lock` → `cargo`
- **Commands** (test/lint/typecheck/build): parse the idiomatic config
  - TS/JS: `scripts` in `package.json`
  - Python: `[tool.poetry.scripts]` in `pyproject.toml`, then `Makefile` targets
  - Go/Rust: inferred defaults (`go test ./...`, `cargo test`), but also check `Makefile`/`justfile`
  - If a command cannot be confidently inferred, record it as the literal string `"unavailable"` — the applier gracefully degrades.

### Step I.2: Codebase analysis

Sample 20-50 source files across distinct directories (use `Glob` with the detected language's extensions, then pick a representative cross-section).

Extract:

- **Naming conventions**: from sampled identifiers, detect dominant case (`snake_case`, `camelCase`, `PascalCase`) by token type (file, function, class, constant). Record the dominant convention per token type.
- **Import-order convention**: parse the first ~20 lines of ~15 files. Check for `external → internal → relative` grouping, alphabetical within group, or ESLint-enforced (look for `.eslintrc*` with `import/order` rule).
- **Commit convention**: run `git log -100 --format=%s --no-merges` and classify per the rules in `references/pr-strategy.md` (Conventional Commits / Angular / custom prefix / plain imperative). Persist the detected style as the state's `commit_convention` field.
- **Style rules**: if `.prettierrc*`, `.eslintrc*`, `pyproject.toml [tool.ruff|black|flake8|mypy]`, or `rustfmt.toml` exists, summarize the enforced rules relevant to P1/P2 fixes.

### Step I.3: Web research (thorough)

Use `WebFetch` to gather 2025-2026 best-practices knowledge. For each detected item (language, each major framework, package manager):

- 2025-2026 best practices for the detected language/version
- Framework-specific anti-patterns and recent CVEs
- Known deprecated dependencies (and their modern replacements)
- Modern idioms vs. legacy patterns

Aim for **3-5 authoritative sources per topic** (official docs, language-committee blogs, well-established practitioner blogs, CVE databases). Cite the URLs inline in the generated reference files so the user can audit the research.

WebFetch is the slowest part of `--init`. Keep it bounded: cap total WebFetch calls at ~25 per `--init` and stop early if you have enough material to fill the templates concretely.

### Step I.4: Generate 5 reference files

For each of the 5 templates under `skills/code-improver/templates/project-references/`, copy the template to `docs/code-improver/references/<same-name>` and substitute placeholders using Steps I.1-I.3 findings:

- `language-guide.md` — language version, idioms, deprecations, modern alternatives
- `framework-guide.md` — detected frameworks, anti-patterns, CVEs, migration hints
- `project-conventions.md` — naming / import-order / commit / style rules from Step I.2
- `improvement-priorities.md` — project-specific nudges to the priority matrix (e.g., "this project treats exported-from-index.ts files as public API")
- `anti-patterns.md` — language + framework anti-patterns discovered during research, with concrete examples

Use `Write` for each destination file.

### Step I.5: Generate state file

Copy `templates/code-improver-state.md` to `docs/code-improver/code-improver-state.md` and fill:

- `version: 1`, `harness_version: <from plugin.json>`, `current_iteration: 0`, `current_phase: idle`
- `initialized_at` = now (ISO-8601 UTC)
- `last_refreshed_at` = now
- Detected Environment / Commands / Git-PR Config from Steps I.1 + 0.3
- Metrics History: empty list (no iterations yet)
- Plateau Tracking: `consecutive_plateau_iterations: 0`, `plateau_threshold: 0.80`
- Resume Context: all null/empty

### Step I.6: Generate `.code-improver-ignore`

Copy `templates/.code-improver-ignore` to `<project_root>/.code-improver-ignore`. Offer to customize — prompt the user for additional paths to exclude (e.g., `legacy/**`, `vendor/**`, `migrations/*.sql`) and append any they provide.

Ensure the file includes — even if the user overrides it — the hardcoded self-reference paths:

- `harness/skills/code-improver/**`
- `docs/code-improver/**`
- `docs/code-improvement/**`

### Step I.7: Summary

Report to the user:

- Detected language + frameworks + package manager
- Files generated: 5 references + state file + `.code-improver-ignore`
- Research source count (WebFetch calls made)
- Recommendation: "Review `docs/code-improver/references/` then run `/improve --audit` to see the first audit without making any changes."

### `--refresh` variant

If `--init --refresh` is invoked and state already exists:

- Preserve `initialized_at` and `metrics_history`
- Update `last_refreshed_at` to now
- Regenerate the 5 reference files (Steps I.1-I.4) — overwrite existing
- Do NOT reset `current_iteration`, `current_phase`, or `consecutive_plateau_iterations`
- Do NOT overwrite `.code-improver-ignore` (the user may have customized it); instead, warn if the 3 hardcoded self-reference paths are absent and offer to append them.

## Phase 1: AUDIT

### Step 1.1: Resolve iteration number

Read state → `current_iteration`. For a new audit started by `/improve` or `/improve --audit`:

- `N = current_iteration + 1`
- Set `current_phase = AUDIT` and persist.

For `--resume` entering AUDIT: re-use the same `N` (audit is idempotent).

### Step 1.2: Prepare iteration directory

Create `docs/code-improvement/<today-YYYY-MM-DD>/` if it does not exist. The iteration file path is `docs/code-improvement/<today>/iteration-N.md`; the audit-report path is `docs/code-improvement/<today>/audit-iter-N.md`.

### Step 1.3: Dispatch `codebase-auditor`

Use the `Agent` tool to dispatch `codebase-auditor` with these inputs:

- `project_root` = current working directory (absolute)
- `ignore_file_path` = `<project_root>/.code-improver-ignore` (or `null` if missing)
- `categories_to_check` = `["all"]` by default; if `/improve --category <name>` was invoked, still pass `["all"]` so the audit covers the whole codebase (the category restriction applies only to APPLY). For `/improve --audit --category <name>` the same applies — audit is always broad.
- `iteration_number` = N
- `category_catalog_path` = `${CLAUDE_PLUGIN_ROOT}/skills/code-improver/references/category-catalog.md`
- `priority_matrix_path` = `${CLAUDE_PLUGIN_ROOT}/skills/code-improver/references/priority-matrix.md`
- `audit_template_path` = `${CLAUDE_PLUGIN_ROOT}/skills/code-improver/templates/audit-report.md`
- `project_references_dir` = `<project_root>/docs/code-improver/references/`
- `output_path` = `<project_root>/docs/code-improvement/<today>/audit-iter-N.md`

Wait for the agent to complete. It returns the absolute path to the written audit-report plus summary stats (Priority buckets, counts, Forbidden-Auto-Fix demotions, `files_scanned_count`, `files_excluded_count`).

If the agent reports a fatal error (missing catalog/matrix/template), abort with the agent's error message.

### Step 1.4: Stitch audit into `iteration-N.md`

Read the audit-report. Create (or update, on `--resume`) `docs/code-improvement/<today>/iteration-N.md` by filling `templates/iteration.md`:

- Frontmatter: `iteration: N`, `started_at: <ISO-8601 UTC>`, `status: in_progress`, `harness_version: <from plugin.json>`
- Summary: total issues + per-priority counts from the audit's Category Totals table
- Metrics (Before / After): `before` = last entry from state's Metrics History (or "baseline" for iteration 1); `after` = current audit's Metrics Snapshot; Δ computed as `after − before` with sign
- Issues by Category / Priority: copy verbatim from the audit-report
- Auto-Fixes Applied: empty placeholder until Phase 3
- Suggestions (Priority 3-5): populated immediately from the audit's P3/P4/P5 bullets
- Failure Log: empty placeholder — the applier appends to this section in Phase 3
- Plateau Check: left empty until Phase 4
- Issues Carried Over: for iteration 1, empty; for N ≥ 2, compute the `[RESOLVED] / [STILL PRESENT] / [DEFERRED]` list by diffing the previous iteration's issues vs. the current audit

Update state: `current_phase = AUDIT → PRIORITIZE`, persist.

## Phase 2: PRIORITIZE

### Step 2.1: Classify

Parse the audit-report (already stitched into iteration-N.md). Partition:

- **Priority 1-2** → auto-fix candidates, grouped by category
- **Priority 3-5** → suggestions only. These are already in the iteration file's "Suggestions" section — no further action in Phase 2.

### Step 2.2: Build PR plan

For each category with one or more Priority 1-2 issues:

- Enumerate files touched (deduplicated)
- Estimate lines-changed by summing the line ranges of each issue. This is a heuristic (actual lines depend on the applier); treat it as a ceiling.
- If files > 20 OR estimated lines > 500: flag the category for split. The actual split will happen inside `pr-creator`; the orchestrator just surfaces the expectation to the user.
- Record as a planned PR entry: `{category, file_count, estimated_lines, split_expected}`.

### Step 2.3: Present the plan to the user

Example prompt to emit:

```
Audit complete. Found X issues (Priority 1-2: Y, Priority 3-5: Z).

Priority 1-2 (auto-fixable):
  - dead-code: 87 issues across 34 files (~520 lines) — SPLIT EXPECTED
  - clarity:   12 issues across 8 files (~120 lines)

Priority 3-5 (suggestions only, see iteration-N.md):
  - solid:       3 issues
  - performance: 5 issues

Proposed PR plan:
  - dead-code → multi-part PR (by top-level dir)
  - clarity   → 1 PR

Proceed with all? Select categories? Skip (audit-only)?
```

Accept user input:

- "all" / "yes" → proceed with all categories
- "<category1>,<category2>" → restrict APPLY to those categories
- "skip" → treat this run as audit-only; end after Phase 2

If `/improve --category <name>` was invoked, the prompt is **pre-filtered** to that category only — the user still confirms, but alternatives are not shown.

If `/improve --audit` was invoked, **skip this prompt entirely** — just finalize iteration-N.md's `status` stays `in_progress`, set state's `current_phase = idle` (audit artifacts remain for a later `--apply`), and return.

Update state: `current_phase = PRIORITIZE → APPLY` (if proceeding) or `idle` (if skipping).

## Phase 3: APPLY

Iterate over approved categories in **alphabetical order** for determinism. For each category:

### Step 3.1: Dispatch `improvement-applier`

Use the `Agent` tool with inputs (see `agents/improvement-applier.md` for the full contract):

- `project_root` = cwd
- `audit_report_path` = `<iteration-N.md path>` (the applier parses the `### {{category}}` section from the iteration report directly)
- `category` = the current category name
- `iteration_number` = N
- `priority_matrix_path` = `${CLAUDE_PLUGIN_ROOT}/skills/code-improver/references/priority-matrix.md`
- `test_command` / `lint_command` / `typecheck_command` = from state's Commands section (use literal `"unavailable"` for any that couldn't be detected)
- `branch_name` = `code-improver/iter-N/<category>` (per `pr-strategy.md`)
- `output_failure_log_path` = the iteration-N.md path (the applier appends a `## Failure Log` entry there on demotions)

Before dispatching, persist to state's Resume Context: `pending_category = <category>`, so a crash mid-apply can resume cleanly.

Receive from the agent:

```
{
  status: "success" | "partial" | "failure",
  branch_name, files_changed, files_demoted,
  test_result, lint_result, typecheck_result,
  commit_sha, failure_log_appended_to
}
```

If `status = failure` **with no branch**: record the category as skipped in iteration-N.md under a "Skipped Categories" bullet (one line, with the reason from the error). Continue to the next category — do NOT abort the whole APPLY.

If `status = failure` **because every planned file was a culprit and the branch was deleted**: same handling — skip and continue.

### Step 3.2: Dispatch `pr-creator` (when full_mode = true and applier produced a branch)

Skip this step if any of:

- `full_mode = false` (gh not available) — mark this category's PR status as "local-only; push + open PR manually"
- The applier's status was `failure` and no branch exists

Otherwise, use the `Agent` tool to dispatch `pr-creator` with inputs (see `agents/pr-creator.md`):

- `project_root` = cwd
- `branch_name` = from the applier
- `category`, `iteration_number`
- `pr_base_branch` = from state
- `audit_report_path` = iteration-N.md path (same as applier's input)
- `iteration_report_path` = same as audit_report_path (the iteration report IS the stitched-in audit in this design)
- `metrics_before` = last entry from state's Metrics History (or empty object for iteration 1)
- `metrics_after` = current audit's Metrics Snapshot (parse from iteration-N.md)
- `pr_strategy_path` = `${CLAUDE_PLUGIN_ROOT}/skills/code-improver/references/pr-strategy.md`
- `gh_auth_status` = from state
- `files_changed` = from the applier
- `verification_results` = `{tests: applier.test_result, lint: applier.lint_result, typecheck: applier.typecheck_result}`

Receive the pr-creator's structured result: `{status, prs, commit_style_detected, split_required, error}`. Each `prs[*].url` may be a GitHub URL or `null`.

### Step 3.3: Update `iteration-N.md`

Append to the "Auto-Fixes Applied (by category → PR)" section, using the template:

- Category heading with PR URL(s) — or "local-only" / the error string on failure
- Files changed count, lines added/removed (from pr-creator's `prs[*].files_count` / `lines_changed`, or `git diff --stat` post-hoc for local-only)
- Verification check symbols (`✅/❌/⏭`)
- Bullet list of specific fixes (one-liners extracted from the audit-report's `### {{category}}` Priority 1/2 bullets)

If the category was skipped (applier failure + no branch), under "Auto-Fixes Applied" write a single bullet: `- <category>: skipped (see Failure Log)`.

### Step 3.4: Update state

- Append a metrics snapshot to `metrics_history` (format per `templates/code-improver-state.md`): one entry per completed iteration, keyed `iteration_N`, containing the values from the audit's Metrics Snapshot.
- Clear `pending_category` in Resume Context.
- When all approved categories have been processed, set `current_phase = idle` (unless the invocation was `/improve` and the user asked to run VERIFY immediately, in which case set `current_phase = VERIFY`).
- Finalize iteration-N.md: `status: completed`, `completed_at: <ISO-8601 UTC>`.

## Phase 4: VERIFY (Optional)

Triggered by `/improve --verify`, or automatically if the user explicitly requests verification immediately after PR merges.

### Step 4.1: Re-dispatch `codebase-auditor`

Same dispatch as Phase 1 (Step 1.3), but:

- Write the audit output to a fresh path `docs/code-improvement/<today>/verify-audit-iter-N.md` — do NOT overwrite the iteration's primary audit.
- `iteration_number` = current N (the iteration being verified).

### Step 4.2: Compute deltas

Diff the previous iteration's audit (from `iteration-N.md`'s Issues by Category section or state's metrics_history) against the fresh verify-audit:

```
resolved = count(issues in iteration-N.md NOT in verify audit)
new      = count(issues in verify audit NOT in iteration-N.md)
ratio    = new / max(resolved, 1)
```

Issue identity for matching = `(file_path, line_range_start, category, pattern)`. Exact matching — a one-line shift counts as "resolved + new", which is acceptable for plateau purposes.

Write the Plateau Check section of iteration-N.md:

```
## Plateau Check
- resolved: X, new: Y, ratio: Y/max(X,1)
- Consecutive plateau iterations: <count>
- Plateau confirmed: yes | no
```

### Step 4.3: Apply plateau detection

Per `references/plateau-detection.md`:

- If `ratio >= 0.80`: increment `consecutive_plateau_iterations` in state.
- Otherwise: reset `consecutive_plateau_iterations = 0`.
- If `consecutive_plateau_iterations >= 2`: plateau confirmed.

### Step 4.4: On plateau, present the 4-option menu

Per `references/plateau-detection.md`:

```
⚠ Plateau detected (iteration N)
- New issues (X) ≥ 80% of resolved issues (Y)

Options:
  (1) Halt — generate summary.md and stop   [default]
  (2) Continue anyway — proceed to iteration N+1
  (3) Refresh references — run /improve --init --refresh
  (4) Reduce scope — focus on specific category (/improve --category <name>)
```

Default action is (1) Halt. On Halt, generate `docs/code-improvement/<today>/summary.md` with:

- Cumulative metrics (first iteration vs. current)
- Iteration history table (date, issues fixed, PRs created, plateau flag)
- Plateau reasoning (which two consecutive iterations triggered it)
- Deferred items (Priority 3-5 accumulated across iterations, with a migration note to a suitable tracker)

Set iteration-N.md's `status: plateau` and state's `current_phase = idle`.

## Phase 5: RESUME (for `--resume`)

Read state. Based on `current_phase` and `pending_*`:

- `current_phase = AUDIT` → restart from Phase 1. Audit is idempotent (deterministic); the previous partial iteration-N.md will be overwritten.
- `current_phase = PRIORITIZE` → the audit is already done. Re-read iteration-N.md and re-present the PR plan prompt (Step 2.3).
- `current_phase = APPLY` → inspect:
  - Which category branches already exist: `git branch --list 'code-improver/iter-N/*'`
  - Which categories are already documented in iteration-N.md's "Auto-Fixes Applied" section
  - Resume from the first category in alphabetical order that has no branch and no iteration-N.md entry.
  - If `pending_category` is set, that category is the checkpoint. Verify the branch state: if the branch exists and has a commit, assume the applier finished and dispatch `pr-creator`; otherwise re-dispatch `improvement-applier` (the applier's preconditions will detect any stale branch and abort with a clear message).
- `current_phase = VERIFY` → restart from Phase 4.
- `current_phase = idle` → nothing in flight; tell the user there is nothing to resume.

After resume completes a phase, continue naturally into subsequent phases (unless the original invocation was mode-restricted, e.g., `--audit`).

## Error Handling

Refer to the internal references for the authoritative rules:

- `references/priority-matrix.md` — auto-fix safety rules, Forbidden Auto-Fix list, change-volume limits
- `references/plateau-detection.md` — plateau algorithm, 4-option menu
- `references/pr-strategy.md` — branch naming, commit-style detection, PR splitting, gh fallback
- `references/workflow-guide.md` — phase-by-phase expected behavior
- `references/category-catalog.md` — category definitions and heuristics

Specific failure cases handled by this orchestrator:

- **State file missing on non-init command** → abort with instruction to run `/improve --init`.
- **Dirty working tree before APPLY** → abort with list of dirty paths (the applier would abort anyway; fail fast at the orchestrator level).
- **Applier returns `failure` for a single category** → record in iteration-N.md under "Skipped Categories", skip that category, continue APPLY for remaining approved categories.
- **pr-creator returns `failure` (self-reference violation)** → loudly surface the error to the user; leave the branch in place for inspection; continue to the next category without blocking.
- **PR creation fails due to network/auth mid-run** → record the branch as local-only in iteration-N.md; continue.
- **Template file missing under `${CLAUDE_PLUGIN_ROOT}/skills/code-improver/templates/`** → abort with "Reinstall the harness plugin — template <name> is missing." Do not attempt to synthesize a substitute.
- **State file corrupted (YAML parse failure)** → offer to run `/improve --init --refresh`. If the Metrics History table is still parseable, preserve it into the new state; otherwise warn the user that it will reset.
- **Web research exhausted / WebFetch failures during `--init`** → continue with whatever sources succeeded. If zero sources for a category succeeded, emit the template with a `<!-- RESEARCH-UNAVAILABLE -->` marker rather than leaving placeholders.

## Self-Reference Guard

Never audit, never modify, and never PR-create files under any of:

- `harness/skills/code-improver/**` (this skill's own source)
- `docs/code-improver/**` (reference outputs)
- `docs/code-improvement/**` (iteration outputs)

These paths are **hardcoded exclusions** in the codebase-auditor (Step 1 auto-exclude list) and the improvement-applier (Step 2 safety filter), and are enforced one more time in the pr-creator (Step 6 pre-push grep). They are also appended to `.code-improver-ignore` automatically by `--init`. A self-reference violation anywhere must surface loudly, not be silently corrected.

## Feedback Guard (adopted from harness-orchestrator)

If the user provides corrective feedback after an iteration, DO NOT immediately implement it. Verify first:

1. **VERIFY** — Is the feedback consistent with this iteration's audit findings? Grep the iteration report for the issue the user is referencing.
2. **EVALUATE** — Does the feedback contradict `priority-matrix.md` safety rules? (E.g., "auto-fix this SRP violation" when SRP is Priority 3 suggestion-only.)
3. **PUSH BACK if needed** — If the feedback is technically wrong or contradicts the design ("code-improver should auto-fix SOLID violations"), explain the reasoning instead of silently complying.

This is the receiving-code-review protocol: performative agreement is forbidden. "You're absolutely right!" followed by an unsafe auto-fix is the worst possible response. Verify, then act.

## Model Selection Guide

Each subagent has its model pinned in its own frontmatter. The rationale:

- **`codebase-auditor`** — `opus`. Reasoning-heavy: pattern recognition across 9 categories, cognitive-complexity computation, priority assignment, fixture-convention disambiguation. Determinism and precision matter.
- **`improvement-applier`** — `sonnet`. Pattern-matching execution: apply a known fix pattern, run tests, bisect. The thinking has already been done by the auditor.
- **`pr-creator`** — `sonnet`. Mechanical orchestration: parse convention, craft message, run git + gh. Minimal judgment.

The orchestrator itself (this SKILL.md) runs at whatever model Claude Code invokes it with; the heavy work is in the subagents.

## Dependencies

- **`git`** — required. Without git, the skill aborts at Phase 0.
- **`gh` CLI** — optional. Without it, `full_mode = false` and PR creation is skipped; branches + commits are still produced for manual push.
- **Project-specific test/lint/typecheck commands** — optional. Each one that is `"unavailable"` is skipped; the applier downgrades `status: success → partial` if all three are unavailable (nothing was actually verified).
- **`WebFetch` network access** — used only during `--init` research. Offline `--init` emits partial references marked `<!-- RESEARCH-UNAVAILABLE -->`.

## File Outputs

Under the audited project's root:

- `docs/code-improver/references/<5 files>.md` — emitted by `--init` and `--init --refresh`
- `docs/code-improver/code-improver-state.md` — emitted by `--init`, updated across every phase transition
- `docs/code-improvement/YYYY-MM-DD/audit-iter-N.md` — emitted by every AUDIT
- `docs/code-improvement/YYYY-MM-DD/iteration-N.md` — emitted by every full flow (`/improve`, `/improve --audit`, `/improve --apply`, `/improve --category`, `/improve --resume`)
- `docs/code-improvement/YYYY-MM-DD/verify-audit-iter-N.md` — emitted by `/improve --verify`
- `docs/code-improvement/YYYY-MM-DD/summary.md` — emitted by Phase 4 on plateau-Halt
- `.code-improver-ignore` — emitted by `--init`; preserved on `--refresh`

Under the plugin (read-only from the skill's perspective):

- `skills/code-improver/references/*.md` — the 5 internal references
- `skills/code-improver/templates/*.md` — the iteration / state / audit-report / ignore-file templates
- `skills/code-improver/templates/project-references/*.md` — the 5 project-reference templates
- `agents/codebase-auditor.md`, `agents/improvement-applier.md`, `agents/pr-creator.md` — the 3 subagent definitions
