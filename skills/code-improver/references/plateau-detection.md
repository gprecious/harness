---
name: plateau-detection
description: Algorithm for detecting plateau state across iterations.
---

# Plateau Detection

## Inputs
- `docs/code-improver/code-improver-state.md` → `metrics_history` field
- Current iteration's audit result (from iteration-N.md)

## Algorithm

**Primary path — read from `events.jsonl`:**

The orchestrator's run dir is `docs/code-improvement/<date>/`. If `events.jsonl` exists there, derive plateau state from the last two `plateau_check` events:

```bash
jq -c 'select(.type == "plateau_check")' \
  docs/code-improvement/<date>/events.jsonl | tail -2
```

Each `plateau_check` event has shape:

```json
{"ts":"...","type":"plateau_check","iteration":N,"resolved":X,"new":Y,"ratio":0.NN,"consecutive":K}
```

**Plateau confirmed:** the most recent two `plateau_check` events both have `ratio >= 0.80`.

**Fallback — markdown parse (older runs without events.jsonl):**

If `events.jsonl` is absent in the run dir, fall back to parsing the `## Plateau Check` section of the most recent `iteration-N.md` and `iteration-(N-1).md`. Look for the `- resolved: X, new: Y, ratio: ...` line and apply the same rule.

For each consecutive iteration pair (N-1, N) under either path:

- `resolved = count(issues present in N-1 but not N)`
- `new = count(issues present in N but not N-1)`
- `ratio = new / max(resolved, 1)`

**Plateau trigger:** `ratio >= 0.80` for **2 consecutive iterations**.

## Example

- Iteration 4: `plateau_check` event ratio 0.91 → plateau candidate
- Iteration 5: `plateau_check` event ratio 0.93 → plateau confirmed (2nd consecutive)

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
