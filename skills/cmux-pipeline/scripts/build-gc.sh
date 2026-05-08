#!/usr/bin/env bash
# scripts/build-gc.sh — delete run directories older than N days (default 30).
#
# Walks .pipeline/runs/ and removes immediate child directories whose mtime is
# older than <days> days. Prints "gc: removing <dir>" for each one removed.

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: build-gc.sh [<days>]

Delete run directories in .pipeline/runs/ older than <days> by mtime.
Default <days> = 30.

Options:
  --help, -h    Show this help.
USAGE
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
esac

DAYS="${1:-30}"
PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
WORKSPACE_CLOSE="$SCRIPT_DIR/workspace-close.sh"

# Validate DAYS is a non-negative integer
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "build-gc: <days> must be a non-negative integer; got: $DAYS" >&2
  exit 1
fi

[ -d "$PIPELINE_ROOT" ] || exit 0

# Close any cmux workspace recorded in the run's manifest before removing the
# directory. Without this, gc would orphan workspaces in the running cmux
# instance — they'd linger forever since the manifest pointer is gone.
close_workspace_for_dir() {
  local dir="$1"
  local manifest="$dir/manifest.json"
  [ -f "$manifest" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  command -v cmux >/dev/null 2>&1 || return 0
  [ -x "$WORKSPACE_CLOSE" ] || return 0
  local ws
  ws=$(jq -r '.options.workspace_id // empty' "$manifest" 2>/dev/null || echo "")
  [ -n "$ws" ] || return 0
  if "$WORKSPACE_CLOSE" --workspace "$ws" >/dev/null 2>&1; then
    echo "gc: closed workspace $ws (from $(basename "$dir"))"
  fi
}

# find -mtime +N is "modified more than N*24h ago" on both BSD and GNU find.
find "$PIPELINE_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime "+$DAYS" -print | \
while read -r dir; do
  close_workspace_for_dir "$dir"
  echo "gc: removing $dir"
  rm -rf "$dir"
done
