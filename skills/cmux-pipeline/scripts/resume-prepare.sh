#!/usr/bin/env bash
# scripts/resume-prepare.sh — emit JSON metadata for resuming a paused/failed run.
#
# Usage:
#   resume-prepare.sh <run-id>
#
# Output (JSON to stdout):
#   { "run_id": "...", "topic": "...", "resume_from": "...",
#     "worker_pane_id": "...", "options": {...} }

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: resume-prepare.sh <run-id>

Print JSON metadata for resuming a paused or failed run.
Errors if run is not in a resumable state.
USAGE
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  "") echo "resume-prepare: <run-id> required" >&2; usage >&2; exit 1 ;;
esac

RUN_ID="$1"
PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"
f="$PIPELINE_ROOT/$RUN_ID/manifest.json"
[ -f "$f" ] || { echo "resume-prepare: no such run: $RUN_ID" >&2; exit 1; }

status=$(jq -r .status "$f")
case "$status" in
  paused|failed) ;;
  *) echo "resume-prepare: run is not resumable: status=$status" >&2; exit 1 ;;
esac

# Resolve resume_from:
#   1. If checkpoints.paused_at is non-null, use it (preserves existing
#      fine-grained checkpoints like "loop:03-routes").
#   2. Otherwise, walk the canonical stage sequence and pick the first
#      stage whose status != "completed". Treats missing stages (e.g. on
#      a schema_version 1 manifest) as pending.
jq '
  . as $m
  | {
      run_id: .run_id,
      topic: .topic,
      resume_from: (
        if (.checkpoints.paused_at // null) != null then
          .checkpoints.paused_at
        else
          (["spec","decompose","contract","loop","integrate","learn"]
           | map(select((($m.stages[.].status) // "pending") != "completed"))
           | .[0])
        end
      ),
      worker_pane_id: .stages.loop.worker_pane_id,
      options: .options
    }
' "$f"
