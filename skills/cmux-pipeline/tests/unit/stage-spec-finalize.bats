#!/usr/bin/env bats
# stage-spec-finalize.bats — unit tests for scripts/stage-spec-finalize.sh
#
# Strategy:
# - Each test runs in its own tmpdir to isolate .pipeline/ + gstack-out fixture.
# - Auto-discovery (default ~/.gstack/projects/<slug>) is exercised by injecting
#   a fake gstack-slug binary via $GSTACK_SLUG_BIN.
# - Asserts cover: copy all *.md from explicit dir, manifest status=completed,
#   outputs array length, primary_design selected by mtime, missing run-id error,
#   missing gstack-out dir error, auto-discovery happy path + binary-missing error.
#
# Note: bats 1.x — keep @test names ASCII-only.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/stage-spec-finalize.sh"
  MANIFEST="$BATS_TEST_DIRNAME/../../scripts/manifest.sh"
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  git init -q
  RUN_ID=$("$MANIFEST" gen-run-id "test")
  "$MANIFEST" init "$RUN_ID" "test"
  # Simulate GStack output dir: two design docs (older + newer) plus autoplan/test-plan siblings.
  mkdir -p gstack-out
  printf '# old design\n' > gstack-out/user-feature-design-20260101-000000.md
  # Touch with explicit older mtime so the ordering is deterministic regardless of fs resolution.
  touch -t 202601010000 gstack-out/user-feature-design-20260101-000000.md
  printf '# newer design\n' > gstack-out/user-feature-design-20260507-120000.md
  touch -t 202605071200 gstack-out/user-feature-design-20260507-120000.md
  printf '# autoplan restore\n' > gstack-out/feature-autoplan-restore-20260507-120100.md
  touch -t 202605071201 gstack-out/feature-autoplan-restore-20260507-120100.md
  printf '# test plan\n' > gstack-out/user-feature-test-plan-20260507-120200.md
  touch -t 202605071202 gstack-out/user-feature-test-plan-20260507-120200.md
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "stage-spec-finalize copies all md files in given dir to spec/" {
  run "$SCRIPT" "$RUN_ID" "gstack-out"
  [ "$status" -eq 0 ]
  [ -f ".pipeline/runs/$RUN_ID/spec/user-feature-design-20260507-120000.md" ]
  [ -f ".pipeline/runs/$RUN_ID/spec/user-feature-design-20260101-000000.md" ]
  [ -f ".pipeline/runs/$RUN_ID/spec/feature-autoplan-restore-20260507-120100.md" ]
  [ -f ".pipeline/runs/$RUN_ID/spec/user-feature-test-plan-20260507-120200.md" ]
}

@test "stage-spec-finalize sets stages.spec.status to completed" {
  "$SCRIPT" "$RUN_ID" "gstack-out"
  result=$("$MANIFEST" read "$RUN_ID" '.stages.spec.status')
  [ "$result" = "completed" ]
}

@test "stage-spec-finalize records outputs array in manifest" {
  "$SCRIPT" "$RUN_ID" "gstack-out"
  count=$("$MANIFEST" read "$RUN_ID" '.stages.spec.outputs | length')
  [ "$count" -eq 4 ]
}

@test "stage-spec-finalize identifies primary design doc by mtime" {
  "$SCRIPT" "$RUN_ID" "gstack-out"
  primary=$("$MANIFEST" read "$RUN_ID" '.stages.spec.primary_design')
  [ "$primary" = "spec/user-feature-design-20260507-120000.md" ]
}

@test "stage-spec-finalize requires run-id" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "stage-spec-finalize fails with clear message when gstack-out dir missing" {
  run "$SCRIPT" "$RUN_ID" "nonexistent-dir"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "stage-spec-finalize fails when gstack-out dir has no .md files" {
  mkdir -p empty-dir
  run "$SCRIPT" "$RUN_ID" "empty-dir"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no .md files"* ]]
}

@test "stage-spec-finalize auto-discovers via injected gstack-slug binary" {
  # Build a fake projects tree + gstack-slug shim that points at it.
  FAKE_HOME="$TMPDIR/fake-home"
  mkdir -p "$FAKE_HOME/.gstack/projects/myslug"
  printf '# auto-discovered design\n' > "$FAKE_HOME/.gstack/projects/myslug/user-feature-design-20260507-120000.md"
  touch -t 202605071200 "$FAKE_HOME/.gstack/projects/myslug/user-feature-design-20260507-120000.md"

  FAKE_BIN="$TMPDIR/fake-gstack-slug"
  printf '#!/usr/bin/env bash\necho SLUG=myslug\necho BRANCH=feature\n' > "$FAKE_BIN"
  chmod +x "$FAKE_BIN"

  HOME="$FAKE_HOME" GSTACK_SLUG_BIN="$FAKE_BIN" run "$SCRIPT" "$RUN_ID"
  [ "$status" -eq 0 ]
  [ -f ".pipeline/runs/$RUN_ID/spec/user-feature-design-20260507-120000.md" ]
  primary=$("$MANIFEST" read "$RUN_ID" '.stages.spec.primary_design')
  [ "$primary" = "spec/user-feature-design-20260507-120000.md" ]
}

@test "stage-spec-finalize errors when auto-discovery requested but gstack-slug missing" {
  GSTACK_SLUG_BIN="$TMPDIR/no-such-binary" run "$SCRIPT" "$RUN_ID"
  [ "$status" -ne 0 ]
  [[ "$output" == *"gstack-slug"* ]]
}
