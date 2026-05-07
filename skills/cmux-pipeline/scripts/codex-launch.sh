#!/usr/bin/env bash
# scripts/codex-launch.sh — start interactive codex in a cmux pane with safe flags
#
# Per notes/codex-cli-flags.md (Phase 0 Task 2 verification against codex
# 0.128.0), the actual codex CLI flag surface is:
#   -m, --model <name>             model selection
#   -C, --cd <path>                working directory
#   -s, --sandbox <mode>           sandbox mode (omit to respect ~/.codex/config.toml)
#   -a, --ask-for-approval <mode>  'never' for headless
#   --no-alt-screen                REQUIRED inside cmux for scrollback preservation
#   -c <key=value>                 TOML config override (repeatable)
#       model_reasoning_effort="high"   raises reasoning effort
#
# Default resulting command line (typed into the pane):
#   codex -m <MODEL> -C <CWD> -a never --no-alt-screen \
#         -c 'model_reasoning_effort="high"'
#
# Sandbox: by default we DO NOT pass -s, so codex respects the user's
# ~/.codex/config.toml `sandbox_mode`. The first sandbox verification (run-id
# 20260507-0806-routine-tracker) found that hard-coding `-s workspace-write`
# blocked npm registry access for users whose config grants
# `danger-full-access`. Pass --sandbox <mode> to override explicitly.
#
# Trust prompt: codex prompts "Do you trust the contents of this directory?" on
# first launch in a new directory. We auto-answer "1" (Yes) by default after
# the launch wait. Disable with --no-auto-trust if you want manual control.
#
# Usage:
#   codex-launch.sh --pane <pane:N|surface:N> --cwd <path>
#                   [--model <name>] [--sandbox <mode>] [--no-auto-trust]
#
# After launch, the codex interactive session runs in the pane. Use
# pane-send.sh to send prompts and pane-wait.sh to wait for sentinels.

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: codex-launch.sh --pane <ref> --cwd <path> [options]

Start an interactive codex session inside a cmux pane.

Required:
  --pane <ref>          Target pane ref (pane:N | surface:N | UUID)
  --cwd <path>          Working directory for the codex session

Options:
  --model <name>        Codex model (overrides $CODEX_MODEL env, default gpt-5.5)
  --sandbox <mode>      Codex sandbox mode (workspace-write, danger-full-access).
                        Default: omit -s entirely (respect ~/.codex/config.toml).
  --no-auto-trust       Do NOT auto-answer codex's directory trust prompt.
                        Default: send "1" + Enter ~5s after launch.
  --help, -h            Show this help and exit 0

Environment:
  CODEX_MODEL           default model when --model not given (default: gpt-5.5)
  CODEX_SANDBOX         default sandbox mode when --sandbox not given
  CODEX_EXTRA_FLAGS     extra flags appended to the codex invocation

Exit codes:
  0  Codex command typed into the pane successfully.
  1  Missing required flag (--pane or --cwd).
  2  Bad CLI usage (unknown flag).
  *  Propagated from pane-send.sh on transport failure.
USAGE
}

PANE=""
CWD=""
MODEL="${CODEX_MODEL:-gpt-5.5}"
SANDBOX="${CODEX_SANDBOX:-}"
AUTO_TRUST=1
EXTRA_FLAGS="${CODEX_EXTRA_FLAGS:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --pane)
      [ $# -ge 2 ] || { echo "codex-launch: --pane requires a value" >&2; exit 2; }
      PANE="$2"; shift 2
      ;;
    --cwd)
      [ $# -ge 2 ] || { echo "codex-launch: --cwd requires a value" >&2; exit 2; }
      CWD="$2"; shift 2
      ;;
    --model)
      [ $# -ge 2 ] || { echo "codex-launch: --model requires a value" >&2; exit 2; }
      MODEL="$2"; shift 2
      ;;
    --sandbox)
      [ $# -ge 2 ] || { echo "codex-launch: --sandbox requires a value" >&2; exit 2; }
      SANDBOX="$2"; shift 2
      ;;
    --no-auto-trust)
      AUTO_TRUST=0; shift
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      echo "codex-launch: unknown flag: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ -z "$PANE" ] && { echo "codex-launch: --pane required" >&2; exit 1; }
[ -z "$CWD" ]  && { echo "codex-launch: --cwd required" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SEND="$SCRIPT_DIR/pane-send.sh"

# Compose the codex invocation. The pane's interactive shell will execute it
# verbatim, so we must produce text that's syntactically valid in that shell.
# Single quotes around -c values protect `"high"` from the pane shell's
# quote-stripping pass.
cmd="cd \"$CWD\" && codex -m \"$MODEL\" -C \"$CWD\""
if [ -n "$SANDBOX" ]; then
  cmd="$cmd -s \"$SANDBOX\""
fi
cmd="$cmd -a never --no-alt-screen -c 'model_reasoning_effort=\"high\"'"
if [ -n "$EXTRA_FLAGS" ]; then
  cmd="$cmd $EXTRA_FLAGS"
fi

"$SEND" --pane "$PANE" --text "$cmd"

# Codex needs ~2-3s to render its banner and become input-ready. Sleep so
# callers can immediately follow up with pane-send.sh prompts without racing
# the TUI startup. Need a few extra seconds for the trust prompt to render.
sleep 5

# Auto-handle codex's "Do you trust the contents of this directory?" prompt.
# Only fires when codex hasn't seen this dir before; idempotent on repeat
# launches in the same dir (the prompt won't appear, our "1\n" lands in the
# normal input buffer and is harmless).
if [ "$AUTO_TRUST" -eq 1 ]; then
  surface=$(cmux list-pane-surfaces --pane "$PANE" 2>/dev/null \
    | grep -oE 'surface:[0-9]+' | head -1)
  if [ -n "$surface" ]; then
    screen=$(cmux read-screen --surface "$surface" --lines 30 2>/dev/null || echo "")
    if echo "$screen" | grep -q "trust the contents"; then
      "$SEND" --pane "$PANE" --text "1" >/dev/null 2>&1 || true
      sleep 2
    fi
  fi
fi

exit 0
