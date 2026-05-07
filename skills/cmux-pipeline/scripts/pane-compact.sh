#!/usr/bin/env bash
# pane-compact.sh — send /compact to a codex pane, then poll for readiness marker
#
# Approach: cmux's /compact is processed by codex TUI; we can't directly
# detect when it finishes (the actual UI completion string is unverified —
# see notes/codex-cli-flags.md). Instead we inject our own readiness marker
# (`echo $MARKER`) AFTER /compact and poll until that marker appears in
# the pane's scrollback. This guarantees we don't proceed until /compact
# (and any prompt re-render) has completed.
#
# In a non-codex pane (plain shell) /compact is just a "command not found"
# no-op — only the marker echo step matters for readiness detection.
#
# Usage:
#   pane-compact.sh --pane <ref> [--marker <string>] [--timeout <sec>] [--poll <sec>]
#
# cmux 0.62.2 notes:
#   - read-screen takes --surface (NOT --pane). We resolve pane:N -> surface:N
#     via lib/resolve-surface.sh (DRY with pane-send / pane-wait).
#
# Exit codes:
#   0    marker detected within --timeout
#   1    --pane missing or pane->surface resolution failed
#   2    bad CLI usage (unknown flag, missing argument)
#   124  timeout expired without marker detection

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: pane-compact.sh --pane <ref> [options]

Send /compact to a codex pane and wait for a readiness marker to appear.
Sends `/compact`, briefly waits for codex to process it, then injects
`echo <marker>` and polls scrollback until the marker shows up.

Required:
  --pane <pane:N|surface:N|UUID>   Target pane or surface ref

Options:
  --marker <string>                Custom readiness marker
                                   [default: COMPACT_READY_<pid>]
  --timeout <seconds>              Max wait time for marker (default: 30)
  --poll <seconds>                 Poll interval (default: 2)
  --help, -h                       Show this help and exit 0

Exit codes:
  0    Marker detected
  1    Missing required flag, or pane->surface resolution failed
  2    Bad CLI usage (unknown flag, missing argument)
  124  Timeout
USAGE
}

PANE=""
MARKER=""
TIMEOUT=30
POLL=2

while [ $# -gt 0 ]; do
  case "$1" in
    --pane)
      [ $# -ge 2 ] || { echo "pane-compact: --pane requires a value" >&2; exit 2; }
      PANE="$2"; shift 2
      ;;
    --marker)
      [ $# -ge 2 ] || { echo "pane-compact: --marker requires a value" >&2; exit 2; }
      MARKER="$2"; shift 2
      ;;
    --timeout)
      [ $# -ge 2 ] || { echo "pane-compact: --timeout requires a value" >&2; exit 2; }
      TIMEOUT="$2"; shift 2
      ;;
    --poll)
      [ $# -ge 2 ] || { echo "pane-compact: --poll requires a value" >&2; exit 2; }
      POLL="$2"; shift 2
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      echo "pane-compact: unknown flag: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -z "$PANE" ] && { echo "pane-compact: --pane is required" >&2; exit 1; }
[ -z "$MARKER" ] && MARKER="COMPACT_READY_$$"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/resolve-surface.sh"

SURFACE=$(resolve_surface "$PANE") || exit 1

SEND="$SCRIPT_DIR/pane-send.sh"

# 1. Send /compact (codex slash command). In a plain shell this is a no-op
#    "command not found" — fine for testing. In codex TUI this triggers
#    context summarization.
"$SEND" --pane "$PANE" --text "/compact"

# Brief wait for codex to process /compact (UI may re-render, prompt resets).
# In a real codex session this is when context summarization happens.
sleep 3

# 2. Inject the readiness marker (echo $MARKER + Enter).
"$SEND" --pane "$PANE" --text "echo $MARKER"

# 3. Poll until marker appears in scrollback.
elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
  screen=$(cmux read-screen --surface "$SURFACE" --lines 100 2>/dev/null || echo "")
  if printf '%s\n' "$screen" | grep -qF "$MARKER"; then
    exit 0
  fi
  sleep "$POLL"
  elapsed=$((elapsed + POLL))
done

echo "pane-compact: timeout after ${TIMEOUT}s waiting for marker '$MARKER'" >&2
exit 124
