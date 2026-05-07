#!/usr/bin/env bats
# stage-loop-happy.bats — e2e: 3-phase happy path through stage-loop.sh
#
# Strategy: prime the worker pane's shell with a `while read` loop that emits
# all three SUCCESS sentinels (one per phase) for every input line it receives.
# pane-wait.sh greps the scrollback for the sentinel matching the *current*
# phase-id, so emitting all three at once is safe — only the matching one is
# consumed per dispatch. After the first dispatch the loop also consumes the
# remaining lines of the prompt, but that's irrelevant: the sentinels we need
# are already in scrollback.
#
# Requires a running cmux daemon; skipped otherwise.

setup() {
  ROOT="$BATS_TEST_DIRNAME/../.."
  cmux ping >/dev/null 2>&1 || skip "cmux not running"

  TMPDIR=$(mktemp -d)
  cd "$TMPDIR" || exit 1

  git init -q
  git -c "user.name=test" -c "user.email=test@test" \
      commit --allow-empty -m "init" -q

  RUN_ID=$("$ROOT/scripts/manifest.sh" gen-run-id "test")
  "$ROOT/scripts/manifest.sh" init "$RUN_ID" "test"

  # Three fake phase directories under decompose/phases/
  for n in 01 02 03; do
    PHASE_DIR=".pipeline/runs/$RUN_ID/decompose/phases/${n}-step"
    mkdir -p "$PHASE_DIR"
    cat > "$PHASE_DIR/${n}-01-PLAN.md" <<EOF
# ${n} step PLAN

## Goal
fake phase ${n}
EOF
  done

  PANE=$("$ROOT/scripts/pane-create.sh" --direction down)
  # shellcheck disable=SC1091
  source "$ROOT/scripts/lib/resolve-surface.sh"
  SURFACE=$(resolve_surface "$PANE")

  # Prime the pane: for every input line, emit SUCCESS sentinels for all 3
  # phase ids (01-step, 02-step, 03-step). pane-wait greps for the matching
  # one per dispatch. Use single-quoted heredoc-like form via bash -c so we
  # avoid escaping headaches with $RUN_ID expansion locally vs. in the pane.
  cmux send-panel --panel "$SURFACE" -- \
    "while read -r line; do for n in 01-step 02-step 03-step; do echo \"==DONE==${RUN_ID}==phase-\$n==SUCCESS==\"; done; done" \
    >/dev/null
  cmux send-key-panel --panel "$SURFACE" enter >/dev/null
  sleep 1
  # Cleanup on abort / Ctrl+C / SIGTERM (bats teardown is skipped on signals).
  trap teardown EXIT INT TERM
}

teardown() {
  if [ -n "${SURFACE:-}" ]; then
    cmux close-surface --surface "$SURFACE" >/dev/null 2>&1 || true
  fi
  cd /
  [ -n "${TMPDIR:-}" ] && rm -rf "$TMPDIR"
}

@test "stage-loop happy: 3 phases all SUCCESS, manifest completed" {
  # Use shorter dispatch timeout so the test is bounded if something hangs.
  PHASE_TIMEOUT=20 run "$ROOT/scripts/stage-loop.sh" "$RUN_ID" "$PANE"
  [ "$status" -eq 0 ]

  count=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" \
            '.stages.loop.completed_phases | length')
  [ "$count" -eq 3 ]

  status_val=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" \
                 '.stages.loop.status')
  [ "$status_val" = "completed" ]
}
