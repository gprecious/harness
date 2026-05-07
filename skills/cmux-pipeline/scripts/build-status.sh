#!/usr/bin/env bash
# scripts/build-status.sh — print manifest of one run, or summary table of all runs.

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: build-status.sh [<run-id>]

  No args        Print summary table of all runs.
  <run-id>       Pretty-print that run's manifest.json (jq).
USAGE
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
esac

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LIST="$SCRIPT_DIR/build-list.sh"

if [ $# -eq 0 ]; then
  if [ ! -d "$PIPELINE_ROOT" ]; then
    echo "(no runs)"
    exit 0
  fi
  printf "%-40s %-12s %s\n" "RUN_ID" "STATUS" "STARTED"
  for rid in $("$LIST"); do
    f="$PIPELINE_ROOT/$rid/manifest.json"
    [ -f "$f" ] || continue
    status=$(jq -r '.status // "?"' "$f")
    started=$(jq -r '.started_at // "?"' "$f")
    cur=$(jq -r '.stages.loop.current_phase // "-"' "$f")
    printf "%-40s %-12s %s phase=%s\n" "$rid" "$status" "$started" "$cur"
  done
  exit 0
fi

RUN_ID="$1"
f="$PIPELINE_ROOT/$RUN_ID/manifest.json"
if [ ! -f "$f" ]; then
  echo "build-status: no such run: $RUN_ID" >&2
  exit 1
fi
jq . "$f"
