#!/usr/bin/env bats
# tests/e2e/full-happy-path.bats — full end-to-end happy path through Stage 3 + 4.
# Stages 1 and 2 are mocked via manifest (skipped to keep test deterministic).

setup() {
  ROOT="$BATS_TEST_DIRNAME/../.."
  cmux ping >/dev/null 2>&1 || skip "cmux not running"

  TMPDIR=$(mktemp -d)
  cd "$TMPDIR" || exit 1

  git init -q
  git -c "user.name=test" -c "user.email=test@test" \
      commit --allow-empty -m "init" -q

  RUN_ID=$("$ROOT/scripts/manifest.sh" gen-run-id "e2e-test")
  "$ROOT/scripts/manifest.sh" init "$RUN_ID" "e2e-test"

  # Mock Stage 1 + 2 as completed
  "$ROOT/scripts/manifest.sh" update "$RUN_ID" \
    '.stages.spec.status = "completed" | .stages.decompose.status = "completed"'

  # Create 4 fake phase dirs (simulating stage-decompose output)
  for n in 01 02 03 04; do
    PHASE_DIR=".pipeline/runs/$RUN_ID/decompose/phases/${n}-step"
    mkdir -p "$PHASE_DIR"
    cat > "$PHASE_DIR/${n}-01-PLAN.md" <<EOF
# ${n} step PLAN

## Goal
fake e2e phase ${n}
EOF
  done

  # Worker pane primed to emit per-phase SUCCESS sentinels for each input line.
  PANE=$("$ROOT/scripts/pane-create.sh" --direction down)
  # shellcheck disable=SC1091
  source "$ROOT/scripts/lib/resolve-surface.sh"
  SURFACE=$(resolve_surface "$PANE")

  cmux send-panel --panel "$SURFACE" -- \
    "while read -r line; do for n in 01-step 02-step 03-step 04-step; do echo \"==DONE==${RUN_ID}==phase-\$n==SUCCESS==\"; done; done" \
    >/dev/null
  cmux send-key-panel --panel "$SURFACE" enter >/dev/null
  sleep 1
}

teardown() {
  if [ -n "${SURFACE:-}" ]; then
    cmux close-surface --surface "$SURFACE" >/dev/null 2>&1 || true
  fi
  cd /
  [ -n "${TMPDIR:-}" ] && rm -rf "$TMPDIR"
}

@test "E2E happy: 4 phases SUCCESS + Stage 4 complete" {
  # Stage 3: run loop
  PHASE_TIMEOUT=20 run "$ROOT/scripts/stage-loop.sh" "$RUN_ID" "$PANE"
  [ "$status" -eq 0 ]

  count=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" \
            '.stages.loop.completed_phases | length')
  [ "$count" -eq 4 ]

  loop_status=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" \
                  '.stages.loop.status')
  [ "$loop_status" = "completed" ]

  # Stage 4: integrate complete
  run "$ROOT/scripts/stage-integrate.sh" complete "$RUN_ID"
  [ "$status" -eq 0 ]

  integrate_status=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" \
                       '.stages.integrate.status')
  [ "$integrate_status" = "completed" ]

  final_status=$("$ROOT/scripts/manifest.sh" read "$RUN_ID" '.status')
  [ "$final_status" = "completed" ]
}
