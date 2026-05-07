#!/usr/bin/env bats
# build-gc.bats — unit tests for scripts/build-gc.sh
#
# Strategy:
# - Each test runs in its own tmpdir to isolate .pipeline/ state.
# - Mtime manipulation: prefer BSD `touch -t` (macOS), fall back to GNU
#   `touch -d "40 days ago"` (Linux). Both forms are tried in setup so the
#   suite is portable across CI environments.

setup() {
  ROOT="$BATS_TEST_DIRNAME/../.."
  GC="$ROOT/scripts/build-gc.sh"
  MANIFEST="$ROOT/scripts/manifest.sh"
  TMPDIR=$(mktemp -d) && cd "$TMPDIR"
  git init -q

  # Create old run (40 days old)
  OLD=$("$MANIFEST" gen-run-id "old")
  "$MANIFEST" init "$OLD" "old"
  if touch -t $(date -j -v-40d +%Y%m%d0000) ".pipeline/runs/$OLD" 2>/dev/null; then
    :
  else
    touch -d "40 days ago" ".pipeline/runs/$OLD"
  fi

  # Create recent run (today). gen-run-id is YYYYMMDD-HHMM-slug; the OLD one
  # was generated in the same minute so we use a different slug to avoid the
  # init for NEW reusing the same directory.
  NEW=$("$MANIFEST" gen-run-id "newrun")
  "$MANIFEST" init "$NEW" "newrun"
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "build-gc default 30 deletes 40-day-old run, keeps recent" {
  run "$GC"
  [ "$status" -eq 0 ]
  [ ! -d ".pipeline/runs/$OLD" ]
  [ -d ".pipeline/runs/$NEW" ]
}

@test "build-gc 60 keeps 40-day-old run" {
  run "$GC" 60
  [ "$status" -eq 0 ]
  [ -d ".pipeline/runs/$OLD" ]
  [ -d ".pipeline/runs/$NEW" ]
}

@test "build-gc 7 deletes both old and recent if both > 7d" {
  if touch -t $(date -j -v-40d +%Y%m%d0000) ".pipeline/runs/$NEW" 2>/dev/null; then
    :
  else
    touch -d "40 days ago" ".pipeline/runs/$NEW"
  fi
  run "$GC" 7
  [ "$status" -eq 0 ]
  [ ! -d ".pipeline/runs/$OLD" ]
  [ ! -d ".pipeline/runs/$NEW" ]
}

@test "build-gc no .pipeline directory exits 0" {
  rm -rf .pipeline
  run "$GC"
  [ "$status" -eq 0 ]
}

@test "build-gc prints removed paths" {
  output=$("$GC")
  [[ "$output" == *"$OLD"* ]]
  [[ "$output" != *"$NEW"* ]]
}

@test "build-gc --help exits 0" {
  run "$GC" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}
