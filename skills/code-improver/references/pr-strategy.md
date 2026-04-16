---
name: pr-strategy
description: PR creation rules — branch naming, commit style, body format, splitting.
---

# PR Strategy

## Branch Naming

`code-improver/iter-<N>/<category>` (e.g. `code-improver/iter-3/dead-code`)

Split PRs (see below) append `-part-<k>` suffix: `code-improver/iter-3/dead-code-part-1`.

## Commit Message Detection

1. Run `git log -50 --format=%s` on the project
2. Detect convention:
   - Conventional Commits (`type(scope): subject`) — most common
   - Angular style (`type: subject` without scope)
   - Custom prefix schemes (e.g., `[TICKET-123] subject`)
   - Plain imperative sentences
3. If detected style matches a known template, generate commits in that style.
4. Fallback template: `refactor(code-improver): <category> - <summary>`

## PR Body Template

```
## Category: <category>
## Iteration: <N>

### Changes
- <list of specific fixes>

### Metrics (Before → After)
| Metric | Before | After | Δ |
|---|---|---|---|
| ... | ... | ... | ... |

### Verification
- Tests: ✅/❌
- Lint: ✅/❌
- Typecheck: ✅/❌

### Related
- Iteration report: `docs/code-improvement/YYYY-MM-DD/iteration-<N>.md`
```

## Splitting Rules

- `> 20 files` OR `> 500 lines changed` → split
- Split key: **top-level directory** within the category (e.g., `src/auth/` vs `src/api/`)
- Title: `<base title> (1/N)`, `(2/N)`, …
- Each part must independently pass tests/lint/typecheck before its own PR is opened

## gh CLI Fallback

If `gh` is unavailable or unauthenticated:
1. Still create the branch and commits locally
2. Record the branch name in iteration-N.md's APPLY section as "PR pending (local-only mode)"
3. Suggest the user run `gh pr create` manually

## Self-Reference Guard

Never open a PR that modifies files inside `harness/skills/code-improver/**`. If the applier queue contains such a file, fail loudly — this is a priority-matrix violation.
