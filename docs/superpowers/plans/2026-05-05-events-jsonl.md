# events.jsonl for `/improve` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an append-only `events.jsonl` log to `/improve` (code-improver skill), written via a single helper script (`scripts/log_event.sh`), so plateau detection / wisdom-extractor / `--resume` derive structured timeline facts from one file instead of parsing markdown.

**Architecture:** Additive — new helper script + new file per run; existing `code-improver-state.md` and `iteration-N.md` untouched. SKILL.md gains ~13 one-line `bash log_event.sh ...` calls at phase boundaries. `plateau-detection.md` reads events.jsonl with markdown fallback.

**Tech Stack:** bash, `jq` (1.6+, preinstalled), POSIX append (`>>`). No new runtime deps. Tests are bash scripts run manually (mirrors existing `tests/verification-log.md` convention — no CI).

**Spec:** `docs/superpowers/specs/2026-05-05-events-jsonl-design.md`

**Working branch:** `feature/events-jsonl` (already created at commit `90447fd` containing the spec).

---

## File Structure

**New:**
- `skills/code-improver/scripts/log_event.sh` — single writer, ~50 lines
- `skills/code-improver/tests/log_event.test.sh` — 4 unit cases

**Modified:**
- `skills/code-improver/SKILL.md` — ~13 `log_event.sh` call sites at phase boundaries
- `skills/code-improver/references/plateau-detection.md` — events.jsonl-first algorithm + fallback
- `skills/code-improver/templates/code-improver-state.md` — `events_log: events.jsonl` in frontmatter
- `CHANGELOG.md` — 0.4.0 entry
- `README.md` — events.jsonl one-liner
- `.claude-plugin/plugin.json` — version bump 0.3.0 → 0.4.0
- `skills/code-improver/tests/verification-log.md` — append v0.4.0 dry-run notes

---

## Task 1: Scaffold directories and empty `log_event.sh`

**Files:**
- Create: `skills/code-improver/scripts/log_event.sh`
- Create: `skills/code-improver/tests/log_event.test.sh` (empty)

- [ ] **Step 1: Create scripts/ directory and stub script**

```bash
mkdir -p skills/code-improver/scripts
cat > skills/code-improver/scripts/log_event.sh <<'EOF'
#!/usr/bin/env bash
# Append-only event logger for /improve.
# Usage: log_event.sh <event_type> [key=value ...]
# Writes a single JSON line to docs/code-improvement/<date>/events.jsonl.
set -euo pipefail
echo "log_event.sh: not implemented" >&2
exit 1
EOF
chmod +x skills/code-improver/scripts/log_event.sh
```

- [ ] **Step 2: Create empty test file**

```bash
cat > skills/code-improver/tests/log_event.test.sh <<'EOF'
#!/usr/bin/env bash
# Unit tests for log_event.sh. Run from repo root: bash skills/code-improver/tests/log_event.test.sh
set -euo pipefail
echo "no tests yet"
EOF
chmod +x skills/code-improver/tests/log_event.test.sh
```

- [ ] **Step 3: Commit scaffold**

```bash
git add skills/code-improver/scripts/log_event.sh skills/code-improver/tests/log_event.test.sh
git commit -m "chore(code-improver): scaffold log_event.sh + test runner"
```

---

## Task 2: TDD Red — Test 1 (simple event writes valid JSON)

**Files:**
- Modify: `skills/code-improver/tests/log_event.test.sh` (replace stub)

- [ ] **Step 1: Write the failing test**

Replace the entire contents of `skills/code-improver/tests/log_event.test.sh` with:

