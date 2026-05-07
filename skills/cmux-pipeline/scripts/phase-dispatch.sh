#!/usr/bin/env bash
# scripts/phase-dispatch.sh — send a phase prompt to a pane and wait for sentinel.
#
# Thin orchestrator over pane-send.sh + pane-wait.sh:
#   1. Read prompt from .pipeline/runs/<run-id>/phases/<phase-id>/prompt.md
#   2. Send via pane-send.sh
#   3. Poll for sentinel via pane-wait.sh
#   4. Echo sentinel status (SUCCESS/NEEDS_HELP/FAILED) on stdout
#
# Sentinel format: ==DONE==<run-id>==phase-<phase-id>==<status>==
#
# Usage:
#   phase-dispatch.sh --pane <ref> --run-id <id> --phase-id <id>
#                     [--timeout <sec>] [--poll <sec>]
#
# Output: SUCCESS | NEEDS_HELP | FAILED on stdout when detected.
# Exit codes:
#   0    sentinel detected (status echoed on stdout)
#   1    setup error (missing flag, missing prompt file, send failure)
#   2    bad CLI usage (unknown flag, missing arg value)
#   124  timeout (propagated from pane-wait.sh)

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: phase-dispatch.sh --pane <ref> --run-id <id> --phase-id <id> [options]

Send the phase's prompt.md to a cmux pane and poll for a sentinel marker
matching: ==DONE==<run-id>==phase-<phase-id>==(SUCCESS|NEEDS_HELP|FAILED)==

Required:
  --pane <pane:N|surface:N|UUID>   Target codex pane
  --run-id <id>                    Run identifier
  --phase-id <id>                  Phase identifier

Options:
  --timeout <seconds>              Max wait time (default: 1200)
  --poll <seconds>                 Poll interval (default: 5)
  --help, -h                       Show this help and exit 0

Reads:  $PIPELINE_ROOT/<run-id>/phases/<phase-id>/prompt.md
        (PIPELINE_ROOT defaults to .pipeline/runs)

Output: SUCCESS | NEEDS_HELP | FAILED on stdout when detected.
Exit:   0 detected, 124 timeout, 1 setup error, 2 bad usage.
USAGE
}

PANE=""
RUN_ID=""
PHASE_ID=""
TIMEOUT=1200
POLL=5

while [ $# -gt 0 ]; do
  case "$1" in
    --pane)
      [ $# -ge 2 ] || { echo "phase-dispatch: --pane requires a value" >&2; exit 2; }
      PANE="$2"; shift 2
      ;;
    --run-id)
      [ $# -ge 2 ] || { echo "phase-dispatch: --run-id requires a value" >&2; exit 2; }
      RUN_ID="$2"; shift 2
      ;;
    --phase-id)
      [ $# -ge 2 ] || { echo "phase-dispatch: --phase-id requires a value" >&2; exit 2; }
      PHASE_ID="$2"; shift 2
      ;;
    --timeout)
      [ $# -ge 2 ] || { echo "phase-dispatch: --timeout requires a value" >&2; exit 2; }
      TIMEOUT="$2"; shift 2
      ;;
    --poll)
      [ $# -ge 2 ] || { echo "phase-dispatch: --poll requires a value" >&2; exit 2; }
      POLL="$2"; shift 2
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      echo "phase-dispatch: unknown flag: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -z "$PANE" ]     && { echo "phase-dispatch: --pane is required" >&2; exit 1; }
[ -z "$RUN_ID" ]   && { echo "phase-dispatch: --run-id is required" >&2; exit 1; }
[ -z "$PHASE_ID" ] && { echo "phase-dispatch: --phase-id is required" >&2; exit 1; }

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"
PROMPT_FILE="$PIPELINE_ROOT/$RUN_ID/phases/$PHASE_ID/prompt.md"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "phase-dispatch: prompt.md not found: $PROMPT_FILE" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SEND="$SCRIPT_DIR/pane-send.sh"
WAIT="$SCRIPT_DIR/pane-wait.sh"

# Read prompt body once (preserves embedded newlines via command substitution
# stripping only the trailing newline, which pane-send handles correctly).
prompt_text=$(cat "$PROMPT_FILE")

# Send the prompt to the pane. Errors are surfaced by pane-send.sh on stderr.
if ! "$SEND" --pane "$PANE" --text "$prompt_text"; then
  echo "phase-dispatch: pane-send failed" >&2
  exit 1
fi

# Wait for the sentinel; pane-wait echoes status on stdout and propagates
# its own exit code (0 detected, 124 timeout, 1 resolution failure, 2 bad usage).
"$WAIT" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE_ID" \
        --timeout "$TIMEOUT" --poll "$POLL"
