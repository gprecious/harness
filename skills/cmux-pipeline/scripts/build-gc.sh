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

# Validate DAYS is a non-negative integer
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "build-gc: <days> must be a non-negative integer; got: $DAYS" >&2
  exit 1
fi

[ -d "$PIPELINE_ROOT" ] || exit 0

# find -mtime +N is "modified more than N*24h ago" on both BSD and GNU find.
find "$PIPELINE_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime "+$DAYS" -print | \
while read -r dir; do
  echo "gc: removing $dir"
  rm -rf "$dir"
done
