#!/usr/bin/env bats
# Schema v2: stages.contract and stages.learn present after init.

setup() {
  TMP=$(mktemp -d)
  export PIPELINE_ROOT="$TMP/.pipeline/runs"
  SCRIPT_DIR="$BATS_TEST_DIRNAME/../../scripts"
  MANIFEST="$SCRIPT_DIR/manifest.sh"
}
teardown() { rm -rf "$TMP"; }

@test "init writes schema_version 2" {
  "$MANIFEST" init "20260508-1200-test" "test topic"
  run jq -r '.schema_version' "$PIPELINE_ROOT/20260508-1200-test/manifest.json"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "init creates stages.contract and stages.learn pending" {
  "$MANIFEST" init "20260508-1200-test" "test topic"
  run jq -r '.stages.contract.status' "$PIPELINE_ROOT/20260508-1200-test/manifest.json"
  [ "$output" = "pending" ]
  run jq -r '.stages.learn.status' "$PIPELINE_ROOT/20260508-1200-test/manifest.json"
  [ "$output" = "pending" ]
}

@test "default checkpoint includes contract" {
  "$MANIFEST" init "20260508-1200-test" "test topic"
  run jq -r '.options.checkpoint | join(",")' "$PIPELINE_ROOT/20260508-1200-test/manifest.json"
  [ "$output" = "spec,decompose,contract" ]
}
