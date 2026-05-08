#!/usr/bin/env bats
# stage-contract.sh: validates contract.md presence and updates manifest.

setup() {
  TMP=$(mktemp -d)
  export PIPELINE_ROOT="$TMP/.pipeline/runs"
  SCRIPT_DIR="$BATS_TEST_DIRNAME/../../scripts"
  MANIFEST="$SCRIPT_DIR/manifest.sh"
  STAGE_CONTRACT="$SCRIPT_DIR/stage-contract.sh"
  RUN_ID="20260508-1200-test"
  "$MANIFEST" init "$RUN_ID" "test topic"
  RUN_DIR="$PIPELINE_ROOT/$RUN_ID"
}
teardown() { rm -rf "$TMP"; }

@test "fails if contract.md missing" {
  run "$STAGE_CONTRACT" "$RUN_ID"
  [ "$status" -ne 0 ]
  [[ "$output" == *"contract.md not found"* ]]
}

@test "marks stages.contract completed when contract.md present" {
  printf '## Feature: test\n\n### Hard Thresholds\n' > "$RUN_DIR/contract.md"
  run "$STAGE_CONTRACT" "$RUN_ID"
  [ "$status" -eq 0 ]
  run jq -r '.stages.contract.status' "$RUN_DIR/manifest.json"
  [ "$output" = "completed" ]
  run jq -r '.stages.contract.contract_path' "$RUN_DIR/manifest.json"
  [ "$output" = "contract.md" ]
}

@test "fails on missing run-id arg" {
  run "$STAGE_CONTRACT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"<run-id> required"* ]]
}
