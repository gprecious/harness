#!/usr/bin/env bats
# resume-prepare.sh recognizes new contract/learn stages.

setup() {
  TMP=$(mktemp -d)
  export PIPELINE_ROOT="$TMP/.pipeline/runs"
  SCRIPT_DIR="$BATS_TEST_DIRNAME/../../scripts"
  MANIFEST="$SCRIPT_DIR/manifest.sh"
  RESUME="$SCRIPT_DIR/resume-prepare.sh"
  RUN_ID="20260508-1200-test"
  "$MANIFEST" init "$RUN_ID" "test topic"
  # Mark run as paused so resume-prepare accepts it; clear paused_at so the
  # stage-sequence walk decides resume_from.
  "$MANIFEST" update "$RUN_ID" \
    '.status = "paused" | .checkpoints.paused_at = null'
}
teardown() { rm -rf "$TMP"; }

@test "resume_from = contract when decompose completed but contract pending" {
  "$MANIFEST" update "$RUN_ID" \
    '.stages.spec.status = "completed" | .stages.decompose.status = "completed"'
  out=$("$RESUME" "$RUN_ID")
  echo "$out" | jq -r '.resume_from' | grep -q "^contract$"
}

@test "resume_from = learn when integrate completed but learn pending" {
  "$MANIFEST" update "$RUN_ID" \
    '.stages.spec.status = "completed"
     | .stages.decompose.status = "completed"
     | .stages.contract.status = "completed"
     | .stages.loop.status = "completed"
     | .stages.integrate.status = "completed"'
  out=$("$RESUME" "$RUN_ID")
  echo "$out" | jq -r '.resume_from' | grep -q "^learn$"
}
