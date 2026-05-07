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

jq '{
  run_id: .run_id,
  topic: .topic,
  resume_from: .checkpoints.paused_at,
  worker_pane_id: .stages.loop.worker_pane_id,
  options: .options
}' "$f"