```bash
#!/usr/bin/env bash
# Unit tests for log_event.sh. Run from repo root:
#   bash skills/code-improver/tests/log_event.test.sh
# Each test sets up a temp project root, runs log_event.sh, asserts output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/code-improver/scripts/log_event.sh"

setup() {
  TMP=$(mktemp -d)
  mkdir -p "$TMP/docs/code-improvement/2026-05-05"
  : > "$TMP/docs/code-improvement/2026-05-05/code-improver-state.md"
  cd "$TMP"
}
teardown() { cd "$REPO_ROOT"; rm -rf "$TMP"; }
fail() { echo "FAIL: $*" >&2; teardown; exit 1; }
ok()   { echo "ok: $*"; }

# --- Test 1: simple event writes one valid JSON line with ts + type ---
test_simple_event() {
  setup
  bash "$SCRIPT" phase_start iteration=1 phase=AUDIT
  EVENTS="$TMP/docs/code-improvement/2026-05-05/events.jsonl"
  [ -f "$EVENTS" ] || fail "events.jsonl not created"
  LINES=$(wc -l < "$EVENTS")
  [ "$LINES" -eq 1 ] || fail "expected 1 line, got $LINES"
  jq -e . "$EVENTS" >/dev/null || fail "line is not valid JSON"
  TYPE=$(jq -r .type "$EVENTS")
  [ "$TYPE" = "phase_start" ] || fail "type=$TYPE, want phase_start"
  ITER=$(jq -r .iteration "$EVENTS")
  [ "$ITER" = "1" ] || fail "iteration=$ITER, want 1"
  PHASE=$(jq -r .phase "$EVENTS")
  [ "$PHASE" = "AUDIT" ] || fail "phase=$PHASE, want AUDIT"
  TS=$(jq -r .ts "$EVENTS")
  echo "$TS" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
    || fail "ts=$TS not ISO8601 UTC"
  ok "test_simple_event"
  teardown
}

test_simple_event

echo "ALL TESTS PASSED"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash skills/code-improver/tests/log_event.test.sh
```

Expected: exit non-zero with `log_event.sh: not implemented` on stderr (or test failure if the stub somehow writes a file).

- [ ] **Step 3: Commit failing test**

```bash
git add skills/code-improver/tests/log_event.test.sh
git commit -m "test(log_event): red — simple event writes valid JSON"
```

---

## Task 3: TDD Green — Implement minimal `log_event.sh`

**Files:**
- Modify: `skills/code-improver/scripts/log_event.sh`

- [ ] **Step 1: Write minimal implementation**

Replace the entire contents of `skills/code-improver/scripts/log_event.sh` with:

```bash
#!/usr/bin/env bash
# Append-only event logger for /improve.
# Usage: log_event.sh <event_type> [key=value ...]
#   - First positional arg becomes the "type" field.
#   - Remaining key=value pairs are merged into the JSON object.
#   - "ts" is auto-injected (ISO 8601 UTC).
# Writes a single JSON line to docs/code-improvement/<date>/events.jsonl,
# where <date> is the run dir of the most recent code-improver-state.md.
# Failures (no run dir, jq missing) exit 1 with a stderr message; the caller
# is expected to ignore the failure (event-log loss is non-critical).
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "log_event.sh: usage: log_event.sh <event_type> [key=value ...]" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "log_event.sh: jq not installed; skipping event log" >&2
  exit 1
fi

type_arg="$1"; shift

# Discover run dir = parent of the most recent code-improver-state.md.
state_file=$(find docs/code-improvement -maxdepth 2 -name code-improver-state.md 2>/dev/null | sort | tail -1)
if [ -z "$state_file" ]; then
  echo "log_event.sh: no run dir (no docs/code-improvement/*/code-improver-state.md)" >&2
  exit 1
fi
run_dir=$(dirname "$state_file")

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build the JSON object: start with {ts, type}, then merge each key=value.
jq_args=(--arg ts "$ts" --arg type "$type_arg")
filter='{ts:$ts, type:$type}'
for kv in "$@"; do
  k="${kv%%=*}"
  v="${kv#*=}"
  # Sanitize key for jq variable name (only alphanum + underscore).
  safe_k=$(printf '%s' "$k" | tr -c 'A-Za-z0-9_' '_')
  jq_args+=(--arg "v_$safe_k" "$v")
  # Use setpath so dotted keys nest correctly later (Task 5 will extend this).
  filter="$filter | .[\"$k\"] = \$v_$safe_k"
done

jq -cn "${jq_args[@]}" "$filter" >> "$run_dir/events.jsonl"
```

- [ ] **Step 2: Run test to verify it passes**

```bash
bash skills/code-improver/tests/log_event.test.sh
```

Expected: `ok: test_simple_event` then `ALL TESTS PASSED`.

- [ ] **Step 3: Commit**

