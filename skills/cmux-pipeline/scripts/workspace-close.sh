#!/usr/bin/env bash
# scripts/workspace-close.sh — close a cmux workspace, idempotent
#
# Wraps `cmux close-workspace --workspace <ref>`. Closing a workspace closes
# every pane inside it in a single operation, so this is the cleanup primitive
# for isolated workspaces created by workspace-create.sh.
#
# Idempotent: closing a non-existent workspace exits 0 with a soft message.
# This matches pane-close.sh's contract and makes teardown safe to call from
# trap EXIT INT TERM without "already closed" failure cascades.
#
# Usage:
#   workspace-close.sh --workspace <ref> [--help]

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: workspace-close.sh --workspace <ref> [--help]

Close a cmux workspace and all panes inside it. Idempotent — closing a
nonexistent workspace exits 0.

Required:
  --workspace <id|ref>   Workspace to close

Options:
  --help, -h             Show this help and exit 0

Exit codes:
  0  Workspace closed (or already closed).
  2  Bad CLI usage (unknown flag, missing arg).
  *  Propagated from cmux on unexpected failure.
USAGE
}

WORKSPACE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --workspace)
      [ $# -ge 2 ] || { echo "workspace-close: --workspace requires a value" >&2; exit 2; }
      WORKSPACE="$2"; shift 2
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      echo "workspace-close: unknown flag: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -z "$WORKSPACE" ] && { echo "workspace-close: --workspace is required" >&2; exit 2; }

# cmux close-workspace exits non-zero on already-closed; map that to 0.
if cmux close-workspace --workspace "$WORKSPACE" >/dev/null 2>&1; then
  exit 0
fi

# Verify it's actually gone (idempotent path). If list-workspaces still shows
# it, something else failed — surface the original error.
if ! cmux list-workspaces 2>/dev/null | grep -qF "$WORKSPACE"; then
  exit 0
fi

# Re-run with output so the caller sees the real error.
cmux close-workspace --workspace "$WORKSPACE" >&2
exit $?
