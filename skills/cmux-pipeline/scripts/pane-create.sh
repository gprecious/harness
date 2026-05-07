#!/usr/bin/env bash
# pane-create.sh — create a new cmux pane and emit its pane:<n> ref on stdout
#
# Usage:
#   pane-create.sh [--direction <left|right|up|down>] [--type <terminal|browser>]
#                  [--workspace <id|ref|index>] [--url <url>] [--help]
#
# Defaults:
#   --direction down
#   --type      terminal
#   --workspace (omitted; cmux defaults to currently focused workspace)
#
# Output:
#   On success: prints the new pane's short ref, e.g. `pane:33`, on stdout
#               and exits 0.
#   On failure: writes diagnostic to stderr and exits non-zero.
#
# cmux 0.62.2 notes (verified against installed version):
#   - `--workspace current` is NOT a valid literal. cmux requires a UUID,
#     a ref like `workspace:1`, or a numeric index. We omit --workspace by
#     default so cmux uses the currently focused workspace.
#   - `--id-format` is a GLOBAL option and MUST appear BEFORE the subcommand:
#       cmux --id-format both new-pane --type terminal --direction down
#   - With `--id-format both`, new-pane stdout looks like:
#       OK surface:36 (UUID) pane:33 (UUID) workspace:1 (UUID)
#     We extract the `pane:N` token (integer ref) for our return value.
#   - To close a pane we created, use `cmux close-surface --surface surface:N`
#     (close-surface takes --surface, NOT --pane). Closing the lone surface of
#     a freshly-created pane removes the pane.

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: pane-create.sh [options]

Create a new cmux pane in the currently focused workspace (or a specified
workspace) and print its `pane:<n>` ref on stdout.

Options:
  --direction <left|right|up|down>    Split direction (default: down)
  --type      <terminal|browser>      Pane type (default: terminal)
  --workspace <id|ref|index>          Target workspace (default: focused)
  --url       <url>                   Initial URL (browser type only)
  --help, -h                          Show this help and exit 0

Exit codes:
  0  Pane created; ref printed on stdout.
  2  Bad CLI usage (unknown flag, missing argument).
  3  cmux returned 0 but output could not be parsed.
  *  Propagated from cmux on failure.
USAGE
}

DIRECTION="down"
TYPE="terminal"
WORKSPACE=""
URL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --direction)
      [ $# -ge 2 ] || { echo "pane-create: --direction requires a value" >&2; exit 2; }
      DIRECTION="$2"; shift 2
      ;;
    --type)
      [ $# -ge 2 ] || { echo "pane-create: --type requires a value" >&2; exit 2; }
      TYPE="$2"; shift 2
      ;;
    --workspace)
      [ $# -ge 2 ] || { echo "pane-create: --workspace requires a value" >&2; exit 2; }
      WORKSPACE="$2"; shift 2
      ;;
    --url)
      [ $# -ge 2 ] || { echo "pane-create: --url requires a value" >&2; exit 2; }
      URL="$2"; shift 2
      ;;
    --help|-h)
      usage; exit 0
      ;;
    *)
      echo "pane-create: unknown flag: $1" >&2
      echo "" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Build the cmux command. --id-format is a GLOBAL option, before `new-pane`.
cmd=(cmux --id-format both new-pane --type "$TYPE" --direction "$DIRECTION")
[ -n "$WORKSPACE" ] && cmd+=(--workspace "$WORKSPACE")
[ -n "$URL" ]       && cmd+=(--url "$URL")

output=$("${cmd[@]}" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "pane-create: cmux new-pane failed (exit $exit_code):" >&2
  echo "$output" >&2
  exit $exit_code
fi

# Parse `pane:N` (integer ref) from cmux output. With --id-format both, the
# output line includes both the short ref and the UUID in parens; we want the
# short ref only.
pane_ref=$(printf '%s\n' "$output" | grep -oE 'pane:[0-9]+' | head -1)

if [ -z "$pane_ref" ]; then
  echo "pane-create: could not parse pane ref from cmux output:" >&2
  echo "$output" >&2
  exit 3
fi

echo "$pane_ref"
exit 0
