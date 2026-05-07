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
  WS_CREATE="$BATS_TEST_DIRNAME/../../scripts/workspace-create.sh"
  WS_CLOSE="$BATS_TEST_DIRNAME/../../scripts/workspace-close.sh"
  cmux ping >/dev/null 2>&1 || skip "cmux not running"
  # Isolated workspace per-test: never split inside the user's active
  # workspace. close-workspace in teardown removes every pane in one shot.
  # If teardown is skipped (SIGKILL of bats subprocess), the workspace leaks
  # but stays out of the user's active view — orphans accumulate in
  # `cmux list-workspaces` and can be GC'd by a separate sweep script.
  WORKSPACE=$("$WS_CREATE" --cwd "$BATS_TMPDIR" --title "bats:pane-create")
  CREATED_SURFACES=()
}

teardown() {
  for sref in "${CREATED_SURFACES[@]:-}"; do
    [ -n "$sref" ] && cmux close-surface --surface "$sref" >/dev/null 2>&1 || true
  done
  if [ -n "${WORKSPACE:-}" ]; then
    "$WS_CLOSE" --workspace "$WORKSPACE" >/dev/null 2>&1 || true
  fi
}

# Helper: invoke pane-create and capture the corresponding surface ref so
# teardown can close it. We must pass --workspace because list-pane-surfaces
# defaults to the focused workspace and our panes are in an isolated one.
# Returns 0 even when nothing matches so [-e] callers don't trip on "no
# surface found" mid-test.
record_surface_for_pane() {
  local pane_ref="$1"
  local surf
  surf=$(cmux list-pane-surfaces --workspace "$WORKSPACE" --pane "$pane_ref" \
           2>/dev/null \
         | grep -oE 'surface:[0-9]+' | head -1)
  if [ -n "$surf" ]; then
    CREATED_SURFACES+=("$surf")
  fi
  return 0
}

@test "script file is executable" {
  [ -x "$SCRIPT" ]
}

@test "pane-create produces pane:N ref on stdout" {
  pane=$("$SCRIPT" --direction down --workspace "$WORKSPACE")
  record_surface_for_pane "$pane"
  [ -n "$pane" ]
  [[ "$pane" =~ ^pane:[0-9]+$ ]]
}

@test "pane-create created pane appears in list-panes" {
  pane=$("$SCRIPT" --direction down --workspace "$WORKSPACE")
  record_surface_for_pane "$pane"
  # list-panes defaults to focused workspace; pass --workspace so our isolated
  # pane is included in the listing.
  cmux list-panes --workspace "$WORKSPACE" | grep -qF "$pane"
}

@test "pane-create accepts --type terminal explicitly" {
  pane=$("$SCRIPT" --direction down --workspace "$WORKSPACE" --type terminal)
  record_surface_for_pane "$pane"
  [[ "$pane" =~ ^pane:[0-9]+$ ]]
}

@test "pane-create defaults direction to down when omitted" {
  pane=$("$SCRIPT" --workspace "$WORKSPACE")
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
