#!/usr/bin/env bats
# test-workspace-lifecycle.bats — verifies auto-close of cmux workspaces across
# the four lifecycle trigger points: stage-learn DONE, build-gc removal, preflight
# orphan sweep, and the --keep-workspace opt-out.
#
# Strategy: shim `cmux` and `claude` on PATH. The shim:
#   - For `list-workspaces` echoes the contents of $CMUX_LIST_FIXTURE
#   - For `close-workspace --workspace <ref>` appends `close <ref>` to $CMUX_LOG
#   - All other invocations no-op exit 0
# This isolates the test from any real cmux daemon on the dev machine while
# letting us assert exact close-call sequences.

setup() {
  ROOT="$BATS_TEST_DIRNAME/../.."
  TMPDIR=$(mktemp -d) && cd "$TMPDIR"
  git init -q

  mkdir -p bin
  cat > bin/cmux <<'EOF'
#!/usr/bin/env bash
case "$1" in
  list-workspaces)
    [ -f "$CMUX_LIST_FIXTURE" ] && cat "$CMUX_LIST_FIXTURE"
    exit 0
    ;;
  close-workspace)
    shift
    while [ $# -gt 0 ]; do
      case "$1" in
        --workspace) echo "close $2" >> "$CMUX_LOG"; shift 2 ;;
        *) shift ;;
      esac
    done
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x bin/cmux

  # Stub `claude` so preflight's plugin half doesn't touch the real CLI.
  cat > bin/claude <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x bin/claude

  export PATH="$TMPDIR/bin:$PATH"
  export CMUX_LOG="$TMPDIR/cmux.log"
  export CMUX_LIST_FIXTURE="$TMPDIR/list.txt"
  : > "$CMUX_LOG"
  : > "$CMUX_LIST_FIXTURE"

  STAGE_LEARN="$ROOT/scripts/stage-learn.sh"
  BUILD_GC="$ROOT/scripts/build-gc.sh"
  PREFLIGHT="$ROOT/scripts/preflight.sh"
  MANIFEST="$ROOT/scripts/manifest.sh"

  export PIPELINE_ROOT="$TMPDIR/.pipeline/runs"
  export WISDOM_ROOT="$TMPDIR/docs/wisdom"
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

# ---------- stage-learn DONE path ----------

@test "stage-learn closes workspace by default after marking completed" {
  RUN_ID="20260508-1200-learn1"
  "$MANIFEST" init "$RUN_ID" "learn1"
  "$MANIFEST" update "$RUN_ID" '.options.workspace_id = "workspace:99"'
  mkdir -p "$WISDOM_ROOT/patterns"
  printf '# p\n' > "$WISDOM_ROOT/patterns/p.md"

  run "$STAGE_LEARN" "$RUN_ID"
  [ "$status" -eq 0 ]
  [[ "$output" == *"closed workspace workspace:99"* ]]
  grep -q '^close workspace:99$' "$CMUX_LOG"
}

@test "stage-learn keeps workspace when keep_workspace=true" {
  RUN_ID="20260508-1201-learn2"
  "$MANIFEST" init "$RUN_ID" "learn2"
  "$MANIFEST" update "$RUN_ID" '.options.workspace_id = "workspace:88" | .options.keep_workspace = true'
  mkdir -p "$WISDOM_ROOT/patterns"
  printf '# p\n' > "$WISDOM_ROOT/patterns/p.md"

  run "$STAGE_LEARN" "$RUN_ID"
  [ "$status" -eq 0 ]
  [[ "$output" == *"keeping workspace workspace:88"* ]]
  ! grep -q '^close ' "$CMUX_LOG"
}

@test "stage-learn no-op when workspace_id missing" {
  RUN_ID="20260508-1202-learn3"
  "$MANIFEST" init "$RUN_ID" "learn3"
  mkdir -p "$WISDOM_ROOT/patterns"
  printf '# p\n' > "$WISDOM_ROOT/patterns/p.md"

  run "$STAGE_LEARN" "$RUN_ID"
  [ "$status" -eq 0 ]
  [[ "$output" != *"closed workspace"* ]]
  [[ "$output" != *"keeping workspace"* ]]
}

