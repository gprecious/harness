#!/usr/bin/env bats
# pane-send.bats — integration tests for scripts/pane-send.sh
#
# Requires a running cmux instance (verified via `cmux ping`); otherwise each
# test is skipped. Tests create a real pane, send text into it, then read the
# rendered terminal back to verify the marker arrived.
#
# Cleanup: setup creates one pane per test; teardown closes it via
# `cmux close-surface --surface <ref>` (cmux 0.62.2 close-surface takes
# --surface, not --pane).

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/pane-send.sh"
  CREATE="$BATS_TEST_DIRNAME/../../scripts/pane-create.sh"
  cmux ping >/dev/null 2>&1 || skip "cmux not running"
  PANE=$("$CREATE" --direction down)
  SURFACE=$(cmux list-pane-surfaces --pane "$PANE" 2>/dev/null \
    | grep -oE 'surface:[0-9]+' | head -1)
}

teardown() {
  if [ -n "${SURFACE:-}" ]; then
    cmux close-surface --surface "$SURFACE" >/dev/null 2>&1 || true
  fi
}

@test "script file is executable" {
  [ -x "$SCRIPT" ]
}

@test "pane-send: text appears in pane after send" {
  marker="HELLO_TEST_$$"
  "$SCRIPT" --pane "$PANE" --text "echo $marker"
  sleep 1
  output=$(cmux read-screen --surface "$SURFACE" --lines 50)
  [[ "$output" == *"$marker"* ]]
}

@test "pane-send: --pane required, exit non-zero without it" {
  run "$SCRIPT" --text "foo"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--pane"* ]]
}

@test "pane-send: --text required, exit non-zero without it" {
  run "$SCRIPT" --pane "$PANE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--text"* ]]
}

@test "pane-send: multiline text — all lines arrive and execute" {
  marker_a="ALPHA_$$"
  marker_b="BETA_$$"
  prompt=$(printf 'echo %s\necho %s' "$marker_a" "$marker_b")
  "$SCRIPT" --pane "$PANE" --text "$prompt"
  sleep 2
  output=$(cmux read-screen --surface "$SURFACE" --lines 50)
  [[ "$output" == *"$marker_a"* ]]
  [[ "$output" == *"$marker_b"* ]]
}

@test "pane-send: --no-enter leaves text at prompt without executing" {
  # Use a command that would produce a distinctive ERROR if executed,
  # so we can verify --no-enter actually prevented execution. Sending
  # `echo $marker` would execute fine even with Enter, which makes the
  # negative assertion brittle (marker appears twice: prompt + output).
  marker="NOENTER_BOGUS_CMD_$$"
  "$SCRIPT" --pane "$PANE" --text "$marker" --no-enter
  sleep 1
  output=$(cmux read-screen --surface "$SURFACE" --lines 50)
  # Text was typed at the prompt
  [[ "$output" == *"$marker"* ]]
  # Command was NOT executed → no "command not found" error
  [[ "$output" != *"command not found"* ]]
  [[ "$output" != *"not found"* ]]
}

@test "pane-send: rejects unknown flag" {
  run "$SCRIPT" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown"* ]]
}

@test "pane-send: --help exits 0 and prints usage" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--pane"* ]]
  [[ "$output" == *"--text"* ]]
}
