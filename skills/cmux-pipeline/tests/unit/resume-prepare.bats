#!/usr/bin/env bats

setup() {
  ROOT="$BATS_TEST_DIRNAME/../.."
  SCRIPT="$ROOT/scripts/resume-prepare.sh"
  MANIFEST="$ROOT/scripts/manifest.sh"
  TMPDIR=$(mktemp -d) && cd "$TMPDIR"
  git init -q
  RUN_ID=$("$MANIFEST" gen-run-id "test")
  "$MANIFEST" init "$RUN_ID" "test"
  "$MANIFEST" update "$RUN_ID" '.status = "paused" | .checkpoints.paused_at = "loop:03-routes" | .stages.loop.worker_pane_id = "pane:42"'
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "resume-prepare paused run prints JSON with resume_from" {
  output=$("$SCRIPT" "$RUN_ID")
  resume_from=$(echo "$output" | jq -r .resume_from)
  [ "$resume_from" = "loop:03-routes" ]
  rid=$(echo "$output" | jq -r .run_id)
  [ "$rid" = "$RUN_ID" ]
  topic=$(echo "$output" | jq -r .topic)
  [ "$topic" = "test" ]
  pane=$(echo "$output" | jq -r .worker_pane_id)
  [ "$pane" = "pane:42" ]
}

@test "resume-prepare paused run includes options object" {
  output=$("$SCRIPT" "$RUN_ID")
  has_options=$(echo "$output" | jq -e '.options | has("checkpoint")')
  [ "$has_options" = "true" ]
}

@test "resume-prepare failed run is also resumable" {
  "$MANIFEST" update "$RUN_ID" '.status = "failed"'
  run "$SCRIPT" "$RUN_ID"
  [ "$status" -eq 0 ]
}

@test "resume-prepare completed run rejected" {
  "$MANIFEST" update "$RUN_ID" '.status = "completed"'
  run "$SCRIPT" "$RUN_ID"
  [ "$status" -ne 0 ]
}

@test "resume-prepare initialized (running) run rejected" {
  "$MANIFEST" update "$RUN_ID" '.status = "running"'
  run "$SCRIPT" "$RUN_ID"
  [ "$status" -ne 0 ]
}

@test "resume-prepare nonexistent run rejected" {
  run "$SCRIPT" "20990101-0000-nonexistent"
  [ "$status" -ne 0 ]
}

@test "resume-prepare requires run-id" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "resume-prepare --help exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
}
