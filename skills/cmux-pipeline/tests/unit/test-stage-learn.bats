#!/usr/bin/env bats
# stage-learn.sh: validates wisdom output and updates manifest.

setup() {
  TMP=$(mktemp -d)
  export PIPELINE_ROOT="$TMP/.pipeline/runs"
  export WISDOM_ROOT="$TMP/docs/wisdom"
  SCRIPT_DIR="$BATS_TEST_DIRNAME/../../scripts"
  MANIFEST="$SCRIPT_DIR/manifest.sh"
  STAGE_LEARN="$SCRIPT_DIR/stage-learn.sh"
  RUN_ID="20260508-1200-test"
  "$MANIFEST" init "$RUN_ID" "test topic"
}
teardown() { rm -rf "$TMP"; }

@test "fails if wisdom dir missing or empty" {
  run "$STAGE_LEARN" "$RUN_ID"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no wisdom artifacts"* ]]
}

@test "marks stages.learn completed when wisdom artifacts present" {
  mkdir -p "$WISDOM_ROOT/patterns"
  printf '# Pattern: example\n' > "$WISDOM_ROOT/patterns/example.md"
  run "$STAGE_LEARN" "$RUN_ID"
  [ "$status" -eq 0 ]
  run jq -r '.stages.learn.status' "$PIPELINE_ROOT/$RUN_ID/manifest.json"
  [ "$output" = "completed" ]
  run jq -r '.stages.learn.artifacts | length' "$PIPELINE_ROOT/$RUN_ID/manifest.json"
  [ "$output" -ge 1 ]
}

@test "fails on missing run-id arg" {
  run "$STAGE_LEARN"
  [ "$status" -ne 0 ]
  [[ "$output" == *"<run-id> required"* ]]
}

@test "recurses into nested wisdom subdirs and sorts deterministically" {
  mkdir -p "$WISDOM_ROOT/patterns/sub" "$WISDOM_ROOT/decisions"
  printf '# a\n' > "$WISDOM_ROOT/patterns/a.md"
  printf '# b\n' > "$WISDOM_ROOT/patterns/sub/b.md"
  printf '# c\n' > "$WISDOM_ROOT/decisions/c.md"
  printf '# index\n' > "$WISDOM_ROOT/index.md"
  run "$STAGE_LEARN" "$RUN_ID"
  [ "$status" -eq 0 ]
  run jq -r '.stages.learn.artifacts | length' "$PIPELINE_ROOT/$RUN_ID/manifest.json"
  [ "$output" = "3" ]
  # Sorted order: decisions/c.md, patterns/a.md, patterns/sub/b.md
  run jq -r '.stages.learn.artifacts[0]' "$PIPELINE_ROOT/$RUN_ID/manifest.json"
  [[ "$output" == *"decisions/c.md" ]]
  run jq -r '.stages.learn.artifacts[1]' "$PIPELINE_ROOT/$RUN_ID/manifest.json"
  [[ "$output" == *"patterns/a.md" ]]
  run jq -r '.stages.learn.artifacts[2]' "$PIPELINE_ROOT/$RUN_ID/manifest.json"
  [[ "$output" == *"patterns/sub/b.md" ]]
}
