---
type: audit-report
iteration: {{N}}
generated_at: {{ISO_8601_TIMESTAMP}}
auditor_version: {{semver of agent}}
---

# Audit Report — Iteration {{N}}

## Scope

- Project root: {{path}}
- Ignore rules applied: {{count}} patterns from `.code-improver-ignore`
- Categories checked: [{{comma-separated}}]
- Files scanned: {{count}}
- Files excluded: {{count}} (ignore + safety)

## Metrics Snapshot

| Metric | Value |
|---|---|
| Avg cognitive complexity (functions > 0) | {{value}} |
| Max cognitive complexity | {{value}} ({{file::function}}) |
| Dead code lines (estimated) | {{value}} |
| Unused imports | {{value}} |
| Test coverage | {{percent | "unavailable"}} |
| Files > 300 lines | {{count}} |
| SOLID violations | {{value}} |

## Issues by Category

### {{Category name}} ({{N}} issues)

#### Priority {{1 | 2 | 3 | 4 | 5}}

- **{{file path}}:{{line-range}}** — {{one-line description}}
  - Pattern: {{e.g. unused_import | cognitive_complexity_exceeded | srp_violation}}
  - Suggested fix: {{action}}
  - Risk if auto-fixed: {{low | medium | high}} ({{rationale}})

<!-- Repeat per issue. Group by priority within each category. -->

## Category Totals

| Category | P1 | P2 | P3 | P4 | P5 | Total |
|---|---|---|---|---|---|---|
| structural-health | 0 | 0 | 0 | 0 | 0 | 0 |
| clarity | 0 | 0 | 0 | 0 | 0 | 0 |
| solid | 0 | 0 | 0 | 0 | 0 | 0 |
| code-smells | 0 | 0 | 0 | 0 | 0 | 0 |
| dead-code | 0 | 0 | 0 | 0 | 0 | 0 |
| error-handling | 0 | 0 | 0 | 0 | 0 | 0 |
| testing | 0 | 0 | 0 | 0 | 0 | 0 |
| performance | 0 | 0 | 0 | 0 | 0 | 0 |
| documentation | 0 | 0 | 0 | 0 | 0 | 0 |
| **Total** | 0 | 0 | 0 | 0 | 0 | 0 |

## Self-Reference Guard

Confirmed: 0 issues reported inside `harness/skills/code-improver/**` or `docs/code-improver/**` (auditor must auto-exclude these paths per priority-matrix.md).
