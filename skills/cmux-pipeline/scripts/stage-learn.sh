#!/usr/bin/env bash
# scripts/stage-learn.sh — finalize Stage 6 (learn).
#
# Pre-condition: claude orch has dispatched the wisdom-extractor agent
# (see references/stage-learn.md), which has written wisdom artifacts under
# docs/wisdom/{patterns,decisions,evaluations,test-recipes}/.
#
# This script counts new wisdom files and records them in manifest.json:
#   .stages.learn.status    = "completed"
#   .stages.learn.artifacts = ["docs/wisdom/patterns/<file>.md", ...]
#
# Usage:
#   stage-learn.sh <run-id>
#
# Env overrides (mainly for tests):
#   PIPELINE_ROOT  Pipeline runs root (default: .pipeline/runs)
#   WISDOM_ROOT    Wisdom output root (default: docs/wisdom)

set -uo pipefail

RUN_ID="${1:-}"
if [ -z "$RUN_ID" ]; then
  echo "stage-learn: <run-id> required" >&2
  echo "Usage: stage-learn.sh <run-id>" >&2
  exit 1
fi

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"
WISDOM_ROOT="${WISDOM_ROOT:-docs/wisdom}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MANIFEST="$SCRIPT_DIR/manifest.sh"

# Collect wisdom artifacts (any *.md under WISDOM_ROOT, excluding index.md).
artifacts=()
shopt -s nullglob globstar
for f in "$WISDOM_ROOT"/**/*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  [ "$base" = "index.md" ] && continue
  artifacts+=("\"$f\"")
done
shopt -u nullglob globstar

if [ "${#artifacts[@]}" -eq 0 ]; then
  echo "stage-learn: no wisdom artifacts under $WISDOM_ROOT" >&2
  exit 1
fi

artifacts_json="[$(IFS=,; echo "${artifacts[*]}")]"

"$MANIFEST" update "$RUN_ID" \
  ".stages.learn.status = \"completed\" | .stages.learn.artifacts = $artifacts_json"

echo "stage-learn: marked completed for $RUN_ID (${#artifacts[@]} artifact(s))"
