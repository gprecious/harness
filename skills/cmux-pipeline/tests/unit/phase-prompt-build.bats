#!/usr/bin/env bats
# phase-prompt-build.bats — unit tests for scripts/phase-prompt-build.sh
#
# Strategy:
# - Each test runs in its own tmpdir; manifest.sh init scaffolds .pipeline/runs/<run-id>/.
# - We seed a single phase dir under decompose/phases/<phase-id>/ with a PLAN.md
#   (and optional CONTEXT.md) — mirroring the actual layout produced by Task 17
#   (stage-decompose-finalize).
# - Asserts: prompt.md path, stdout path, sentinel pattern presence, PLAN body
#   inlined, RUN_ID + TOPIC substituted, error on missing phase dir, error on
#   missing args, "Original GSD Plan" appendix included.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/phase-prompt-build.sh"
  MANIFEST="$BATS_TEST_DIRNAME/../../scripts/manifest.sh"
  TMPDIR=$(mktemp -d) && cd "$TMPDIR"
  git init -q
  RUN_ID=$("$MANIFEST" gen-run-id "test-topic")
  "$MANIFEST" init "$RUN_ID" "test-topic"
  PHASE="01-bootstrap"
  PHASE_DIR=".pipeline/runs/$RUN_ID/decompose/phases/$PHASE"
  mkdir -p "$PHASE_DIR"
  cat > "$PHASE_DIR/01-01-PLAN.md" <<EOF
# 01 bootstrap PLAN

## Goal
Setup project skeleton

## Files
- src/index.ts
- package.json

## Tests
- tests/index.test.ts
EOF
  cat > "$PHASE_DIR/01-CONTEXT.md" <<EOF
# Context for bootstrap
Repo currently empty.
EOF
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "phase-prompt-build creates prompt.md at expected path" {
  run "$SCRIPT" "$RUN_ID" "$PHASE"
  [ "$status" -eq 0 ]
  [ -f ".pipeline/runs/$RUN_ID/phases/$PHASE/prompt.md" ]
}

@test "phase-prompt-build prints output path on stdout" {
  output=$("$SCRIPT" "$RUN_ID" "$PHASE")
  [[ "$output" == *"phases/$PHASE/prompt.md" ]]
}

@test "phase-prompt-build includes sentinel pattern in prompt" {
  "$SCRIPT" "$RUN_ID" "$PHASE"
  prompt=$(cat ".pipeline/runs/$RUN_ID/phases/$PHASE/prompt.md")
  [[ "$prompt" == *"==DONE==$RUN_ID==phase-$PHASE=="* ]]
}

@test "phase-prompt-build inlines PLAN body" {
  "$SCRIPT" "$RUN_ID" "$PHASE"
  prompt=$(cat ".pipeline/runs/$RUN_ID/phases/$PHASE/prompt.md")
  [[ "$prompt" == *"Setup project skeleton"* ]]
}

@test "phase-prompt-build includes RUN_ID and TOPIC in substituted vars" {
  "$SCRIPT" "$RUN_ID" "$PHASE"
  prompt=$(cat ".pipeline/runs/$RUN_ID/phases/$PHASE/prompt.md")
  [[ "$prompt" == *"$RUN_ID"* ]]
  [[ "$prompt" == *"test-topic"* ]]
}

@test "phase-prompt-build errors when phase dir missing" {
  run "$SCRIPT" "$RUN_ID" "99-nonexistent"
  [ "$status" -ne 0 ]
}

@test "phase-prompt-build requires both run-id and phase-id" {
  run "$SCRIPT" "$RUN_ID"
  [ "$status" -ne 0 ]
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "phase-prompt-build appends original PLAN as section" {
  "$SCRIPT" "$RUN_ID" "$PHASE"
  prompt=$(cat ".pipeline/runs/$RUN_ID/phases/$PHASE/prompt.md")
  [[ "$prompt" == *"Original GSD Plan"* ]] || [[ "$prompt" == *"GSD plan"* ]]
}