```bash
git add skills/code-improver/scripts/log_event.sh
git commit -m "feat(log_event): green — minimal implementation passes simple event test"
```

---

## Task 4: TDD Red — Test 2 (dotted-key nesting)

**Files:**
- Modify: `skills/code-improver/tests/log_event.test.sh`

- [ ] **Step 1: Add test 2 before the `echo "ALL TESTS PASSED"` line**

Insert (just above `echo "ALL TESTS PASSED"`):

```bash
# --- Test 2: dotted keys nest into objects ---
test_dotted_key_nesting() {
  setup
  bash "$SCRIPT" category_applied iteration=2 verification.tests=true verification.lint=false
  EVENTS="$TMP/docs/code-improvement/2026-05-05/events.jsonl"
  jq -e . "$EVENTS" >/dev/null || fail "line is not valid JSON"
  T=$(jq -r .verification.tests "$EVENTS")
  L=$(jq -r .verification.lint "$EVENTS")
  [ "$T" = "true" ] || fail "verification.tests=$T, want true"
  [ "$L" = "false" ] || fail "verification.lint=$L, want false"
  ok "test_dotted_key_nesting"
  teardown
}

test_dotted_key_nesting
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash skills/code-improver/tests/log_event.test.sh
```

Expected: `test_simple_event` passes, `test_dotted_key_nesting` fails — likely with `verification.tests` becoming a flat string key `"verification.tests": "true"` instead of nested.

- [ ] **Step 3: Commit failing test**

```bash
git add skills/code-improver/tests/log_event.test.sh
git commit -m "test(log_event): red — dotted keys must nest into objects"
```

---

## Task 5: TDD Green — Add nesting + value coercion to `log_event.sh`

**Files:**
- Modify: `skills/code-improver/scripts/log_event.sh`

- [ ] **Step 1: Replace the for-loop and final jq invocation**

In `skills/code-improver/scripts/log_event.sh`, replace the section starting from `# Build the JSON object: ...` to the end with:

```bash
# Build the JSON object: start with {ts, type}, then merge each key=value.
# - Dotted keys (a.b.c) become nested objects via setpath.
# - Values that look like booleans, integers, or floats are coerced to JSON
#   primitives via --argjson; everything else is a string via --arg.
jq_args=(--arg ts "$ts" --arg type "$type_arg")
filter='{ts:$ts, type:$type}'
i=0
for kv in "$@"; do
  k="${kv%%=*}"
  v="${kv#*=}"
  i=$((i+1))
  var="v$i"
  # Coerce value type for the JSON primitive case.
  case "$v" in
    true|false)                            jq_args+=(--argjson "$var" "$v") ;;
    -[0-9]*|[0-9]*)
      if printf '%s' "$v" | grep -qE '^-?[0-9]+(\.[0-9]+)?$'; then
        jq_args+=(--argjson "$var" "$v")
      else
        jq_args+=(--arg "$var" "$v")
      fi ;;
    *)                                     jq_args+=(--arg "$var" "$v") ;;
  esac
  # Build a setpath() expression so dotted keys nest:
  #   "verification.tests" -> setpath(["verification","tests"]; $v1)
  path_json=$(printf '%s' "$k" | jq -Rcn 'inputs | split(".")' <<< "$k")
  filter="$filter | setpath($path_json; \$$var)"
done

jq -cn "${jq_args[@]}" "$filter" >> "$run_dir/events.jsonl"
```

- [ ] **Step 2: Run test to verify both pass**

```bash
bash skills/code-improver/tests/log_event.test.sh
```

Expected: `ok: test_simple_event`, `ok: test_dotted_key_nesting`, `ALL TESTS PASSED`.

- [ ] **Step 3: Commit**

```bash
git add skills/code-improver/scripts/log_event.sh
git commit -m "feat(log_event): green — dotted keys nest + values coerce to JSON primitives"
```

---

## Task 6: TDD Red — Test 3 (value type coercion)

**Files:**
- Modify: `skills/code-improver/tests/log_event.test.sh`

- [ ] **Step 1: Add test 3 before `echo "ALL TESTS PASSED"`**

