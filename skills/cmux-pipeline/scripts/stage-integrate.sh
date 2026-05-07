#!/usr/bin/env bash
# scripts/stage-integrate.sh — Stage 4 integrate state transitions.
#
# Subcommands:
#   complete <run-id>            Mark integrate + top-level as completed
#   fail <run-id> <reason>       Mark integrate failed; paused at "integrate"

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: stage-integrate.sh <subcommand>

Subcommands:
  complete <run-id>             Mark integrate + top-level status = completed
  fail <run-id> <reason>        Mark paused with paused_at = "integrate" and reason
USAGE
}

CMD="${1:-}"
case "$CMD" in
  --help|-h) usage; exit 0 ;;
  "")        usage >&2; exit 1 ;;
esac

RUN_ID="${2:-}"
[ -z "$RUN_ID" ] && { echo "stage-integrate: <run-id> required" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MANIFEST="$SCRIPT_DIR/manifest.sh"

case "$CMD" in
  complete)
    "$MANIFEST" update "$RUN_ID" \
      '.stages.integrate.status = "completed" | .status = "completed"'
    ;;
  fail)
    REASON="${3:-}"
    [ -z "$REASON" ] && { echo "stage-integrate fail: <reason> required" >&2; exit 1; }
    # manifest.sh forwards the expr verbatim to jq, so we inline the reason.
    # Escape any double quotes in reason to avoid breaking the jq string literal.
    REASON_ESCAPED=$(printf '%s' "$REASON" | sed 's/"/\\"/g')
    "$MANIFEST" update "$RUN_ID" \
      ".stages.integrate.status = \"failed\"
       | .status = \"paused\"
       | .checkpoints.paused_at = \"integrate\"
       | .checkpoints.paused_reason = \"$REASON_ESCAPED\""
    ;;
  *)
    echo "stage-integrate: unknown subcommand: $CMD" >&2
    usage >&2
    exit 2
    ;;
esac
