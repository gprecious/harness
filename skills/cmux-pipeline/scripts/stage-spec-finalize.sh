#!/usr/bin/env bash
# scripts/stage-spec-finalize.sh — collect GStack output into .pipeline/runs/<run-id>/spec/
# and update manifest.json's stages.spec.{status, outputs, primary_design}.
#
# Usage:
#   stage-spec-finalize.sh <run-id> [<gstack-output-dir>]
#
# When <gstack-output-dir> is omitted, the script auto-discovers via gstack-slug:
#   eval "$($GSTACK_SLUG_BIN)"   # sets SLUG=...
#   GSTACK_OUT="$HOME/.gstack/projects/$SLUG"
#
# Per notes/external-skills-io.md, GStack writes:
#   ~/.gstack/projects/<slug>/<user>-<branch>-design-<datetime>.md     (office-hours)
#   ~/.gstack/projects/<slug>/<branch>-autoplan-restore-<datetime>.md  (autoplan)
#   ~/.gstack/projects/<slug>/<user>-<branch>-test-plan-<datetime>.md  (autoplan)
# We copy all *.md files; the most recent *-design-*.md by mtime is recorded
# as stages.spec.primary_design.
#
# Env overrides (mainly for tests):
#   GSTACK_SLUG_BIN  Path to gstack-slug (default: ~/.claude/skills/gstack/bin/gstack-slug)
#   PIPELINE_ROOT    Pipeline runs root (default: .pipeline/runs)

set -uo pipefail

RUN_ID="${1:-}"
GSTACK_OUT="${2:-}"

if [ -z "$RUN_ID" ]; then
  echo "stage-spec-finalize: <run-id> required" >&2
  echo "Usage: stage-spec-finalize.sh <run-id> [<gstack-output-dir>]" >&2
  exit 1
fi

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"
SPEC_DIR="$PIPELINE_ROOT/$RUN_ID/spec"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MANIFEST="$SCRIPT_DIR/manifest.sh"
GSTACK_SLUG_BIN="${GSTACK_SLUG_BIN:-$HOME/.claude/skills/gstack/bin/gstack-slug}"

# Auto-discovery via gstack-slug when no explicit dir.
if [ -z "$GSTACK_OUT" ]; then
  if [ ! -x "$GSTACK_SLUG_BIN" ]; then
    echo "stage-spec-finalize: gstack-slug not executable at $GSTACK_SLUG_BIN — pass <gstack-output-dir> explicitly" >&2
    exit 1
  fi
  # gstack-slug prints "SLUG=...\nBRANCH=..." — eval to set SLUG locally.
  SLUG=""
  eval "$("$GSTACK_SLUG_BIN")" || true
  if [ -z "${SLUG:-}" ]; then
    echo "stage-spec-finalize: gstack-slug did not produce a SLUG" >&2
    exit 1
  fi
  GSTACK_OUT="$HOME/.gstack/projects/$SLUG"
fi

if [ ! -d "$GSTACK_OUT" ]; then
  echo "stage-spec-finalize: gstack-out dir not found: $GSTACK_OUT" >&2
  exit 1
fi

mkdir -p "$SPEC_DIR"

# Copy all *.md files. Use nullglob so an empty match yields no iterations.
shopt -s nullglob
md_files=("$GSTACK_OUT"/*.md)
shopt -u nullglob

if [ ${#md_files[@]} -eq 0 ]; then
  echo "stage-spec-finalize: no .md files in $GSTACK_OUT" >&2
  exit 1
fi

outputs=()
for f in "${md_files[@]}"; do
  cp "$f" "$SPEC_DIR/"
  outputs+=("\"spec/$(basename "$f")\"")
done

# Identify primary design doc — most recent *-design-*.md by mtime.
# `ls -t` is portable across BSD/GNU; first hit wins.
primary_basename=""
shopt -s nullglob
design_files=("$GSTACK_OUT"/*-design-*.md)
shopt -u nullglob
if [ ${#design_files[@]} -gt 0 ]; then
  # Pipe through ls -t to mtime-sort; head -1 picks the newest.
  primary_path=$(ls -t "${design_files[@]}" 2>/dev/null | head -1)
  [ -n "$primary_path" ] && primary_basename=$(basename "$primary_path")
fi

outputs_json="[$(IFS=,; echo "${outputs[*]}")]"

if [ -n "$primary_basename" ]; then
  "$MANIFEST" update "$RUN_ID" \
    ".stages.spec.status = \"completed\" | .stages.spec.outputs = $outputs_json | .stages.spec.primary_design = \"spec/$primary_basename\""
else
  "$MANIFEST" update "$RUN_ID" \
    ".stages.spec.status = \"completed\" | .stages.spec.outputs = $outputs_json"
fi

echo "stage-spec-finalize: copied ${#outputs[@]} file(s) to $SPEC_DIR"
[ -n "$primary_basename" ] && echo "stage-spec-finalize: primary design = spec/$primary_basename"