```bash
# --- Test 3: value type coercion (bool/int/float/string) ---
test_value_coercion() {
  setup
  bash "$SCRIPT" audit_completed iteration=3 total_issues=42 ratio=0.36 active=true name=hello
  EVENTS="$TMP/docs/code-improvement/2026-05-05/events.jsonl"
  jq -e . "$EVENTS" >/dev/null || fail "line is not valid JSON"
  # Use jq's `type` filter to assert each value is the right JSON type.
  [ "$(jq -r '.iteration | type' "$EVENTS")" = "number" ] || fail "iteration not number"
  [ "$(jq -r '.total_issues | type' "$EVENTS")" = "number" ] || fail "total_issues not number"
  [ "$(jq -r '.ratio | type' "$EVENTS")" = "number" ] || fail "ratio not number"
  [ "$(jq -r '.active | type' "$EVENTS")" = "boolean" ] || fail "active not boolean"
  [ "$(jq -r '.name | type' "$EVENTS")" = "string" ] || fail "name not string"
  [ "$(jq -r '.ratio' "$EVENTS")" = "0.36" ] || fail "ratio value"
  ok "test_value_coercion"
  teardown
}

test_value_coercion
```

- [ ] **Step 2: Run tests**

```bash
bash skills/code-improver/tests/log_event.test.sh
```

Expected: all three pass (Task 5 already implemented coercion). If a numeric assertion fails (jq printing `0.36` as `0.359999…`), use a tolerance check or `printf "%.2f"` before compare.

- [ ] **Step 3: Commit**

```bash
git add skills/code-improver/tests/log_event.test.sh
git commit -m "test(log_event): cover value type coercion (bool/int/float/string)"
```

---

## Task 7: TDD Red — Test 4 (append-only durability)

**Files:**
- Modify: `skills/code-improver/tests/log_event.test.sh`

- [ ] **Step 1: Add test 4 before `echo "ALL TESTS PASSED"`**

```bash
# --- Test 4: append-only — second call adds a line, first line unchanged ---
test_append_only() {
  setup
  bash "$SCRIPT" phase_start iteration=1 phase=AUDIT
  EVENTS="$TMP/docs/code-improvement/2026-05-05/events.jsonl"
  FIRST_LINE=$(head -1 "$EVENTS")
  bash "$SCRIPT" phase_end iteration=1 phase=AUDIT status=ok
  LINES=$(wc -l < "$EVENTS")
  [ "$LINES" -eq 2 ] || fail "expected 2 lines, got $LINES"
  [ "$(head -1 "$EVENTS")" = "$FIRST_LINE" ] || fail "first line mutated by second call"
  jq -e . "$EVENTS" >/dev/null || fail "second line invalid JSON (or jq treats file as one obj)"
  # Verify both are independently parseable as a JSON array via jq -s
  COUNT=$(jq -s 'length' "$EVENTS")
  [ "$COUNT" = "2" ] || fail "jq -s reports $COUNT objects, want 2"
  ok "test_append_only"
  teardown
}

test_append_only
```

- [ ] **Step 2: Run tests**

```bash
bash skills/code-improver/tests/log_event.test.sh
```

