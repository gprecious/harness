#!/usr/bin/env bats
# codex-launch.bats — integration tests for scripts/codex-launch.sh
#
# Strategy: codex-launch.sh composes a `codex …` command line and types it
# into a cmux pane via pane-send.sh. We don't actually want to start the real
# codex TUI inside the test pane — instead we shadow `codex` on PATH with the
# fake-codex.sh stub so the typed command line is harmless when executed but
# still lets us verify the launch script:
#   1. Typed something containing the literal token `codex` into the pane.
#   2. Honors --model (custom model name appears in the typed command line).
#   3. Required-arg / unknown-flag / --help validation.
#
# We verify the typed command line by reading the pane scrollback. The pane is
# a real shell, so the command line shows up after Enter. We do NOT assert the
# fake-codex output itself (timing-sensitive); we assert the command line text.
#
# Quoting note: the codex invocation includes `-c 'mcp_servers={}'` and
# `-c 'model_reasoning_effort="high"'`. These must survive (a) the typed-into-
# pane pathway and (b) zsh/bash globbing (`{}`). The "typed command appears"
# test covers (a) by looking for the literal token `codex`. We also assert
# the command does not get truncated at `{` by checking the pane for
# `mcp_servers`.

setup() {
  LAUNCH="$BATS_TEST_DIRNAME/../../scripts/codex-launch.sh"
  CREATE="$BATS_TEST_DIRNAME/../../scripts/pane-create.sh"
  cmux ping >/dev/null 2>&1 || skip "cmux not running"
  PANE=$("$CREATE" --direction down)
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/../../scripts/lib/resolve-surface.sh"
  SURFACE=$(resolve_surface "$PANE")

  # Shadow real codex with the fake stub so the typed command line is harmless
  # when the pane's shell executes it. The launch script invokes `codex` by
  # bare name, so prepending FAKE_DIR to PATH is sufficient for its environment;
  # however the launched pane has its own PATH (inherited from cmux), so the
  # pane may still resolve real codex. That's OK — we only assert on the typed
  # command line text, not on codex stdout.
  FAKE_DIR=$(mktemp -d)
  ln -sf "$BATS_TEST_DIRNAME/../fixtures/fake-codex.sh" "$FAKE_DIR/codex"
  export PATH="$FAKE_DIR:$PATH"
}

teardown() {
  if [ -n "${SURFACE:-}" ]; then
    cmux close-surface --surface "$SURFACE" >/dev/null 2>&1 || true
  fi
  if [ -n "${FAKE_DIR:-}" ] && [ -d "$FAKE_DIR" ]; then
    rm -rf "$FAKE_DIR"
  fi
}

@test "script file is executable" {
  [ -x "$LAUNCH" ]
}

@test "codex-launch: typed command appears in pane" {
  run "$LAUNCH" --pane "$PANE" --cwd "$BATS_TEST_DIRNAME"
  [ "$status" -eq 0 ]
  sleep 1
  output=$(cmux read-screen --surface "$SURFACE" --lines 80)
  # The literal `codex` token must appear in the pane (the typed command line).
  [[ "$output" == *"codex"* ]]
  # And the corrected Phase 0 flags must survive quoting (no truncation at `{`).
  [[ "$output" == *"mcp_servers"* ]]
  [[ "$output" == *"model_reasoning_effort"* ]]
}

@test "codex-launch: --pane required" {
  run "$LAUNCH" --cwd /tmp
  [ "$status" -ne 0 ]
  [[ "$output" == *"--pane"* ]]
}

@test "codex-launch: --cwd required" {
  run "$LAUNCH" --pane "$PANE"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--cwd"* ]]
}

@test "codex-launch: rejects unknown flag" {
  run "$LAUNCH" --pane "$PANE" --cwd /tmp --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown"* ]]
}

@test "codex-launch: --help exits 0" {
  run "$LAUNCH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"--pane"* ]]
  [[ "$output" == *"--cwd"* ]]
}

@test "codex-launch: --model overrides default" {
  run "$LAUNCH" --pane "$PANE" --cwd "$BATS_TEST_DIRNAME" --model "custom-model-xxx"
  [ "$status" -eq 0 ]
  sleep 1
  output=$(cmux read-screen --surface "$SURFACE" --lines 80)
  [[ "$output" == *"custom-model-xxx"* ]]
}
