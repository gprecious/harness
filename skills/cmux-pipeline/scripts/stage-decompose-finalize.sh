#!/usr/bin/env bash
# scripts/stage-decompose-finalize.sh — collect GSD output into
# .pipeline/runs/<run-id>/decompose/{phases,...} and update manifest.json's
# stages.decompose.{status, phase_count, phase_dirs}.
#
# Usage:
#   stage-decompose-finalize.sh <run-id> [<gsd-planning-dir>]
#
# Defaults to ./.planning when <gsd-planning-dir> omitted.
#
# Per notes/external-skills-io.md, GSD writes:
#   .planning/phases/{padded_phase}-{phase_slug}/{padded_phase}-{NN}-PLAN.md
#   .planning/phases/{padded_phase}-{phase_slug}/{padded_phase}-CONTEXT.md
#   .planning/phases/{padded_phase}-{phase_slug}/{padded_phase}-RESEARCH.md
#   .planning/{PROJECT,REQUIREMENTS,ROADMAP,STATE}.md (top-level refs)
#   .planning/{research,codebase}/*.md (optional reference docs — not copied)
# We copy phases/* and the top-level *.md ref docs (not nested research/codebase).
#
# Env overrides (mainly for tests):
#   PIPELINE_ROOT    Pipeline runs root (default: .pipeline/runs)

set -uo pipefail

RUN_ID="${1:-}"
PLANNING="${2:-.planning}"

if [ -z "$RUN_ID" ]; then
  echo "stage-decompose-finalize: <run-id> required" >&2
  echo "Usage: stage-decompose-finalize.sh <run-id> [<gsd-planning-dir>]" >&2
  exit 1
fi

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"
DECOMPOSE_DIR="$PIPELINE_ROOT/$RUN_ID/decompose"
PHASES_DEST="$DECOMPOSE_DIR/phases"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MANIFEST="$SCRIPT_DIR/manifest.sh"

if [ ! -d "$PLANNING/phases" ]; then
  echo "stage-decompose-finalize: $PLANNING/phases not found" >&2
  exit 1
fi

mkdir -p "$PHASES_DEST"

# Walk phase dirs deterministically (sorted by basename).
phase_dirs=()
count=0
shopt -s nullglob
for d in "$PLANNING/phases"/*/; do
  [ -d "$d" ] || continue
  # Strip trailing slash so BSD `cp -R` copies the dir itself, not its contents.
  src="${d%/}"
  base=$(basename "$src")
  cp -R "$src" "$PHASES_DEST/"
  phase_dirs+=("\"decompose/phases/$base\"")
  count=$((count + 1))
done
shopt -u nullglob

if [ "$count" -eq 0 ]; then
  echo "stage-decompose-finalize: no phase dirs in $PLANNING/phases" >&2
  exit 1
fi

# Copy top-level reference docs (PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md).
for ref in PROJECT.md REQUIREMENTS.md ROADMAP.md STATE.md; do
  [ -f "$PLANNING/$ref" ] && cp "$PLANNING/$ref" "$DECOMPOSE_DIR/"
done

dirs_json="[$(IFS=,; echo "${phase_dirs[*]}")]"

"$MANIFEST" update "$RUN_ID" \
  ".stages.decompose.status = \"completed\" | .stages.decompose.phase_count = $count | .stages.decompose.phase_dirs = $dirs_json"

echo "stage-decompose-finalize: copied $count phase dir(s) to $PHASES_DEST"
