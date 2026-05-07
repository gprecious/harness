#!/usr/bin/env bash
# scripts/pane-close.sh — close a cmux pane (idempotent)
#
# cmux 0.62.2: `close-surface --surface <ref>` is the actual close command.
# We accept either pane:N or surface:N via --pane flag and resolve internally
# via lib/resolve-surface.sh (DRY with sibling pane-* scripts).
#
# Idempotent contract: closing a nonexistent pane exits 0 without error.
# This makes it safe to call from cleanup paths and orchestrators that may
# not know whether a pane is still open.
#
# Usage:
#   pane-close.sh --pane <pane:N|surface:N|UUID> [--help]
#
# Exit codes:
#   0  Closed (or already gone)
#   1  --pane missing
#   2  Unknown flag

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: pane-close.sh --pane <ref> [--help]

Close a cmux pane (or surface). Idempotent: nonexistent panes exit 0.

Required:
  --pane <pane:N|surface:N|UUID>   Pane or surface ref to close

Options:
  --help, -h                       Show this help and exit 0

Exit codes:
  0  Success (closed or already gone)
  1  --pane missing
  2  Unknown flag
USAGE
}

PANE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pane)
      [ $# -ge 2 ] || { echo "pane-close: --pane requires a value" >&2; exit 2; }
      PANE="$2"; shift 2
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      echo "pane-close: unknown flag: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -z "$PANE" ] && { echo "pane-close: --pane is required" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/resolve-surface.sh"

# Try to resolve to surface. If it fails (pane already gone or invalid),
# return 0 — idempotency is the contract.
SURFACE=$(resolve_surface "$PANE" 2>/dev/null) || exit 0

# Close. Suppress errors — if the surface vanishes between resolve and close,
# we still return 0 (idempotent contract).
cmux close-surface --surface "$SURFACE" >/dev/null 2>&1 || true
exit 0
