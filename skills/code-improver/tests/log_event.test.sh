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

echo "ALL TESTS PASSED"
