#!/usr/bin/env bash
# scripts/phase-dispatch.sh — send a phase prompt to a pane and wait for sentinel.
#
# Thin orchestrator over pane-send.sh + pane-wait.sh:
#   1. Read prompt from .pipeline/runs/<run-id>/phases/<phase-id>/prompt.md
#   2. Send to codex via single-line file-reference message (default) or
#      raw multi-line text (--mode=raw, deprecated).
#   3. Poll for sentinel via pane-wait.sh
#   4. Echo sentinel status (SUCCESS/NEEDS_HELP/FAILED) on stdout
#
# Sentinel format: ==DONE==<run-id>==phase-<phase-id>==<status>==
#
# Send modes (--mode):
#   file (default)
#     Send a single-line prompt: "Read the file at <abs-path> and follow
#     ALL instructions inside it." This bypasses cmux's `\n` → Enter
#     conversion that fragments multi-line prompts into separate codex
#     messages. The prompt body is on disk; codex reads it via its file
#     tools. Discovered necessary in the first sandbox verification
#     (run-id 20260507-0806-routine-tracker) where the raw mode caused
#     codex to start work on the first line and queue the rest.
#   raw
#     Send the full prompt body via pane-send.sh. cmux interprets each
#     newline as Enter, so codex receives each line as its own message.
#     Kept for backward-compat / debugging. Avoid for normal use.
#
# Usage:
#   phase-dispatch.sh --pane <ref> --run-id <id> --phase-id <id>
#                     [--timeout <sec>] [--poll <sec>] [--mode file|raw]
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
  --mode file|raw                  Prompt send mode (default: file)
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
MODE="file"

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
    --mode)
      [ $# -ge 2 ] || { echo "phase-dispatch: --mode requires a value" >&2; exit 2; }
      MODE="$2"; shift 2
      case "$MODE" in
        file|raw) ;;
        *) echo "phase-dispatch: --mode must be 'file' or 'raw' (got: $MODE)" >&2; exit 2 ;;
      esac
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

# Convert prompt path to absolute so codex (which sets its own cwd) can find it.
ABS_PROMPT_FILE=$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")

if [ "$MODE" = "file" ]; then
  # File-reference mode (default). Single-line message → no fragmentation.
  # Codex reads the file via its built-in file tool. Sentinel format and
  # all behavioral instructions live inside the file.
  msg="Read the file at ${ABS_PROMPT_FILE} and follow ALL instructions inside it. Do not stop until you emit the sentinel marker described in that file."
  if ! "$SEND" --pane "$PANE" --text "$msg"; then
    echo "phase-dispatch: pane-send failed" >&2
    exit 1
  fi
else
  # Raw mode (legacy). cmux interprets each \n as Enter so codex sees each
  # line as a separate message. Kept for debugging / explicit opt-in.
  prompt_text=$(cat "$PROMPT_FILE")
  if ! "$SEND" --pane "$PANE" --text "$prompt_text"; then
    echo "phase-dispatch: pane-send failed" >&2
    exit 1
  fi
fi

# Wait for the sentinel; pane-wait echoes status on stdout and propagates
# its own exit code (0 detected, 124 timeout, 1 resolution failure, 2 bad usage).
"$WAIT" --pane "$PANE" --run-id "$RUN_ID" --phase-id "$PHASE_ID" \
        --timeout "$TIMEOUT" --poll "$POLL"
