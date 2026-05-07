#!/usr/bin/env bats
# pane-compact.bats — integration tests for scripts/pane-compact.sh
#
# Strategy: in a real codex TUI session, /compact is a slash command that
# triggers context summarization. We can't reliably detect when it finishes
# from outside (the actual UI completion string is unverified — see
# notes/codex-cli-flags.md). Instead pane-compact.sh sends /compact AND a
# "readiness marker" (`echo $MARKER`) afterwards, then polls scrollback for
# the marker. This decouples readiness detection from any codex-specific UI.
#
# In this test environment the pane is a plain shell, not codex, so /compact
# just produces "command not found" — that's fine. What we verify is that
# the marker echo step is correctly sent and detected.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/pane-compact.sh"
  CREATE="$BATS_TEST_DIRNAME/../../scripts/pane-create.sh"
  cmux ping >/dev/null 2>&1 || skip "cmux not running"
  PANE=$("$CREATE" --direction down)
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/../../scripts/lib/resolve-surface.sh"
  SURFACE=$(resolve_surface "$PANE")
  # Cleanup on abort / Ctrl+C / SIGTERM (bats teardown is skipped on signals).
  trap teardown EXIT INT TERM
}

teardown() {
  if [ -n "${SURFACE:-}" ]; then
    cmux close-surface --surface "$SURFACE" >/dev/null 2>&1 || true
  fi
}

@test "script file is executable" {
  [ -x "$SCRIPT" ]
}

@test "pane-compact: sends /compact and detects readiness marker" {
  marker="COMPACT_READY_$$"
  run "$SCRIPT" --pane "$PANE" --marker "$marker" --timeout 15 --poll 1
  [ "$status" -eq 0 ]
}

@test "pane-compact: --pane required" {
  run "$SCRIPT" --marker "FOO"
  [ "$status" -eq 1 ]
}

@test "pane-compact: rejects unknown flag" {
  run "$SCRIPT" --pane "$PANE" --bogus
  [ "$status" -eq 2 ]
}

@test "pane-compact: --help exits 0 and prints usage" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--pane"* ]]
  [[ "$output" == *"--marker"* ]]
}

@test "pane-compact: timeout test (skipped — real shell pane always echoes)" {
  # A timeout test would require a pane that doesn't echo back the marker.
  # In a real shell pane, `echo $MARKER` always succeeds within poll time,
  # making a deterministic timeout assertion flaky. Skipped intentionally.
  skip "timeout test requires non-echoing pane simulation; flake-prone in real cmux"
}
