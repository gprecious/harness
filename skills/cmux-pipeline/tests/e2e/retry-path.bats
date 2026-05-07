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

  WORKSPACE=$("$ROOT/scripts/workspace-create.sh" --cwd "$TMPDIR" \
                --title "bats:e2e-retry")
  export CMUX_WORKSPACE_ID="$WORKSPACE"
  PANE=$("$ROOT/scripts/pane-create.sh" --direction down --workspace "$WORKSPACE")
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
}

teardown() {
  # workspace-close removes the original pane and any fresh-retry pane that
  # stage-loop created — single cleanup primitive.
  if [ -n "${WORKSPACE:-}" ]; then
    "$ROOT/scripts/workspace-close.sh" --workspace "$WORKSPACE" \
      >/dev/null 2>&1 || true
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

# --- isolated workspace honored from manifest -------------------------------
# Pin: when manifest.options.workspace_id is set and CMUX_WORKSPACE_ID is NOT
# pre-exported by the caller, stage-loop must still create the retry pane in
# the manifest-recorded workspace (not the user's currently-focused one).
# This is the contract the workspace-create.sh primitive promises.
@test "E2E retry: manifest.options.workspace_id alone routes retry pane" {
  # Record the workspace into the manifest options.
  "$ROOT/scripts/manifest.sh" update "$RUN_ID" \
    ".options.workspace_id = \"$WORKSPACE\""

  # Capture the workspace pane count before invoking stage-loop. Setup created
  # exactly one pane ($PANE); after the first FAILED attempt stage-loop will
  # close it and create a fresh retry pane in the same workspace, so the post
  # count must be >= 1 (timing-dependent: close vs create may race).
  pane_count_before=$(cmux list-panes --workspace "$WORKSPACE" 2>/dev/null \
                       | grep -cE 'pane:[0-9]+' || echo 0)
  [ "$pane_count_before" -ge 1 ]

  # Critical: unset CMUX_WORKSPACE_ID so the only signal stage-loop has is
  # the manifest. If stage-loop ignores the manifest, the retry pane lands in
  # the focused workspace and our --workspace-scoped grep below will fail.
  unset CMUX_WORKSPACE_ID

  PHASE_TIMEOUT=8 run "$ROOT/scripts/stage-loop.sh" "$RUN_ID" "$PANE"
  [ "$status" -eq 2 ]

  # The manifest should now record a *new* worker_pane_id (the retry pane),
  # different from the original $PANE. Both panes belong to $WORKSPACE.
  retry_pane=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" \
                 '.stages.loop.worker_pane_id')
  [ -n "$retry_pane" ]
  [ "$retry_pane" != "$PANE" ]

  # The retry pane must be visible in $WORKSPACE.
  cmux list-panes --workspace "$WORKSPACE" 2>/dev/null \
    | grep -qF "$retry_pane"
}
