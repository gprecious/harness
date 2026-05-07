#!/usr/bin/env bash
# scripts/codex-launch.sh — start interactive codex in a cmux pane with safe flags
#
# Per notes/codex-cli-flags.md (Phase 0 Task 2 verification against codex
# 0.128.0), the actual codex CLI flag surface is:
#   -m, --model <name>             model selection
#   -C, --cd <path>                working directory
#   -s, --sandbox <mode>           workspace-write recommended (R5)
#   -a, --ask-for-approval <mode>  'never' for headless (was --auto-approve in design)
#   --no-alt-screen                REQUIRED inside cmux for scrollback preservation
#   -c <key=value>                 TOML config override (repeatable)
#       mcp_servers={}                  disables MCP (was --no-mcp in design)
#       model_reasoning_effort="high"   raises reasoning effort (was --reasoning high)
#
# Resulting command line (typed into the pane):
#   codex -m <MODEL> -C <CWD> -s workspace-write -a never --no-alt-screen \
#         -c 'model_reasoning_effort="high"' -c 'mcp_servers={}'
#
# Quoting:
#   - The single quotes around -c values are essential. zsh and bash both
#     glob `{}` and reinterpret `"`. We want the pane's shell to receive the
#     literal token `-c mcp_servers={}` — single quotes survive the
#     pane-send.sh roundtrip because we transmit the entire command as one
#     string, and the pane's interactive shell parses it normally.
#
# Usage:
#   codex-launch.sh --pane <pane:N|surface:N> --cwd <path> [--model <name>]
#
# After launch, the codex interactive session runs in the pane. Use
# pane-send.sh to send prompts and pane-wait.sh to wait for sentinels.

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: codex-launch.sh --pane <ref> --cwd <path> [options]

Start an interactive codex session inside a cmux pane.

Required:
  --pane <ref>     Target pane ref (pane:N | surface:N | UUID)
  --cwd <path>     Working directory for the codex session

Options:
  --model <name>   Codex model name (overrides $CODEX_MODEL env)
  --help, -h       Show this help and exit 0

Environment:
  CODEX_MODEL        default model when --model not given
                     (default: gpt-5.5-codex)
  CODEX_EXTRA_FLAGS  extra flags appended to the codex invocation

Exit codes:
  0  Codex command typed into the pane successfully.
  1  Missing required flag (--pane or --cwd).
  2  Bad CLI usage (unknown flag).
  *  Propagated from pane-send.sh on transport failure.
USAGE
}

PANE=""
CWD=""
MODEL="${CODEX_MODEL:-gpt-5.5-codex}"
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
# The single quotes around -c values are intentional: they protect `{}` from
# globbing and `"high"` from quote-stripping by the pane's shell.
cmd="cd \"$CWD\" && codex -m \"$MODEL\" -C \"$CWD\" -s workspace-write -a never --no-alt-screen -c 'model_reasoning_effort=\"high\"' -c 'mcp_servers={}'"
if [ -n "$EXTRA_FLAGS" ]; then
  cmd="$cmd $EXTRA_FLAGS"
fi

"$SEND" --pane "$PANE" --text "$cmd"

# Codex needs ~2-3s to render its banner and become input-ready. Sleep so
# callers can immediately follow up with pane-send.sh prompts without racing
# the TUI startup.
sleep 3

exit 0