# ---------- build-gc path ----------

@test "build-gc closes workspace of removed old run" {
  OLD=$("$MANIFEST" gen-run-id "gcold")
  "$MANIFEST" init "$OLD" "gcold"
  "$MANIFEST" update "$OLD" '.options.workspace_id = "workspace:42"'
  if touch -t $(date -j -v-40d +%Y%m%d0000) ".pipeline/runs/$OLD" 2>/dev/null; then :
  else touch -d "40 days ago" ".pipeline/runs/$OLD"
  fi

  run "$BUILD_GC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"closed workspace workspace:42"* ]]
  [[ "$output" == *"removing"* ]]
  grep -q '^close workspace:42$' "$CMUX_LOG"
  [ ! -d ".pipeline/runs/$OLD" ]
}

@test "build-gc skips workspace close when manifest has no workspace_id" {
  OLD=$("$MANIFEST" gen-run-id "gcnone")
  "$MANIFEST" init "$OLD" "gcnone"
  if touch -t $(date -j -v-40d +%Y%m%d0000) ".pipeline/runs/$OLD" 2>/dev/null; then :
  else touch -d "40 days ago" ".pipeline/runs/$OLD"
  fi

  run "$BUILD_GC"
  [ "$status" -eq 0 ]
  ! grep -q '^close ' "$CMUX_LOG"
  [ ! -d ".pipeline/runs/$OLD" ]
}

# ---------- preflight orphan sweep ----------

@test "preflight closes orphan workspace whose manifest is missing" {
  cat > "$CMUX_LIST_FIXTURE" <<'EOF'
* workspace:11  ✳ Claude Code  [selected]
  workspace:200  cmux-pipeline:20260101-9999-ghost
  workspace:201  postgres-ec2-migration
EOF
  run "$PREFLIGHT" --no-plugin-check
  [ "$status" -eq 0 ]
  [[ "$output" == *"cleaned up 1 orphan workspace"* ]]
  grep -q '^close workspace:200$' "$CMUX_LOG"
  ! grep -q '^close workspace:201$' "$CMUX_LOG"
}

@test "preflight closes orphan workspace whose manifest is completed" {
  RUN_ID="20260508-1300-doneghost"
  "$MANIFEST" init "$RUN_ID" "doneghost"
  "$MANIFEST" update "$RUN_ID" '.status = "completed"'
  cat > "$CMUX_LIST_FIXTURE" <<EOF
* workspace:11  ✳ Claude Code  [selected]
  workspace:300  cmux-pipeline:$RUN_ID
EOF
  run "$PREFLIGHT" --no-plugin-check
  [ "$status" -eq 0 ]
  grep -q '^close workspace:300$' "$CMUX_LOG"
}

@test "preflight preserves workspace whose manifest is paused" {
  RUN_ID="20260508-1301-livepaused"
  "$MANIFEST" init "$RUN_ID" "livepaused"
  "$MANIFEST" update "$RUN_ID" '.status = "paused"'
  cat > "$CMUX_LIST_FIXTURE" <<EOF
* workspace:11  ✳ Claude Code  [selected]
  workspace:400  cmux-pipeline:$RUN_ID
EOF
  run "$PREFLIGHT" --no-plugin-check
  [ "$status" -eq 0 ]
  ! grep -q '^close workspace:400$' "$CMUX_LOG"
  [[ "$output" != *"cleaned up"* ]]
}

@test "preflight --no-orphan-cleanup skips the sweep entirely" {
  cat > "$CMUX_LIST_FIXTURE" <<'EOF'
* workspace:11  ✳ Claude Code  [selected]
  workspace:500  cmux-pipeline:20260101-7777-skipme
EOF
  run "$PREFLIGHT" --no-plugin-check --no-orphan-cleanup
  [ "$status" -eq 0 ]
  ! grep -q '^close workspace:500$' "$CMUX_LOG"
}
