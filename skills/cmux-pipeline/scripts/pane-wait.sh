#!/usr/bin/env bash
# pane-wait.sh — poll for a sentinel marker in a cmux pane's screen buffer
#
# Sentinel format: ==DONE==<run-id>==phase-<phase-id>==<status>==
# where <status> is one of: SUCCESS | NEEDS_HELP | FAILED.
#
# Usage:
#   pane-wait.sh --pane <ref> --run-id <id> --phase-id <id> \
#                [--timeout <seconds>] [--poll <seconds>]
#
# cmux 0.62.2 notes:
#   - read-screen takes --surface (NOT --pane). We resolve pane:N -> surface:N
#     via lib/resolve-surface.sh.
#
# Output: SUCCESS | NEEDS_HELP | FAILED on stdout when detected.
# Exit:
#   0   sentinel detected (status echoed on stdout)
#   1   missing required flag, or surface resolution failed
#   2   bad CLI usage (unknown flag)
#  124  timeout expired without detection (matches GNU `timeout` convention)

set -uo pipefail

PANE=""
RUN_ID=""
PHASE_ID=""
TIMEOUT=1200
POLL=5

usage() {
  cat <<'USAGE'
Usage: pane-wait.sh --pane <ref> --run-id <id> --phase-id <id> [options]

Poll a cmux pane's screen buffer for a sentinel marker matching:
  ==DONE==<run-id>==phase-<phase-id>==(SUCCESS|NEEDS_HELP|FAILED)==

Required:
  --pane <pane:N|surface:N|UUID>   Target pane or surface ref
  --run-id <id>                    Run identifier embedded in the sentinel
  --phase-id <id>                  Phase identifier embedded in the sentinel

Options:
  --timeout <seconds>              Max wait time (default: 1200)
  --poll <seconds>                 Poll interval (default: 5)
  --help, -h                       Show this help and exit 0

Exit codes:
  0    sentinel detected (SUCCESS / NEEDS_HELP / FAILED echoed on stdout)
  1    missing required flag, or surface resolution failed
  2    bad CLI usage (unknown flag)
  124  timeout expired
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --pane)
      [ $# -ge 2 ] || { echo "pane-wait: --pane requires a value" >&2; exit 2; }
      PANE="$2"; shift 2
      ;;
    --run-id)
      [ $# -ge 2 ] || { echo "pane-wait: --run-id requires a value" >&2; exit 2; }
      RUN_ID="$2"; shift 2
      ;;
    --phase-id)
      [ $# -ge 2 ] || { echo "pane-wait: --phase-id requires a value" >&2; exit 2; }
      PHASE_ID="$2"; shift 2
      ;;
    --timeout)
      [ $# -ge 2 ] || { echo "pane-wait: --timeout requires a value" >&2; exit 2; }
      TIMEOUT="$2"; shift 2
      ;;
    --poll)
      [ $# -ge 2 ] || { echo "pane-wait: --poll requires a value" >&2; exit 2; }
      POLL="$2"; shift 2
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      echo "pane-wait: unknown flag: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -z "$PANE" ]     && { echo "pane-wait: --pane is required" >&2; exit 1; }
[ -z "$RUN_ID" ]   && { echo "pane-wait: --run-id is required" >&2; exit 1; }
[ -z "$PHASE_ID" ] && { echo "pane-wait: --phase-id is required" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/resolve-surface.sh"

SURFACE=$(resolve_surface "$PANE") || exit 1

# Sentinel: ==DONE==<run-id>==phase-<phase-id>==<status>==
# Use grep -E with a precise regex so wrong run-id / wrong phase-id are ignored.
sentinel_re="==DONE==${RUN_ID}==phase-${PHASE_ID}==(SUCCESS|NEEDS_HELP|FAILED)=="

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  screen=$(cmux read-screen --surface "$SURFACE" --lines 300 2>/dev/null || echo "")
  match=$(printf '%s\n' "$screen" | grep -oE "$sentinel_re" | tail -1)
  if [ -n "$match" ]; then
    status=$(printf '%s\n' "$match" | sed -E 's/.*==(SUCCESS|NEEDS_HELP|FAILED)==.*/\1/')
    echo "$status"
    exit 0
  fi
  sleep "$POLL"
  elapsed=$((elapsed + POLL))
done

echo "TIMEOUT" >&2
exit 124
