---
name: plateau-detection
description: Algorithm for detecting plateau state across iterations.
---

# Plateau Detection

## Inputs
- `docs/code-improver/code-improver-state.md` → `metrics_history` field
- Current iteration's audit result (from iteration-N.md)

## Algorithm

For each consecutive iteration pair (N-1, N):
- `resolved = count(issues present in N-1 but not N)`
- `new = count(issues present in N but not N-1)`
- `ratio = new / max(resolved, 1)`

**Plateau trigger:** `ratio >= 0.80` for **2 consecutive iterations**.

## Example

- Iteration 4: resolved=22, new=20 → ratio 0.91 → plateau candidate
- Iteration 5: resolved=15, new=14 → ratio 0.93 → plateau confirmed (2nd consecutive)

## Action on Plateau

Present this menu. Default action is (1) Halt if the user provides no response within a reasonable orchestration timeout:

```
⚠ Plateau detected (iteration N)
- New issues (X) ≥ 80% of resolved issues (Y)

Options:
  (1) Halt — generate summary.md and stop   [default]
  (2) Continue anyway — proceed to iteration N+1
  (3) Refresh references — run /improve --init --refresh
  (4) Reduce scope — focus on specific category (/improve --category <name>)
```

Do NOT auto-continue past plateau without an explicit user choice other than default-halt.

## State Fields Updated

- `consecutive_plateau_iterations` — incremented when ratio ≥ 0.80, reset to 0 otherwise
- On plateau confirmation (consecutive ≥ 2): write `docs/code-improvement/<date>/summary.md` with cumulative metrics + iteration history + deferred P3-5 items
