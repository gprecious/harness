#!/usr/bin/env bats
# pane-wait.bats — integration tests for scripts/pane-wait.sh
#
# Requires a running cmux instance (via `cmux ping`); each test is skipped if
# cmux is unavailable. Tests create a pane, inject a sentinel marker via
# pane-send.sh, and verify pane-wait.sh detects (or correctly times out on)
# the marker.
#
# Sentinel format: ==DONE==<run-id>==phase-<phase-id>==<status>==
# where <status> is SUCCESS | NEEDS_HELP | FAILED.

setup() {
  WAIT="$BATS_TEST_DIRNAME/../../scripts/pane-wait.sh"
  SEND="$BATS_TEST_DIRNAME/../../scripts/pane-send.sh"
  CREATE="$BATS_TEST_DIRNAME/../../scripts/pane-create.sh"
  WS_CREATE="$BATS_TEST_DIRNAME/../../scripts/workspace-create.sh"
  WS_CLOSE="$BATS_TEST_DIRNAME/../../scripts/workspace-close.sh"
  cmux ping >/dev/null 2>&1 || skip "cmux not running"
  WORKSPACE=$("$WS_CREATE" --cwd "$BATS_TMPDIR" --title "bats:pane-wait")
  export CMUX_WORKSPACE_ID="$WORKSPACE"
  PANE=$("$CREATE" --direction down --workspace "$WORKSPACE")
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/../../scripts/lib/resolve-surface.sh"
  SURFACE=$(resolve_surface "$PANE")
  RUN_ID="t$$"
  PHASE_ID="0001-test"
}

teardown() {
  if [ -n "${WORKSPACE:-}" ]; then
    "$WS_CLOSE" --workspace "$WORKSPACE" >/dev/null 2>&1 || true
  fi
}

@test "script file is executable" {
  [ -x "$WAIT" ]
}

@test "pane-wait: detects SUCCESS sentinel" {
  ( sleep 2; "$SEND" --pane "$PANE" --text "echo '==DONE==${RUN_ID}==phase-${PHASE_ID}==SUCCESS=='" ) &
  run "$WAIT" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE_ID" --timeout 30 --poll 1
  [ "$status" -eq 0 ]
  [ "$output" = "SUCCESS" ]
}

@test "pane-wait: detects FAILED sentinel" {
  ( sleep 2; "$SEND" --pane "$PANE" --text "echo '==DONE==${RUN_ID}==phase-${PHASE_ID}==FAILED=='" ) &
  run "$WAIT" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE_ID" --timeout 30 --poll 1
  [ "$status" -eq 0 ]
  [ "$output" = "FAILED" ]
}

@test "pane-wait: detects NEEDS_HELP sentinel" {
  ( sleep 2; "$SEND" --pane "$PANE" --text "echo '==DONE==${RUN_ID}==phase-${PHASE_ID}==NEEDS_HELP=='" ) &
  run "$WAIT" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE_ID" --timeout 30 --poll 1
  [ "$status" -eq 0 ]
  [ "$output" = "NEEDS_HELP" ]
}

@test "pane-wait: timeout returns exit 124" {
  run "$WAIT" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE_ID" --timeout 3 --poll 1
  [ "$status" -eq 124 ]
}

@test "pane-wait: ignores wrong run-id sentinel" {
  ( sleep 2; "$SEND" --pane "$PANE" --text "echo '==DONE==WRONG_RUN==phase-${PHASE_ID}==SUCCESS=='" ) &
  run "$WAIT" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE_ID" --timeout 5 --poll 1
  [ "$status" -eq 124 ]
}

@test "pane-wait: ignores wrong phase-id sentinel" {
  ( sleep 2; "$SEND" --pane "$PANE" --text "echo '==DONE==${RUN_ID}==phase-other-phase==SUCCESS=='" ) &
  run "$WAIT" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE_ID" --timeout 5 --poll 1
  [ "$status" -eq 124 ]
}

@test "pane-wait: required flags rejected" {
  run "$WAIT"
  [ "$status" -ne 0 ]
}