Expected: all four pass — append behavior is already correct (Task 3's `>>` redirect).

- [ ] **Step 3: Commit**

```bash
git add skills/code-improver/tests/log_event.test.sh
git commit -m "test(log_event): cover append-only durability across two calls"
```

---

## Task 8: Update `code-improver-state.md` template

**Files:**
- Modify: `skills/code-improver/templates/code-improver-state.md` (frontmatter)

- [ ] **Step 1: Add `events_log` line to template frontmatter**

In `skills/code-improver/templates/code-improver-state.md`, replace the frontmatter block (lines 1-8 of the existing file):

Change:
```yaml
---
version: 1
initialized_at: {{ISO_8601_TIMESTAMP}}
last_refreshed_at: {{ISO_8601_TIMESTAMP}}
current_iteration: {{N}}
current_phase: {{idle | PREFLIGHT | AUDIT | PRIORITIZE | APPLY | VERIFY}}
harness_version: {{semver}}
---
```

To:
```yaml
---
version: 1
initialized_at: {{ISO_8601_TIMESTAMP}}
last_refreshed_at: {{ISO_8601_TIMESTAMP}}
current_iteration: {{N}}
current_phase: {{idle | PREFLIGHT | AUDIT | PRIORITIZE | APPLY | VERIFY}}
harness_version: {{semver}}
events_log: events.jsonl
---
```

- [ ] **Step 2: Commit**

```bash
git add skills/code-improver/templates/code-improver-state.md
git commit -m "feat(code-improver): add events_log pointer to state template"
```

---

## Task 9: Update `plateau-detection.md` to read events.jsonl with markdown fallback

**Files:**
- Modify: `skills/code-improver/references/plateau-detection.md`

- [ ] **Step 1: Replace Algorithm + Example sections**

Open `skills/code-improver/references/plateau-detection.md`. Replace the entire `## Algorithm` and `## Example` sections (currently lines 12-25) with:

```markdown
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
```

- [ ] **Step 2: Verify the rest of the file (Action on Plateau, State Fields Updated) is unchanged**

```bash
grep -A1 '^## Action on Plateau' skills/code-improver/references/plateau-detection.md
grep -A1 '^## State Fields Updated' skills/code-improver/references/plateau-detection.md
```

Expected: both sections still present, unchanged from the original.

- [ ] **Step 3: Commit**

```bash
git add skills/code-improver/references/plateau-detection.md
git commit -m "feat(plateau-detection): read events.jsonl first, markdown fallback"
```

---

## Task 10: Wire `log_event.sh` calls into `SKILL.md`

This task adds ~13 single-line `bash $SCRIPT log_event.sh ...` instructions into the SKILL.md prose. Each insertion is a single `Edit` operation; group them into one task because they form one logical change.

**Files:**
- Modify: `skills/code-improver/SKILL.md`

The constant `$LOG` will be defined inline as `$LOG = "${CLAUDE_PLUGIN_ROOT}/skills/code-improver/scripts/log_event.sh"` in a new "Event Logging" section near the top.

- [ ] **Step 1: Add an "Event Logging" reference section after the Overview**

Find the line `## When to Use` in `skills/code-improver/SKILL.md` and insert this block immediately *before* it:

```markdown
## Event Logging

Every phase boundary and significant result is logged to `docs/code-improvement/<date>/events.jsonl` via the helper script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/code-improver/scripts/log_event.sh" <event_type> [key=value ...]
```

The skill below uses the alias `$LOG` for that path. The helper auto-discovers the run dir from `docs/code-improvement/*/code-improver-state.md`, auto-injects `ts`, and treats the first positional arg as `type`. Failures are non-blocking (event-log loss is not critical).

Event catalog (9 types) is documented in `docs/superpowers/specs/2026-05-05-events-jsonl-design.md`.

```

- [ ] **Step 2: Insert `run_started` at top of Phase 0**

Find `## Phase 0: PREFLIGHT` and replace it through the next line with:

```markdown
## Phase 0: PREFLIGHT

Runs before every command (except the first-ever `--init` invocation, which has no state file yet).

Immediately at command entry — once the state file exists (skip on first `--init`) — log:

    bash $LOG run_started mode=<MODE> harness_version=<VER>

where `<MODE>` is the parsed command mode (`full`, `audit`, `apply`, `verify`, `init`, `init-refresh`, `resume`, or `category`) and `<VER>` comes from `.claude-plugin/plugin.json`'s `version` field.
```

- [ ] **Step 3: Insert `phase_start` / `audit_completed` / `phase_end` for AUDIT**

Find `### Step 1.1: Resolve iteration number` and replace its body's last sentence — currently `Set current_phase = AUDIT and persist.` — with:

```markdown
Set `current_phase = AUDIT` and persist. Then log:

    bash $LOG phase_start iteration=<N> phase=AUDIT
```

Find `### Step 1.3: Dispatch \`codebase-auditor\`` and at the very end of that step (just before the next `###` heading), append:

```markdown

After the agent returns successfully, log:

    bash $LOG audit_completed iteration=<N> total_issues=<T> by_priority.P1=<n1> by_priority.P2=<n2> by_priority.P3=<n3> by_priority.P4=<n4> by_priority.P5=<n5>
```

Find `### Step 1.4: Stitch audit into \`iteration-N.md\`` and at the very end of its body (after the `Update state: ...` line), append:

```markdown

Log phase boundary:

    bash $LOG phase_end iteration=<N> phase=AUDIT status=ok
```

- [ ] **Step 4: Insert `phase_start` / `phase_end` for PRIORITIZE**

Find `## Phase 2: PRIORITIZE` and immediately after the heading insert:

```markdown

At entry log:

    bash $LOG phase_start iteration=<N> phase=PRIORITIZE
```

Find `### Step 2.3: Present the plan to the user` and at the very end of its body, append:

```markdown

Log phase boundary:

    bash $LOG phase_end iteration=<N> phase=PRIORITIZE status=ok
```

- [ ] **Step 5: Insert `phase_start` / `category_applied` / `phase_end` for APPLY**

Find `## Phase 3: APPLY` and replace `Iterate over approved categories in **alphabetical order** for determinism. For each category:` with:

```markdown
At entry log:

    bash $LOG phase_start iteration=<N> phase=APPLY

Iterate over approved categories in **alphabetical order** for determinism. For each category:
```

Find `### Step 3.3: Update \`iteration-N.md\`` and at the very end of its body, append:

```markdown

Log per-category result:

    bash $LOG category_applied iteration=<N> category=<C> pr_url=<URL_OR_null> files_changed=<F> lines_added=<A> lines_removed=<R> verification.tests=<true|false> verification.lint=<true|false> verification.typecheck=<true|false>

(Use the literal string `null` for `pr_url` when running in `local-only` mode.)
```

Find `### Step 3.4: Update state` and at the very end of its body, append:

```markdown

Log phase boundary:

    bash $LOG phase_end iteration=<N> phase=APPLY status=ok

If no VERIFY will run after APPLY (i.e., `current_phase` was set to `idle`), also log:

    bash $LOG iteration_completed iteration=<N> status=completed
```

- [ ] **Step 6: Insert `phase_start` / `verify_completed` / `plateau_check` / `phase_end` / `iteration_completed` / `run_halted` for VERIFY**

Find `## Phase 4: VERIFY (Optional)` and immediately after the introductory paragraph (`Triggered by ...`), insert:

```markdown

At entry log:

    bash $LOG phase_start iteration=<N> phase=VERIFY
```

Find `### Step 4.2: Compute deltas` and at the very end of its body (after the Plateau Check section is written to iteration-N.md), append:

```markdown

Log verify result and plateau check:

    bash $LOG verify_completed iteration=<N> metrics_after.cognitive_complexity=<v> metrics_after.dead_code=<v> metrics_after.unused_imports=<v> metrics_after.test_coverage=<v> metrics_after.files_over_300_lines=<v> metrics_after.solid_violations=<v>

    bash $LOG plateau_check iteration=<N> resolved=<X> new=<Y> ratio=<R> consecutive=<K>
```

Find `### Step 4.3: Apply plateau detection` and at the very end of its body, append:

```markdown

Log phase boundary:

    bash $LOG phase_end iteration=<N> phase=VERIFY status=ok
```

Find `### Step 4.4: On plateau, present the 4-option menu` and at the very end of its body (after the `Set iteration-N.md's status: plateau` sentence), append:

```markdown

If the user chose Halt (option 1, default), log:

    bash $LOG run_halted reason=plateau final_iteration=<N>

If the user chose Continue (option 2), log:

    bash $LOG iteration_completed iteration=<N> status=plateau

(For Refresh/Reduce-scope choices, no event is emitted here — the next `/improve` invocation logs `run_started` afresh.)
```

- [ ] **Step 7: Verify SKILL.md still parses as well-formed markdown and the new section count is right**

```bash
grep -c '^bash \$LOG' skills/code-improver/SKILL.md
```

Expected: `13` (matches the per-step counts: 1 + 3 + 2 + 3 + 4 = 13 call sites).

```bash
head -100 skills/code-improver/SKILL.md | grep -A2 '## Event Logging'
```

Expected: the new section is present near the top.

- [ ] **Step 8: Commit**

```bash
git add skills/code-improver/SKILL.md
git commit -m "feat(code-improver): wire log_event.sh calls at all phase boundaries"
```

---

## Task 11: Bump version + update CHANGELOG / README

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `CHANGELOG.md`
- Modify: `README.md`

- [ ] **Step 1: Bump plugin version to 0.4.0**

In `.claude-plugin/plugin.json`, change the `version` field from `"0.3.0"` to `"0.4.0"`.

```bash
# Verify result
grep '"version"' .claude-plugin/plugin.json
```

Expected: `"version": "0.4.0",`

- [ ] **Step 2: Add 0.4.0 entry to CHANGELOG.md**

Open `CHANGELOG.md`, find the top of the file (after any header), and insert this entry above the most recent prior entry:

```markdown
## 0.4.0 — 2026-05-05

### Added
- `events.jsonl`: append-only structured event log under `docs/code-improvement/<date>/events.jsonl` for every `/improve` run. 9 event types (`run_started`, `phase_start`, `phase_end`, `audit_completed`, `category_applied`, `verify_completed`, `plateau_check`, `iteration_completed`, `run_halted`).
- `skills/code-improver/scripts/log_event.sh`: single-writer helper used by SKILL.md at every phase boundary.
- `skills/code-improver/tests/log_event.test.sh`: 4 unit tests (simple event, dotted-key nesting, value type coercion, append-only durability).

### Changed
- `references/plateau-detection.md` now reads `plateau_check` events from `events.jsonl` first, with markdown parsing as fallback for older runs.
- `templates/code-improver-state.md` frontmatter gains `events_log: events.jsonl` pointer.
```

- [ ] **Step 3: Add events.jsonl mention to README.md**

In `README.md`, find the `/improve` section description (under `## /improve — Codebase Improvement`) and append a sentence:

```markdown
Every run also writes a structured `events.jsonl` log under `docs/code-improvement/<date>/`, used by plateau detection and recoverable from after a crash.
```

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/plugin.json CHANGELOG.md README.md
git commit -m "chore: bump harness version to 0.4.0 + changelog + readme"
```

---

## Task 12: Append v0.4.0 dry-run to verification-log.md

**Files:**
- Modify: `skills/code-improver/tests/verification-log.md`

- [ ] **Step 1: Append a v0.4.0 dry-run section**

At the bottom of `skills/code-improver/tests/verification-log.md`, append:

```markdown
---

## v0.4.0 dry-run — events.jsonl wiring

**Method:** Mentally trace each phase of the SKILL.md against fixture-clean. Confirm every phase boundary emits the documented `bash $LOG ...` instruction, and that the helper script's run-dir discovery finds `docs/code-improvement/<date>/code-improver-state.md`.

**Scope:** SKILL.md changes from Task 10 of `docs/superpowers/plans/2026-05-05-events-jsonl.md`.

### Verified

- 13 `bash $LOG` call sites land at the expected phase transitions (PREFLIGHT entry, AUDIT start/audit_completed/end, PRIORITIZE start/end, APPLY start/category_applied/end, VERIFY start/verify_completed+plateau_check/end, plus iteration_completed and run_halted).
- `Event Logging` reference section explains the `$LOG` alias.

### Smoke test (Task 13)

Run `/improve --audit` against `skills/code-improver/tests/fixtures/fixture-clean` and confirm:

- `events.jsonl` is created in the fixture's `docs/code-improvement/<today>/`.
- File contains at minimum `run_started`, `phase_start(AUDIT)`, `audit_completed`, `phase_end(AUDIT)` (4 lines for an audit-only run).
- Each line is independently valid JSON: `jq -s 'length' events.jsonl` equals the line count.
```

- [ ] **Step 2: Commit**

```bash
git add skills/code-improver/tests/verification-log.md
git commit -m "docs(verification): v0.4.0 events.jsonl dry-run notes"
```

---

## Task 13: Manual integration smoke test

This is a manual-run task — it does not produce a commit unless the smoke test surfaces a defect.

**Files:**
- Read: `skills/code-improver/tests/fixtures/fixture-clean/`

- [ ] **Step 1: Re-install the plugin from the worktree (so /improve picks up the new SKILL.md)**

```bash
# From your home dir or wherever the plugin is referenced
ls /home/taejin/.claude/plugins/cache/harness/harness/  # confirm 0.3.0 is present
```

If the cache is keyed by version, copy the modified files into a fresh `0.4.0` cache dir, OR symlink the worktree, OR commit + push + re-install via the marketplace. Easiest for a smoke test: temporarily edit `0.3.0` in the cache to mirror the worktree (revert after).

- [ ] **Step 2: Run `/improve --audit` against `fixture-clean`**

```bash
cd skills/code-improver/tests/fixtures/fixture-clean
# (in another terminal or session) invoke /improve --audit via Claude Code
```

- [ ] **Step 3: Verify the events.jsonl file**

```bash
cd skills/code-improver/tests/fixtures/fixture-clean
EVENTS=$(find docs/code-improvement -name events.jsonl | head -1)
[ -n "$EVENTS" ] && echo "found: $EVENTS" || { echo "FAIL: no events.jsonl"; exit 1; }
COUNT=$(jq -s 'length' "$EVENTS")
[ "$COUNT" -ge 4 ] && echo "ok: $COUNT events" || { echo "FAIL: only $COUNT events"; exit 1; }
jq -r .type "$EVENTS"  # eyeball the event sequence
```

Expected output (audit-only mode):
```
run_started
phase_start
audit_completed
phase_end
```

- [ ] **Step 4: Document the result in verification-log.md**

If smoke test passes, append a one-line confirmation to the v0.4.0 section of `skills/code-improver/tests/verification-log.md`:

```markdown
- 2026-05-05: smoke test on fixture-clean — passed. events.jsonl produced 4 expected event types.
```

If it fails, capture the failure mode (which step missing? jq error? run-dir not found?) and *do not commit* — instead, fix the underlying defect and rerun.

- [ ] **Step 5: Commit verification-log update (only if smoke test passed)**

```bash
git add skills/code-improver/tests/verification-log.md
git commit -m "docs(verification): smoke test passed on fixture-clean"
```

- [ ] **Step 6: Revert any temporary cache edits made in Step 1**

If the plugin cache was hand-edited for the smoke test, revert it (or wait for a real `/plugin install` after the PR merges).

---

## Task 14: Push branch and open PR

**Files:** none (git operations only).

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feature/events-jsonl
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --title "feat(code-improver): append-only events.jsonl for /improve (v0.4.0)" \
  --body "$(cat <<'EOF'
## Summary
- Add append-only `events.jsonl` log to every `/improve` run, written by a single helper script (`scripts/log_event.sh`)
- 9 event types covering all phase boundaries (run_started → run_halted)
- `plateau-detection.md` now reads events.jsonl first, falls back to markdown parse for older runs

## Spec
`docs/superpowers/specs/2026-05-05-events-jsonl-design.md`

## Plan
`docs/superpowers/plans/2026-05-05-events-jsonl.md`

## Test plan
- [ ] Run `bash skills/code-improver/tests/log_event.test.sh` — all 4 unit tests pass
- [ ] Smoke test on `skills/code-improver/tests/fixtures/fixture-clean` — `/improve --audit` produces events.jsonl with at least 4 events
- [ ] Verify `plateau-detection.md` fallback path still works on a pre-0.4.0 run dir (events.jsonl absent)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review

**1. Spec coverage:** Each spec section maps to tasks:
- §4 Architecture → Tasks 1, 3, 5, 10 (helper + wiring)
- §5 Event Schema → Task 10 (Steps 2-6 emit each of 9 event types)
- §6 Helper script design → Tasks 1, 3, 5
- §7 Reader changes (plateau-detection, SKILL.md, state template) → Tasks 8, 9, 10
- §8 Testing strategy → Tasks 2, 4, 6, 7 (unit) + 13 (integration)
- §9 Backward compat & rollout → Tasks 9 (fallback), 11 (version bump)
- §10 File summary → matches Tasks 1-12 outputs
- §11 Risks (jq missing, multi-run-dir) → handled in Task 3 implementation (jq check + tail -1 picks most recent state.md)

**2. Placeholder scan:** No "TBD"/"TODO"/"implement later" remaining. Every code step has actual code; every command step has an exact command and expected output.

**3. Type / signature consistency:** `log_event.sh` interface (`<event_type> [key=value ...]`) is identical across Tasks 1, 3, 5 and every wiring call in Task 10. Event type names (`run_started`, `phase_start`, etc.) match the spec catalog exactly. `$LOG` alias is defined once (Task 10 Step 1) and used consistently in Steps 2-6.
