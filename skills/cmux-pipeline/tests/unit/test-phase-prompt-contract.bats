#!/usr/bin/env bats
# phase-prompt-build.sh injects contract.md path when present.

setup() {
  TMP=$(mktemp -d)
  export PIPELINE_ROOT="$TMP/.pipeline/runs"
  SCRIPT_DIR="$BATS_TEST_DIRNAME/../../scripts"
  MANIFEST="$SCRIPT_DIR/manifest.sh"
  BUILD="$SCRIPT_DIR/phase-prompt-build.sh"
  RUN_ID="20260508-1200-test"
  PHASE_ID="01-foo"
  "$MANIFEST" init "$RUN_ID" "test topic"
  RUN_DIR="$PIPELINE_ROOT/$RUN_ID"
  PHASE_DIR="$RUN_DIR/decompose/phases/$PHASE_ID"
  mkdir -p "$PHASE_DIR"
  printf '# Plan\n- step\n' > "$PHASE_DIR/01-01-PLAN.md"
}
teardown() { rm -rf "$TMP"; }

@test "prompt omits contract section when contract.md absent" {
  out=$("$BUILD" "$RUN_ID" "$PHASE_ID")
  ! grep -q "Contract Reference" "$out"
}

@test "prompt includes contract.md path when present" {
  printf '## Feature: test\n' > "$RUN_DIR/contract.md"
  out=$("$BUILD" "$RUN_ID" "$PHASE_ID")
  grep -q "Contract Reference" "$out"
  grep -q "contract.md" "$out"
}
