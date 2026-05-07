#!/usr/bin/env bash
# scripts/workspace-create.sh — create a new cmux workspace and emit its ref
#
# Wraps `cmux --id-format both new-workspace --cwd <path>`. The new workspace
# does NOT steal focus — the currently-focused workspace stays focused, so
# the user's view isn't disrupted by pipeline activity. All subsequent
# pane-create calls should target this workspace ref via --workspace.
#
# Why a wrapper:
#   - Parses the `OK workspace:N` line to a single token on stdout
#   - Optionally renames via `workspace-action --action rename --title <text>`
#     so the workspace is identifiable in `cmux list-workspaces` (e.g. as
#     "cmux-pipeline:<run-id>" instead of the cmux default "Terminal N")
#
# Usage:
#   workspace-create.sh --cwd <path> [--title <text>] [--help]
#
# Output:
#   On success: prints `workspace:N` on stdout, exits 0.
#   On failure: writes diagnostic to stderr, exits non-zero.
#
# Cleanup:
#   workspace-close.sh --workspace <ref>

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: workspace-create.sh --cwd <path> [--title <text>] [--help]

Create a new isolated cmux workspace for cmux-pipeline activity and emit
its `workspace:N` ref on stdout. Does NOT steal focus from the user's
currently focused workspace.

Required:
  --cwd <path>     Working directory the new workspace opens in

Options:
  --title <text>   Rename the workspace (default: cmux's auto-name)
  --help, -h       Show this help and exit 0

Exit codes:
  0  Created; ref printed on stdout.
  1  Missing required value, or cmux returned 0 but output was unparseable.
  2  Bad CLI usage (unknown flag, missing arg).
  *  Propagated from cmux on failure.
USAGE
}

CWD=""
TITLE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --cwd)
      [ $# -ge 2 ] || { echo "workspace-create: --cwd requires a value" >&2; exit 2; }
      CWD="$2"; shift 2
      ;;
    --title)
      [ $# -ge 2 ] || { echo "workspace-create: --title requires a value" >&2; exit 2; }
      TITLE="$2"; shift 2
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      echo "workspace-create: unknown flag: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -z "$CWD" ] && { echo "workspace-create: --cwd is required" >&2; exit 1; }
[ -d "$CWD" ] || { echo "workspace-create: --cwd not a directory: $CWD" >&2; exit 1; }

output=$(cmux --id-format both new-workspace --cwd "$CWD" 2>&1)
exit_code=$?

if [ "$exit_code" -ne 0 ]; then
  echo "workspace-create: cmux new-workspace failed (exit $exit_code):" >&2
  echo "$output" >&2
  exit "$exit_code"
fi

ref=$(printf '%s\n' "$output" | grep -oE 'workspace:[0-9]+' | head -1)

if [ -z "$ref" ]; then
  echo "workspace-create: could not parse workspace ref from cmux output:" >&2
  echo "$output" >&2
  exit 1
fi

# Optional rename. Failure here is non-fatal — the workspace exists either way.
if [ -n "$TITLE" ]; then
  cmux workspace-action --workspace "$ref" --action rename --title "$TITLE" \
    >/dev/null 2>&1 || true
fi

echo "$ref"
exit 0
