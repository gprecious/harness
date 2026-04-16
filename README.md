# Universal Feature Harness

A TDD Generator-Evaluator harness plugin for Claude Code that automates the full feature development lifecycle. It drives a structured pipeline from planning through integration, using contracts and tests as the source of truth to ensure every feature is built correctly, reviewed thoroughly, and integrated safely.

## Installation

```bash
claude plugin install harness
```

## Usage

```bash
# Initialize harness for a project (profiles tech stack, design system, conventions)
/feature --init

# Run feature development pipeline
/feature "description"

# Resume interrupted feature run
/feature --resume
```

## Pipeline Overview

- **Phase 0** — Plan
- **Phase 1** — Contract
- **Phase 2** — Test
- **Phase 3** — Build
- **Phase 4** — Evaluate
- **Phase 5** — Integrate
- **Phase 6** — Learn

## `/improve` — Codebase Improvement (v0.3.0+)

Independent from `/feature`. Use `/improve` to iteratively improve an existing codebase through a 4-phase audit-prioritize-apply-verify workflow. Auto-fixes safe Priority 1-2 issues (dead code, magic literals, cognitive complexity reduction) into category-split PRs; reports Priority 3-5 structural/design suggestions for manual review.

### Commands

- `/improve --init` — First-time setup. Detects environment, runs web research, generates 5 project-specific reference docs
- `/improve` — Full workflow: audit → prioritize → apply fixes → verify
- `/improve --audit` — Audit only, no fixes
- `/improve --apply` — Apply last audit's Priority 1-2 fixes as category-split PRs
- `/improve --category <name>` — Restrict to one category (e.g. `dead-code`)
- `/improve --verify` — Re-audit to check progress against previous iteration; detects plateau
- `/improve --resume` — Recover from interrupted iteration

### Outputs

- `docs/code-improver/references/` — 5 project-specific reference docs (refreshed monthly)
- `docs/code-improver/code-improver-state.md` — Persistent state
- `docs/code-improvement/YYYY-MM-DD/iteration-N.md` — Per-iteration reports with auto-fixes and suggestions
- `docs/code-improvement/YYYY-MM-DD/summary.md` — Cumulative report (generated on plateau)
- `.code-improver-ignore` — Project-root glob rules (similar syntax to gitignore)

### Design & Plan

- Design: `docs/plans/2026-04-16-code-improver-design.md` (parent repo)
- Implementation plan: `docs/plans/2026-04-16-code-improver-impl.md` (parent repo)

## Required Plugins

- feature-dev
- code-review
- pr-review-toolkit
- security-guidance
- superpowers
