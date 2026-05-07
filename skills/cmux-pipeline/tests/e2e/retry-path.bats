#!/usr/bin/env bats
# tests/e2e/retry-path.bats — verify retry routing.
#
# We can't easily simulate "FAILED then SUCCESS on a fresh pane" because
# stage-loop.sh closes the original pane and starts codex-launch on a new pane,
# which won't actually do anything in the test env (no real codex). So this
# test verifies the 2-fail flow: FAILED on attempt 1 -> fresh pane spawned ->
# fresh pane TIMEOUTs (no codex) -> manifest paused, exit 2.
#
# This still exercises the retry routing code path and the pause-after-2-fail
# state transitions.

setup() {
  ROOT="$BATS_TEST_DIRNAME/../.."
  cmux ping >/dev/null 2>&1 || skip "cmux not running"

  TMPDIR=$(mktemp -d)
  cd "$TMPDIR" || exit 1

  git init -q
  git -c "user.name=test" -c "user.email=test@test" \
      commit --allow-empty -m "init" -q

  RUN_ID=$("$ROOT/scripts/manifest.sh" gen-run-id "retry-test")
  "$ROOT/scripts/manifest.sh" init "$RUN_ID" "retry-test"
  "$ROOT/scripts/manifest.sh" update "$RUN_ID" \
    '.stages.spec.status = "completed" | .stages.decompose.status = "completed"'

  mkdir -p ".pipeline/runs/$RUN_ID/decompose/phases/01-step"
  cat > ".pipeline/runs/$RUN_ID/decompose/phases/01-step/01-01-PLAN.md" <<EOF
# 01 step PLAN

## Goal
fake retry test phase
EOF

  PANE=$("$ROOT/scripts/pane-create.sh" --direction down)
  # shellcheck disable=SC1091
  source "$ROOT/scripts/lib/resolve-surface.sh"
  SURFACE=$(resolve_surface "$PANE")

  # Emit FAILED on first input — stage-loop will close this pane and try a
  # fresh pane (which will TIMEOUT since no real codex is launched).
  cmux send-panel --panel "$SURFACE" -- \
    "read -r line; echo \"==DONE==${RUN_ID}==phase-01-step==FAILED==\"" \
    >/dev/null
  cmux send-key-panel --panel "$SURFACE" enter >/dev/null
  sleep 1
  # Cleanup on abort / Ctrl+C / SIGTERM (bats teardown is skipped on signals).
  trap teardown EXIT INT TERM
}

teardown() {
  # SURFACE may already be closed by stage-loop's pane-close on FAILED retry.
  # Also close any fresh-retry pane stage-loop created (best-effort: scan for
  # the marker text we left in earlier tests' fresh panes).
  if [ -n "${SURFACE:-}" ]; then
    cmux close-surface --surface "$SURFACE" >/dev/null 2>&1 || true
  fi
  # stage-loop may have created a follow-up pane on the FAILED→retry path.
  # Read the manifest to find the most recent worker_pane_id and close it too.
  if [ -n "${RUN_ID:-}" ] && [ -f ".pipeline/runs/$RUN_ID/manifest.json" ]; then
    next_pane=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" \
      '.stages.loop.worker_pane_id // empty' 2>/dev/null || echo "")
    if [ -n "$next_pane" ] && [ "$next_pane" != "$PANE" ]; then
      next_surface=$(cmux list-pane-surfaces --pane "$next_pane" 2>/dev/null \
        | grep -oE 'surface:[0-9]+' | head -1)
      [ -n "$next_surface" ] && cmux close-surface --surface "$next_surface" >/dev/null 2>&1 || true
    fi
  fi
  cd /
  [ -n "${TMPDIR:-}" ] && rm -rf "$TMPDIR"
}

@test "E2E retry: FAILED then 2-fail timeout pauses manifest" {
  # Use short phase timeout so the second attempt's TIMEOUT fires quickly.
  PHASE_TIMEOUT=8 run "$ROOT/scripts/stage-loop.sh" "$RUN_ID" "$PANE"
  # stage-loop should exit 2 (paused).
  [ "$status" -eq 2 ]

  # Manifest should reflect paused state.
  final_status=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" '.status')
  [ "$final_status" = "paused" ]

  paused_at=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" '.checkpoints.paused_at')
  [ "$paused_at" = "loop:01-step" ]

  failed_count=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" \
                   '.stages.loop.failed_phases | length')
  [ "$failed_count" -eq 1 ]

  # Per-phase status: 2 attempts, status = failed.
  attempts=$(jq -r .attempts ".pipeline/runs/$RUN_ID/phases/01-step/status.json")
  [ "$attempts" -eq 2 ]
  phase_status=$(jq -r .status ".pipeline/runs/$RUN_ID/phases/01-step/status.json")
  [ "$phase_status" = "failed" ]
}
