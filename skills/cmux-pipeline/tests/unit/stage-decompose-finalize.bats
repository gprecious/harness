#!/usr/bin/env bats
# stage-decompose-finalize.bats — unit tests for scripts/stage-decompose-finalize.sh
#
# Strategy:
# - Each test runs in its own tmpdir to isolate .pipeline/ + .planning/ fixture.
# - Fixture mirrors the verified GSD layout from notes/external-skills-io.md:
#     .planning/phases/{padded_phase}-{slug}/{padded_phase}-{NN}-PLAN.md
#     .planning/phases/{padded_phase}-{slug}/{padded_phase}-CONTEXT.md
#     .planning/{PROJECT,REQUIREMENTS,ROADMAP,STATE}.md (top-level refs)
# - Asserts cover: copy phases dirs + PLAN files, top-level ref docs, manifest
#   status + phase_count + phase_dirs array, default planning dir, missing run-id
#   error, missing .planning/phases error.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/stage-decompose-finalize.sh"
  MANIFEST="$BATS_TEST_DIRNAME/../../scripts/manifest.sh"
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  git init -q
  RUN_ID=$("$MANIFEST" gen-run-id "test")
  "$MANIFEST" init "$RUN_ID" "test"
  # Simulate GSD output layout
  mkdir -p .planning/phases/01-bootstrap
  mkdir -p .planning/phases/02-data-model
  mkdir -p .planning/phases/03-routes
  echo "# 01 bootstrap PLAN" > .planning/phases/01-bootstrap/01-01-PLAN.md
  echo "# context" > .planning/phases/01-bootstrap/01-CONTEXT.md
  echo "# 02 data-model PLAN" > .planning/phases/02-data-model/02-01-PLAN.md
  echo "# 03 routes PLAN" > .planning/phases/03-routes/03-01-PLAN.md
  # Also: .planning top-level files (some)
  echo "# project" > .planning/PROJECT.md
  echo "# roadmap" > .planning/ROADMAP.md
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "stage-decompose-finalize copies phases dirs to decompose/phases" {
  run "$SCRIPT" "$RUN_ID" ".planning"
  [ "$status" -eq 0 ]
  [ -d ".pipeline/runs/$RUN_ID/decompose/phases/01-bootstrap" ]
  [ -d ".pipeline/runs/$RUN_ID/decompose/phases/02-data-model" ]
  [ -d ".pipeline/runs/$RUN_ID/decompose/phases/03-routes" ]
  [ -f ".pipeline/runs/$RUN_ID/decompose/phases/01-bootstrap/01-01-PLAN.md" ]
}

@test "stage-decompose-finalize records phase_count = 3" {
  "$SCRIPT" "$RUN_ID" ".planning"
  count=$("$MANIFEST" read "$RUN_ID" '.stages.decompose.phase_count')
  [ "$count" -eq 3 ]
}

@test "stage-decompose-finalize sets stages.decompose.status to completed" {
  "$SCRIPT" "$RUN_ID" ".planning"
  result=$("$MANIFEST" read "$RUN_ID" '.stages.decompose.status')
  [ "$result" = "completed" ]
}

@test "stage-decompose-finalize records phase_dirs array" {
  "$SCRIPT" "$RUN_ID" ".planning"
  len=$("$MANIFEST" read "$RUN_ID" '.stages.decompose.phase_dirs | length')
  [ "$len" -eq 3 ]
  first=$("$MANIFEST" read "$RUN_ID" '.stages.decompose.phase_dirs[0]')
  [[ "$first" =~ decompose/phases/01- ]]
}

@test "stage-decompose-finalize copies top-level .planning ref docs" {
  "$SCRIPT" "$RUN_ID" ".planning"
  [ -f ".pipeline/runs/$RUN_ID/decompose/PROJECT.md" ]
  [ -f ".pipeline/runs/$RUN_ID/decompose/ROADMAP.md" ]
}

@test "stage-decompose-finalize requires run-id" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "stage-decompose-finalize errors if planning dir missing phases" {
  rm -rf .planning/phases
  run "$SCRIPT" "$RUN_ID" ".planning"
  [ "$status" -ne 0 ]
}

@test "stage-decompose-finalize defaults to ./.planning when arg omitted" {
  run "$SCRIPT" "$RUN_ID"
  [ "$status" -eq 0 ]
  count=$("$MANIFEST" read "$RUN_ID" '.stages.decompose.phase_count')
  [ "$count" -eq 3 ]
}
