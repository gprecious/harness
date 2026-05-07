#!/usr/bin/env bash
# scripts/build-list.sh — list all cmux-pipeline run-ids, one per line.

set -uo pipefail

usage() {
  echo "Usage: build-list.sh"
  echo ""
  echo "Print all run-ids in .pipeline/runs/, one per line, sorted."
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  "") ;;
  *) echo "build-list: unexpected arg: $1" >&2; usage >&2; exit 2 ;;
esac

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"
[ -d "$PIPELINE_ROOT" ] || exit 0
ls -1 "$PIPELINE_ROOT" 2>/dev/null | sort
