#!/usr/bin/env bats
# build-status-list.bats — unit tests for scripts/build-status.sh and build-list.sh
#
# Strategy:
# - Each test runs in its own tmpdir; manifest.sh is used to seed two runs.
# - Asserts cover: list output sorting/format, empty case, status table,
#   per-run JSON dump, unknown run-id, --help exits.

setup() {
  ROOT="$BATS_TEST_DIRNAME/../.."
  STATUS="$ROOT/scripts/build-status.sh"
  LIST="$ROOT/scripts/build-list.sh"
  MANIFEST="$ROOT/scripts/manifest.sh"
  TMPDIR=$(mktemp -d) && cd "$TMPDIR"
  git init -q
  for t in "topic alpha" "topic beta"; do
    rid=$("$MANIFEST" gen-run-id "$t")
    "$MANIFEST" init "$rid" "$t"
    sleep 1  # ensure distinct timestamps in run-ids
  done
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "build-list prints all initialized run-ids" {
  output=$("$LIST")
  [[ "$output" == *"topic-alpha"* ]]
  [[ "$output" == *"topic-beta"* ]]
  count=$(echo "$output" | grep -c -E "^[0-9]{8}-[0-9]{4}-")
  [ "$count" -eq 2 ]
}

@test "build-list returns empty (exit 0) when no runs" {
  rm -rf .pipeline
  run "$LIST"
  [ "$status" -eq 0 ]
}

@test "build-status with run-id prints manifest JSON" {
  rid=$("$LIST" | head -1)
  output=$("$STATUS" "$rid")
  [[ "$output" == *"\"run_id\""* ]]
  [[ "$output" == *"\"$rid\""* ]]
  [[ "$output" == *"\"status\""* ]]
  [[ "$output" == *"\"initialized\""* ]]
}

@test "build-status with no args prints table of active runs" {
  output=$("$STATUS")
  [[ "$output" == *"topic-alpha"* ]]
  [[ "$output" == *"topic-beta"* ]]
  [[ "$output" == *"initialized"* ]]
}

@test "build-status with unknown run-id exits non-zero" {
  run "$STATUS" "20990101-0000-nonexistent"
  [ "$status" -ne 0 ]
}

@test "build-status --help exits 0" {
  run "$STATUS" --help
  [ "$status" -eq 0 ]
}

@test "build-list --help exits 0" {
  run "$LIST" --help
  [ "$status" -eq 0 ]
}
