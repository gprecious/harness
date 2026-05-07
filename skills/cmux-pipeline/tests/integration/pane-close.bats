#!/usr/bin/env bats
# pane-close.bats — integration tests for scripts/pane-close.sh
#
# pane-close wraps `cmux close-surface --surface <ref>` (cmux 0.62.2:
# close-surface takes --surface, NOT --pane). It accepts either pane:N or
# surface:N via --pane and resolves internally via lib/resolve-surface.sh.
#
# Contract: idempotent — closing a nonexistent pane MUST exit 0.

setup() {
  CLOSE="$BATS_TEST_DIRNAME/../../scripts/pane-close.sh"
  CREATE="$BATS_TEST_DIRNAME/../../scripts/pane-create.sh"
  cmux ping >/dev/null 2>&1 || skip "cmux not running"
  PANE=$("$CREATE" --direction down)
  # Cleanup on abort / Ctrl+C / SIGTERM (bats teardown is skipped on signals).
  trap teardown EXIT INT TERM
}

teardown() {
  # Best-effort cleanup if a test failed before close
  if [ -n "${PANE:-}" ]; then
    # shellcheck disable=SC1091
    source "$BATS_TEST_DIRNAME/../../scripts/lib/resolve-surface.sh"
    SURFACE=$(resolve_surface "$PANE" 2>/dev/null) || SURFACE=""
    if [ -n "$SURFACE" ]; then
      cmux close-surface --surface "$SURFACE" >/dev/null 2>&1 || true
    fi
  fi
}

@test "script file is executable" {
  [ -x "$CLOSE" ]
}

@test "pane-close: closes pane (no longer in list-panes)" {
  run "$CLOSE" --pane "$PANE"
  [ "$status" -eq 0 ]
  ! cmux list-panes | grep -qF "$PANE"
  PANE=""  # prevent teardown from trying again
}

@test "pane-close: idempotent — closing nonexistent pane exits 0" {
  bogus="pane:99999"
  run "$CLOSE" --pane "$bogus"
  [ "$status" -eq 0 ]
}

@test "pane-close: --pane required" {
  run "$CLOSE"
  [ "$status" -ne 0 ]
}

@test "pane-close: rejects unknown flag" {
  run "$CLOSE" --pane "$PANE" --bogus
  [ "$status" -ne 0 ]
}

@test "pane-close: --help exits 0" {
  run "$CLOSE" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "pane-close: accepts surface ref directly" {
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/../../scripts/lib/resolve-surface.sh"
  surface=$(resolve_surface "$PANE")
  run "$CLOSE" --pane "$surface"
  [ "$status" -eq 0 ]
  ! cmux list-panes | grep -qF "$PANE"
  PANE=""
}
