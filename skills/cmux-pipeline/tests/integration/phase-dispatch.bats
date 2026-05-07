#!/usr/bin/env bats
# phase-dispatch.bats — integration tests for scripts/phase-dispatch.sh
#
# Requires cmux (verified via `cmux ping`); skips otherwise. Each test creates
# a fresh pane + run-id + phase prompt under .pipeline/runs/<run-id>/phases/...,
# primes the pane shell so that any incoming line triggers a sentinel echo,
# then dispatches the prompt and verifies the result.
#
# Sentinel format: ==DONE==<run-id>==phase-<phase-id>==<status>==

setup() {
  DISPATCH="$BATS_TEST_DIRNAME/../../scripts/phase-dispatch.sh"
  CREATE="$BATS_TEST_DIRNAME/../../scripts/pane-create.sh"
  MANIFEST="$BATS_TEST_DIRNAME/../../scripts/manifest.sh"
  WS_CREATE="$BATS_TEST_DIRNAME/../../scripts/workspace-create.sh"
  WS_CLOSE="$BATS_TEST_DIRNAME/../../scripts/workspace-close.sh"
  cmux ping >/dev/null 2>&1 || skip "cmux not running"

  TMPDIR=$(mktemp -d)
  cd "$TMPDIR" || exit 1
  git init -q

  RUN_ID=$("$MANIFEST" gen-run-id "test")
  "$MANIFEST" init "$RUN_ID" "test" >/dev/null

  PHASE="01-test"
  PROMPT_DIR=".pipeline/runs/$RUN_ID/phases/$PHASE"
  mkdir -p "$PROMPT_DIR"
  cat > "$PROMPT_DIR/prompt.md" <<EOF
Test prompt body — this is the dispatch test.
The fake-codex stub will detect any input and respond with the sentinel.
EOF

  WORKSPACE=$("$WS_CREATE" --cwd "$TMPDIR" --title "bats:phase-dispatch")
  export CMUX_WORKSPACE_ID="$WORKSPACE"
  PANE=$("$CREATE" --direction down --workspace "$WORKSPACE")
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/../../scripts/lib/resolve-surface.sh"
  SURFACE=$(resolve_surface "$PANE")
}

teardown() {
  if [ -n "${WORKSPACE:-}" ]; then
    "$WS_CLOSE" --workspace "$WORKSPACE" >/dev/null 2>&1 || true
  fi
  cd /
  [ -n "${TMPDIR:-}" ] && rm -rf "$TMPDIR"
}

# Prime the pane with a small shell loop that echoes the given sentinel
# the first time any non-empty line arrives. We use `read -r line` once
# rather than a while loop so the loop exits cleanly and doesn't echo
# extra sentinels for our subsequent input (the prompt is multi-line).
#
# Strategy: feed all incoming lines into /dev/null but emit ONE sentinel
# the first time we see input. Use a simple `read line; echo SENTINEL`.
prime_pane_sentinel() {
  local status="$1"
  local sentinel="==DONE==${RUN_ID}==phase-${PHASE}==${status}=="
  cmux send-panel --panel "$SURFACE" -- "read -r line; echo \"$sentinel\"" >/dev/null
  cmux send-key-panel --panel "$SURFACE" enter >/dev/null
  sleep 1
}

@test "script file is executable" {
  [ -x "$DISPATCH" ]
}

@test "phase-dispatch: --help exits 0 and prints usage" {
  run "$DISPATCH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "phase-dispatch: missing required flags rejected" {
  run "$DISPATCH"
  [ "$status" -ne 0 ]
}

@test "phase-dispatch: missing prompt file errors" {
  run "$DISPATCH" --pane "$PANE" --run-id "$RUN_ID" --phase-id "missing-phase"
  [ "$status" -ne 0 ]
  [[ "$output" == *"prompt"* ]]
}

@test "phase-dispatch: rejects unknown flag" {
  run "$DISPATCH" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE" --bogus
  [ "$status" -ne 0 ]
}

@test "phase-dispatch: SUCCESS path returns SUCCESS and exit 0" {
  prime_pane_sentinel "SUCCESS"
  run "$DISPATCH" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE" --timeout 30 --poll 1
  [ "$status" -eq 0 ]
  [ "$output" = "SUCCESS" ]
}

@test "phase-dispatch: FAILED sentinel detected" {
  prime_pane_sentinel "FAILED"
  run "$DISPATCH" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE" --timeout 30 --poll 1
  [ "$status" -eq 0 ]
  [ "$output" = "FAILED" ]
}

@test "phase-dispatch: timeout returns 124" {
  # Pane is just an idle shell — no sentinel will appear within 3s
  run "$DISPATCH" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE" --timeout 3 --poll 1
  [ "$status" -eq 124 ]
}

# --- --mode flag (added 2026-05-07 after multi-line fragmentation bug) ------

@test "phase-dispatch: default mode sends single-line file reference" {
  prime_pane_sentinel "SUCCESS"
  run "$DISPATCH" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE" \
    --timeout 30 --poll 1
  [ "$status" -eq 0 ]
  [ "$output" = "SUCCESS" ]
  # Read pane scrollback — the typed message should reference the prompt file
  # path, NOT the prompt body itself.
  pane_text=$(cmux read-screen --surface "$SURFACE" --lines 40)
  [[ "$pane_text" == *"Read the file at"* ]]
  [[ "$pane_text" == *"prompt.md"* ]]
}

@test "phase-dispatch: --mode raw sends prompt body" {
  prime_pane_sentinel "SUCCESS"
  run "$DISPATCH" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE" \
    --timeout 30 --poll 1 --mode raw
  [ "$status" -eq 0 ]
  [ "$output" = "SUCCESS" ]
  # Pane should contain literal text from the prompt body, not "Read the file".
  pane_text=$(cmux read-screen --surface "$SURFACE" --lines 40)
  [[ "$pane_text" == *"Test prompt body"* ]]
}

@test "phase-dispatch: --mode rejects unknown value" {
  run "$DISPATCH" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE" \
    --mode bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"--mode"* ]]
}
