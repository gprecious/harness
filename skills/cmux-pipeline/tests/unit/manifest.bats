#!/usr/bin/env bats
# manifest.bats — unit tests for scripts/manifest.sh
#
# Strategy:
# - Each test runs in its own tmpdir to isolate .pipeline/ state.
# - Asserts cover: gen-run-id format, init dir+JSON shape, read/update,
#   atomic write (no leftover .tmp), updated_at bump, gitignore idempotency,
#   list, unknown subcommand.
#
# Note: bats 1.13 — keep @test names ASCII-only.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/manifest.sh"
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  git init -q
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "manifest gen-run-id matches YYYYMMDD-HHMM-slug format" {
  run "$SCRIPT" gen-run-id "Add Auth Flow"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{8}-[0-9]{4}-add-auth-flow$ ]]
}

@test "manifest gen-run-id slugifies special chars and casefold" {
  run "$SCRIPT" gen-run-id "Foo!! BAR / baz @123"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{8}-[0-9]{4}-foo-bar-baz-123$ ]]
}

@test "manifest init creates directory tree and manifest.json" {
  RUN_ID=$("$SCRIPT" gen-run-id "test topic")
  run "$SCRIPT" init "$RUN_ID" "test topic"
  [ "$status" -eq 0 ]
  [ -d ".pipeline/runs/$RUN_ID/spec" ]
  [ -d ".pipeline/runs/$RUN_ID/decompose" ]
  [ -d ".pipeline/runs/$RUN_ID/phases" ]
  [ -d ".pipeline/runs/$RUN_ID/decisions" ]
  [ -d ".pipeline/runs/$RUN_ID/logs" ]
  [ -f ".pipeline/runs/$RUN_ID/manifest.json" ]
}

@test "manifest init produces valid JSON with required fields" {
  RUN_ID=$("$SCRIPT" gen-run-id "test")
  "$SCRIPT" init "$RUN_ID" "test"
  jq -e '.schema_version == 1' ".pipeline/runs/$RUN_ID/manifest.json"
  jq -e '.topic == "test"' ".pipeline/runs/$RUN_ID/manifest.json"
  jq -e ".run_id == \"$RUN_ID\"" ".pipeline/runs/$RUN_ID/manifest.json"
  jq -e '.status == "initialized"' ".pipeline/runs/$RUN_ID/manifest.json"
  jq -e '.stages.spec.status == "pending"' ".pipeline/runs/$RUN_ID/manifest.json"
}

@test "manifest read extracts a field" {
  RUN_ID=$("$SCRIPT" gen-run-id "test")
  "$SCRIPT" init "$RUN_ID" "test"
  run "$SCRIPT" read "$RUN_ID" .topic
  [ "$status" -eq 0 ]
  [ "$output" = "test" ]
}

@test "manifest update mutates state atomically" {
  RUN_ID=$("$SCRIPT" gen-run-id "test")
  "$SCRIPT" init "$RUN_ID" "test"
  "$SCRIPT" update "$RUN_ID" '.status = "running"'
  result=$("$SCRIPT" read "$RUN_ID" .status)
  [ "$result" = "running" ]
  # No leftover .tmp file
  [ ! -f ".pipeline/runs/$RUN_ID/manifest.json.tmp" ]
}

@test "manifest update bumps updated_at timestamp" {
  RUN_ID=$("$SCRIPT" gen-run-id "test")
  "$SCRIPT" init "$RUN_ID" "test"
  before=$("$SCRIPT" read "$RUN_ID" .updated_at)
  sleep 1
  "$SCRIPT" update "$RUN_ID" '.status = "running"'
  after=$("$SCRIPT" read "$RUN_ID" .updated_at)
  [ "$before" != "$after" ]
}

@test "manifest init adds .pipeline/ to .gitignore" {
  RUN_ID=$("$SCRIPT" gen-run-id "test")
  "$SCRIPT" init "$RUN_ID" "test"
  grep -qE "^\.pipeline/?$" .gitignore
}

@test "manifest init does not duplicate .gitignore entry on rerun" {
  RUN_ID=$("$SCRIPT" gen-run-id "test")
  "$SCRIPT" init "$RUN_ID" "test"
  RUN_ID2=$("$SCRIPT" gen-run-id "test2")
  "$SCRIPT" init "$RUN_ID2" "test2"
  count=$(grep -cE "^\.pipeline/?$" .gitignore)
  [ "$count" -eq 1 ]
}

@test "manifest list returns initialized runs" {
  RUN_ID=$("$SCRIPT" gen-run-id "alpha")
  "$SCRIPT" init "$RUN_ID" "alpha"
  RUN_ID2=$("$SCRIPT" gen-run-id "beta")
  "$SCRIPT" init "$RUN_ID2" "beta"
  output=$("$SCRIPT" list)
  [[ "$output" == *"$RUN_ID"* ]]
  [[ "$output" == *"$RUN_ID2"* ]]
}

@test "manifest unknown subcommand exits non-zero" {
  run "$SCRIPT" bogus
  [ "$status" -ne 0 ]
}
