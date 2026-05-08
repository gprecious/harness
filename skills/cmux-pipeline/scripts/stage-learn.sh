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
# Use `find` for bash 3.2+ portability — `shopt -s globstar` is bash 4+ only.
artifacts=()
if [ -d "$WISDOM_ROOT" ]; then
  while IFS= read -r f; do
    artifacts+=("\"$f\"")
  done < <(find "$WISDOM_ROOT" -type f -name '*.md' ! -name 'index.md' | LC_ALL=C sort)
fi

if [ "${#artifacts[@]}" -eq 0 ]; then
  echo "stage-learn: no wisdom artifacts under $WISDOM_ROOT" >&2
  exit 1
fi

artifacts_json="[$(IFS=,; echo "${artifacts[*]}")]"

"$MANIFEST" update "$RUN_ID" \
  ".stages.learn.status = \"completed\" | .stages.learn.artifacts = $artifacts_json"

echo "stage-learn: marked completed for $RUN_ID (${#artifacts[@]} artifact(s))"

# Auto-close the run's dedicated cmux workspace unless the user opted to keep
# it for post-mortem inspection (--keep-workspace → manifest.options.keep_workspace).
# The workspace was created by workspace-create.sh at Stage 4 entry; closing it
# here is the symmetric teardown for the normal DONE path.
WORKSPACE_CLOSE="$SCRIPT_DIR/workspace-close.sh"
KEEP=$("$MANIFEST" read "$RUN_ID" '.options.keep_workspace // false' 2>/dev/null || echo "false")
WORKSPACE_REF=$("$MANIFEST" read "$RUN_ID" '.options.workspace_id // empty' 2>/dev/null || echo "")

if [ "$KEEP" = "true" ]; then
  if [ -n "$WORKSPACE_REF" ]; then
    echo "stage-learn: keeping workspace $WORKSPACE_REF (--keep-workspace)"
  fi
elif [ -n "$WORKSPACE_REF" ]; then
  if [ -x "$WORKSPACE_CLOSE" ] && command -v cmux >/dev/null 2>&1; then
    if "$WORKSPACE_CLOSE" --workspace "$WORKSPACE_REF" 2>/dev/null; then
      echo "stage-learn: closed workspace $WORKSPACE_REF"
    fi
  fi
fi
