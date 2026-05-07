#!/usr/bin/env bats
# preflight.bats — unit tests for scripts/preflight.sh
#
# Strategy:
# - Use real env for the "all deps present" happy path (cmux/codex/jq/git/gh
#   are installed on dev machine and CI image; plugins gstack/gsd/build-loop/
#   superpowers/ralph-loop are also installed).
# - Use empty PATH (with --no-plugin-check) to simulate missing binaries.
# - Use --no-plugin-check to test binary-half independently of plugin state
#   (helpful for environments where plugin install isn't done).
#
# Note: bats 1.13 does not support multi-byte chars in @test names reliably.
# Test names kept ASCII; comments may use Korean.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/preflight.sh"
}

@test "script file is executable" {
  [ -x "$SCRIPT" ]
}

@test "exits 0 in env with all deps present" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "--dry-run flag exits 0 and mentions dry-run" {
  run "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
}

@test "--no-plugin-check alone exits 0" {
  run "$SCRIPT" --no-plugin-check
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "--no-plugin-check + --dry-run combined" {
  run "$SCRIPT" --no-plugin-check --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry-run"* ]]
}

@test "rejects unknown flag with non-zero exit" {
  run "$SCRIPT" --bogus-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown"* ]]
  [[ "$output" == *"Usage"* ]]
}

@test "empty PATH triggers missing-binary exit 1" {
  # Empty PATH so command -v inside the script finds nothing.
  # We invoke via an explicit /bin/bash so the script can still start (the
  # shebang interpreter would otherwise be unresolvable under PATH=""), then
  # within the script PATH is also empty so all command -v lookups miss.
  # --no-plugin-check skips plugin checks (which need `claude`).
  PATH="" run /bin/bash "$SCRIPT" --no-plugin-check
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing"* ]]
  [[ "$output" == *"cmux"* ]]
}

@test "missing output includes install hint" {
  PATH="" run /bin/bash "$SCRIPT" --no-plugin-check
  [ "$status" -ne 0 ]
  [[ "$output" == *"cmux.app"* ]]
}

@test "--help prints usage and exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
