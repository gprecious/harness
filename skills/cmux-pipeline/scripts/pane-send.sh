#!/usr/bin/env bash
# pane-send.sh — send text input to a cmux pane
#
# Usage:
#   pane-send.sh --pane <pane:N|surface:N|UUID> --text <string> [--no-enter] [--help]
#
# cmux 0.62.2 notes (verified against installed version):
#   - The send command is `cmux send-panel --panel <surface_ref> <text>` and
#     the key command is `cmux send-key-panel --panel <surface_ref> <key>`.
#     Despite the flag name `--panel`, both commands require a SURFACE ref,
#     not a pane ref. Passing `pane:N` returns:
#         Error: invalid_params: Surface is not a terminal
#     We therefore resolve `pane:N` -> `surface:N` internally via
#     `cmux list-pane-surfaces --pane <pane>` (selecting the first/selected
#     surface). Callers may pass either form to --pane; we handle both.
#   - Multiline strategy: we split the input on newlines and send one
#     `send-panel` per line, followed by a `send-key-panel enter` (unless
#     --no-enter). This avoids relying on cmux's `\n` escape interpretation
#     and gives us a clean --no-enter implementation.
#   - Output: `OK <surface:N> <workspace:N>` per command. We discard it.
#
# Exit codes:
#   0  All lines sent successfully.
#   1  Missing required flag (--pane, --text), or unable to resolve pane->surface.
#   2  Bad CLI usage (unknown flag, missing argument).
#   *  Propagated from cmux on send failure.

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: pane-send.sh --pane <ref> --text <string> [options]

Send text input to a cmux pane (resolved to its primary terminal surface).
Multiline text is split on newlines; each line is sent followed by an Enter
key event (unless --no-enter).

Required:
  --pane <pane:N|surface:N|UUID>   Target pane or surface ref
  --text <string>                  Text to send (may contain newlines)

Options:
  --no-enter                       Do not press Enter after sending
  --help, -h                       Show this help and exit 0

Exit codes:
  0  Success.
  1  Missing required flag, or pane->surface resolution failed.
  2  Bad CLI usage (unknown flag, missing argument).
  *  Propagated from cmux on send failure.
USAGE
}

PANE=""
TEXT=""
TEXT_SET=0
NO_ENTER=0

while [ $# -gt 0 ]; do
  case "$1" in
    --pane)
      [ $# -ge 2 ] || { echo "pane-send: --pane requires a value" >&2; exit 2; }
      PANE="$2"; shift 2
      ;;
    --text)
      [ $# -ge 2 ] || { echo "pane-send: --text requires a value" >&2; exit 2; }
      TEXT="$2"; TEXT_SET=1; shift 2
      ;;
    --no-enter)
      NO_ENTER=1; shift
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      echo "pane-send: unknown flag: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -z "$PANE" ] && { echo "pane-send: --pane is required" >&2; exit 1; }
[ "$TEXT_SET" -eq 0 ] && { echo "pane-send: --text is required" >&2; exit 1; }

# Resolve pane ref -> surface ref via shared lib. cmux send-panel requires a
# surface ref even though its flag is --panel. The lib handles surface:*,
# pane:*, and UUID forms; on hard failure it prints an error and we exit 1.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/resolve-surface.sh"

SURFACE=$(resolve_surface "$PANE") || exit 1

# Safety guard: refuse to send to the currently focused pane. The whole point
# of cmux-pipeline is to type into a worker pane we created, never into the
# pane the user is actively looking at. If we ever resolve to the focused
# pane, that's almost certainly a bug in the caller — the user just got their
# input field hijacked.
#
# History: the first sandbox verification (run-id 20260507-0806) had a probe
# step that grepped `cmux list-panes` for the focused pane and sent key events
# to it, hijacking the user's interactive shell. This guard makes that mistake
# fail loudly instead of silently corrupting the user's session.
#
# Override with PANE_SEND_ALLOW_FOCUSED=1 for tests that legitimately need to
# drive the focused pane (none in current cmux-pipeline code).
if [ "${PANE_SEND_ALLOW_FOCUSED:-0}" != "1" ]; then
  focused_pane=$(cmux list-panes 2>/dev/null \
    | grep -E '^\*' | grep -oE 'pane:[0-9]+' | head -1)
  if [ -n "$focused_pane" ]; then
    focused_surface=$(cmux list-pane-surfaces --pane "$focused_pane" 2>/dev/null \
      | grep -oE 'surface:[0-9]+' | head -1)
    if { [ -n "$focused_pane" ] && [ "$PANE" = "$focused_pane" ]; } \
       || { [ -n "$focused_surface" ] && [ "$SURFACE" = "$focused_surface" ]; }; then
      echo "pane-send: refusing to send to focused pane $focused_pane" >&2
      echo "  (target was $PANE → $SURFACE). Override with" >&2
      echo "  PANE_SEND_ALLOW_FOCUSED=1 if intentional." >&2
      exit 1
    fi
  fi
fi

# Send each line of TEXT, followed by Enter (unless --no-enter).
# Use a here-string so we capture the trailing line even without a final
# newline. `IFS= read -r` plus `|| [ -n "$line" ]` handles that case.
#
# Empty lines: cmux 0.62.2 rejects `send-panel -- ""` with
#   "Error: send-panel requires text"
# To preserve blank-line semantics in multi-line prompts, we skip the
# send-panel call for empty lines and just press Enter (when not --no-enter).
send_line() {
  local line="$1"
  if [ -n "$line" ]; then
    if ! cmux send-panel --panel "$SURFACE" -- "$line" >/dev/null 2>&1; then
      # Re-run without redirection to surface the error, then exit.
      cmux send-panel --panel "$SURFACE" -- "$line" >&2
      exit $?
    fi
  fi
  if [ "$NO_ENTER" -eq 0 ]; then
    if ! cmux send-key-panel --panel "$SURFACE" enter >/dev/null 2>&1; then
      cmux send-key-panel --panel "$SURFACE" enter >&2
      exit $?
    fi
  fi
}

# Track whether we've sent any line so an empty TEXT still triggers a single
# Enter (matching shell behavior of "press enter on empty prompt").
sent_any=0
while IFS= read -r line || [ -n "$line" ]; do
  send_line "$line"
  sent_any=1
done <<< "$TEXT"

# If TEXT was completely empty (zero lines), send a bare Enter when not
# --no-enter, to mirror "send empty input" semantics.
if [ "$sent_any" -eq 0 ] && [ "$NO_ENTER" -eq 0 ]; then
  cmux send-key-panel --panel "$SURFACE" enter >/dev/null 2>&1 || true
fi

exit 0
