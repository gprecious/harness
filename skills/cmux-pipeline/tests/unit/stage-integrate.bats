#!/usr/bin/env bats
# stage-integrate.bats — unit tests for scripts/stage-integrate.sh
#
# Subcommands under test:
#   complete <run-id>          → stages.integrate.status = "completed", .status = "completed"
#   fail <run-id> <reason>     → stages.integrate.status = "failed", .status = "paused",
#                                .checkpoints.paused_at = "integrate", .checkpoints.paused_reason = <reason>

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/stage-integrate.sh"
  MANIFEST="$BATS_TEST_DIRNAME/../../scripts/manifest.sh"
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  git init -q
  git -c "user.name=test" -c "user.email=test@test" commit --allow-empty -m "init" -q
  RUN_ID=$("$MANIFEST" gen-run-id "test")
  "$MANIFEST" init "$RUN_ID" "test"
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "stage-integrate complete sets stages.integrate.status to completed" {
  run "$SCRIPT" complete "$RUN_ID"
  [ "$status" -eq 0 ]
  result=$("$MANIFEST" read "$RUN_ID" '.stages.integrate.status')
  [ "$result" = "completed" ]
}

@test "stage-integrate complete sets top-level status to completed" {
  "$SCRIPT" complete "$RUN_ID"
  result=$("$MANIFEST" read "$RUN_ID" '.status')
  [ "$result" = "completed" ]
}

@test "stage-integrate fail sets paused with reason" {
  run "$SCRIPT" fail "$RUN_ID" "lint errors in src/foo.ts"
  [ "$status" -eq 0 ]
  status_val=$("$MANIFEST" read "$RUN_ID" '.status')
  [ "$status_val" = "paused" ]
  reason=$("$MANIFEST" read "$RUN_ID" '.checkpoints.paused_reason')
  [[ "$reason" == *"lint errors"* ]]
  paused_at=$("$MANIFEST" read "$RUN_ID" '.checkpoints.paused_at')
  [ "$paused_at" = "integrate" ]
}

@test "stage-integrate fail sets stages.integrate.status to failed" {
  "$SCRIPT" fail "$RUN_ID" "test failed"
  istatus=$("$MANIFEST" read "$RUN_ID" '.stages.integrate.status')
  [ "$istatus" = "failed" ]
}

@test "stage-integrate complete requires run-id" {
  run "$SCRIPT" complete
  [ "$status" -ne 0 ]
}

@test "stage-integrate fail requires run-id and reason" {
  run "$SCRIPT" fail
  [ "$status" -ne 0 ]
  run "$SCRIPT" fail "$RUN_ID"
  [ "$status" -ne 0 ]
}

@test "stage-integrate unknown subcommand exits non-zero" {
  run "$SCRIPT" bogus "$RUN_ID"
  [ "$status" -ne 0 ]
}

@test "stage-integrate --help exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
