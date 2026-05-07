#!/usr/bin/env bats
# pane-create.bats — integration tests for scripts/pane-create.sh
#
# These tests require a running cmux instance (via `cmux ping`). When cmux is
# not running, every test is skipped — they can run in CI only on machines
# with a live cmux daemon.
#
# Cleanup: each test that creates a pane appends its ref to CREATED_PANES,
# and teardown closes them via `cmux close-surface --surface <ref>`. We close
# by surface ref because (a) cmux 0.62.2 close-surface takes --surface, not
# --pane, and (b) each pane created here has exactly one surface, so closing
# its surface effectively closes the pane.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/pane-create.sh"
  cmux ping >/dev/null 2>&1 || skip "cmux not running"
  CREATED_SURFACES=()
  # Belt-and-suspenders: bats calls teardown() on normal completion, but if
  # the test subprocess receives SIGINT/SIGTERM (Ctrl+C, bats abort) the
  # teardown is skipped and the panes leak into the user's workspace. The
  # trap fires on those signals as well; teardown is idempotent (close-surface
  # is wrapped with `|| true`) so the double-call on normal exit is harmless.
  trap teardown EXIT INT TERM
}

teardown() {
  for sref in "${CREATED_SURFACES[@]:-}"; do
    [ -n "$sref" ] && cmux close-surface --surface "$sref" >/dev/null 2>&1 || true
  done
}

# Helper: invoke pane-create and capture the corresponding surface ref so
# teardown can close it. The surface ref is captured from list-pane-surfaces
# since pane-create only emits the pane ref on stdout.
record_surface_for_pane() {
  local pane_ref="$1"
  local surf
  surf=$(cmux list-pane-surfaces --pane "$pane_ref" 2>/dev/null \
    | grep -oE 'surface:[0-9]+' | head -1)
  [ -n "$surf" ] && CREATED_SURFACES+=("$surf")
}

@test "script file is executable" {
  [ -x "$SCRIPT" ]
}

@test "pane-create produces pane:N ref on stdout" {
  pane=$("$SCRIPT" --direction down)
  record_surface_for_pane "$pane"
  [ -n "$pane" ]
  [[ "$pane" =~ ^pane:[0-9]+$ ]]
}

@test "pane-create created pane appears in list-panes" {
  pane=$("$SCRIPT" --direction down)
  record_surface_for_pane "$pane"
  cmux list-panes | grep -qF "$pane"
}

@test "pane-create accepts --type terminal explicitly" {
  pane=$("$SCRIPT" --direction down --type terminal)
  record_surface_for_pane "$pane"
  [[ "$pane" =~ ^pane:[0-9]+$ ]]
}

@test "pane-create defaults direction to down when omitted" {
  pane=$("$SCRIPT")
  record_surface_for_pane "$pane"
  [[ "$pane" =~ ^pane:[0-9]+$ ]]
}

@test "pane-create rejects unknown flag" {
  run "$SCRIPT" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown"* ]]
}

@test "pane-create --help exits 0 and prints usage" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--direction"* ]]
}
