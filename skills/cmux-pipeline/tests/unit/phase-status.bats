#!/usr/bin/env bats
# phase-status.bats — unit tests for scripts/phase-status.sh
#
# Strategy:
# - Each test runs in its own tmpdir to isolate .pipeline/ state.
# - Uses manifest.sh only for run-id generation + run dir setup.
# - Asserts cover: init shape, complete (SUCCESS + FAILED), retry, read,
#   non-negative duration_sec, unknown subcommand.
#
# Note: bats — keep @test names ASCII-only.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/phase-status.sh"
  MANIFEST="$BATS_TEST_DIRNAME/../../scripts/manifest.sh"
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  git init -q
  RUN_ID=$("$MANIFEST" gen-run-id "test")
  "$MANIFEST" init "$RUN_ID" "test"
  PHASE="0001-bootstrap"
  PHASE_DIR=".pipeline/runs/$RUN_ID/phases/$PHASE"
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "phase-status init creates status.json with started state" {
  run "$SCRIPT" init "$RUN_ID" "$PHASE" "pane:abc"
  [ "$status" -eq 0 ]
  [ -f "$PHASE_DIR/status.json" ]
  jq -e '.status == "started"' "$PHASE_DIR/status.json"
  jq -e '.attempts == 1' "$PHASE_DIR/status.json"
  jq -e '.phase_id == "0001-bootstrap"' "$PHASE_DIR/status.json"
  jq -e '.worker_pane_id == "pane:abc"' "$PHASE_DIR/status.json"
  jq -e '.started_at != null' "$PHASE_DIR/status.json"
  jq -e '.ended_at == null' "$PHASE_DIR/status.json"
  # No leftover .tmp file
  [ ! -f "$PHASE_DIR/status.json.tmp" ]
}

@test "phase-status complete with SUCCESS sets completed status" {
  "$SCRIPT" init "$RUN_ID" "$PHASE" "pane:abc"
  sleep 1
  run "$SCRIPT" complete "$RUN_ID" "$PHASE" "SUCCESS" "abc1234"
  [ "$status" -eq 0 ]
  jq -e '.status == "completed"' "$PHASE_DIR/status.json"
  jq -e '.sentinel_status == "SUCCESS"' "$PHASE_DIR/status.json"
  jq -e '.commit_sha == "abc1234"' "$PHASE_DIR/status.json"
  jq -e '.ended_at != null' "$PHASE_DIR/status.json"
  jq -e '.duration_sec >= 1' "$PHASE_DIR/status.json"
  # No leftover .tmp file
  [ ! -f "$PHASE_DIR/status.json.tmp" ]
}

@test "phase-status complete with FAILED sets failed status" {
  "$SCRIPT" init "$RUN_ID" "$PHASE" "pane:abc"
  run "$SCRIPT" complete "$RUN_ID" "$PHASE" "FAILED" "n/a"
  [ "$status" -eq 0 ]
  jq -e '.status == "failed"' "$PHASE_DIR/status.json"
  jq -e '.sentinel_status == "FAILED"' "$PHASE_DIR/status.json"
}

@test "phase-status retry increments attempts and resets state" {
  "$SCRIPT" init "$RUN_ID" "$PHASE" "pane:abc"
  "$SCRIPT" retry "$RUN_ID" "$PHASE" "pane:def"
  jq -e '.attempts == 2' "$PHASE_DIR/status.json"
  jq -e '.status == "retrying"' "$PHASE_DIR/status.json"
  jq -e '.worker_pane_id == "pane:def"' "$PHASE_DIR/status.json"
  jq -e '.ended_at == null' "$PHASE_DIR/status.json"
  jq -e '.duration_sec == null' "$PHASE_DIR/status.json"
}

@test "phase-status read extracts a field" {
  "$SCRIPT" init "$RUN_ID" "$PHASE" "pane:abc"
  run "$SCRIPT" read "$RUN_ID" "$PHASE" .attempts
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "phase-status complete keeps duration_sec non-negative" {
  "$SCRIPT" init "$RUN_ID" "$PHASE" "pane:abc"
  "$SCRIPT" complete "$RUN_ID" "$PHASE" "SUCCESS" "abc1234"
  dur=$(jq -r .duration_sec "$PHASE_DIR/status.json")
  [ "$dur" -ge 0 ]
}

@test "phase-status unknown subcommand exits non-zero" {
  run "$SCRIPT" bogus
  [ "$status" -ne 0 ]
}
