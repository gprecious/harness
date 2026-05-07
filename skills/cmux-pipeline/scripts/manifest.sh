#!/usr/bin/env bash
# scripts/manifest.sh — run-id generation + manifest.json state management
#
# Subcommands accept BOTH positional args (legacy) and --flag form (preferred,
# matches pane-* and phase-* scripts). Unknown flags exit 2.
#
# Subcommands:
#   gen-run-id <topic> | --topic <topic>
#       Print YYYYMMDD-HHMM-<slug>
#   init <run-id> <topic> | --run-id <id> --topic <topic>
#       Create .pipeline/runs/<run-id>/ + manifest.json
#   read <run-id> <jq-expr> | --run-id <id> --jq <expr>
#       Print jq -r result against manifest.json
#   update <run-id> <jq-expr> | --run-id <id> --jq <expr>
#       Apply jq expr atomically; bumps updated_at
#   list
#       Print run-ids one per line

set -uo pipefail

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"

usage() {
  cat <<'USAGE'
Usage: manifest.sh <subcommand> [args]

Subcommands (both positional and --flag forms supported):
  gen-run-id <topic>                       Print YYYYMMDD-HHMM-<slug>
  gen-run-id --topic <topic>
  init       <run-id> <topic>              Create .pipeline/runs/<run-id>/
  init       --run-id <id> --topic <topic>
  read       <run-id> <jq-expr>            jq -r against manifest.json
  read       --run-id <id> --jq <expr>
  update     <run-id> <jq-expr>            Apply expr atomically; bumps updated_at
  update     --run-id <id> --jq <expr>
  list                                     Print run-ids one per line

Exit codes:
  0  success
  1  setup error (missing required value)
  2  bad CLI usage (unknown flag, missing arg value)
USAGE
}

# Parse mixed positional / --flag args into FLAG_<name> globals.
# Usage: parse_flags KEY1 KEY2 ... -- "$@"
# After call, look up via FLAG_<keyname> (uppercased, dashes -> underscores).
# Positional values fill in the order keys are listed (skipping any already
# set by an earlier --flag).
parse_flags() {
  local keys=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    keys+=( "$1" ); shift
  done
  [ "${1:-}" = "--" ] && shift
  local i
  for i in "${keys[@]}"; do
    local var
    var="FLAG_$(echo "$i" | tr 'a-z-' 'A-Z_')"
    eval "$var=''"
  done
  local positional=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --*)
        local raw="${1#--}"
        local var
        var="FLAG_$(echo "$raw" | tr 'a-z-' 'A-Z_')"
        # Check if this key is in the allowed list.
        local known=0
        for i in "${keys[@]}"; do
          local cmp
          cmp="FLAG_$(echo "$i" | tr 'a-z-' 'A-Z_')"
          [ "$cmp" = "$var" ] && { known=1; break; }
        done
        if [ "$known" -eq 0 ]; then
          echo "manifest: unknown flag: $1" >&2; return 2
        fi
        [ $# -ge 2 ] || { echo "manifest: $1 requires a value" >&2; return 2; }
        eval "$var=\"\$2\""
        shift 2
        ;;
      *)
        positional+=( "$1" ); shift
        ;;
    esac
  done
  # Fill empty FLAG_<key> from positionals in declared order.
  local pi=0
  for i in "${keys[@]}"; do
    local var
    var="FLAG_$(echo "$i" | tr 'a-z-' 'A-Z_')"
    local cur
    eval "cur=\"\$$var\""
    if [ -z "$cur" ] && [ "$pi" -lt "${#positional[@]}" ]; then
      eval "$var=\"\${positional[$pi]}\""
      pi=$((pi + 1))
    fi
  done
}

slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-30
}

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

cmd_gen_run_id() {
  parse_flags topic -- "$@" || return $?
  local topic="${FLAG_TOPIC:-}"
  [ -z "$topic" ] && { echo "manifest: gen-run-id: <topic> required" >&2; return 1; }
  local ts
  ts=$(date -u +%Y%m%d-%H%M)
  local slug
  slug=$(slugify "$topic")
  echo "${ts}-${slug}"
}

ensure_gitignore() {
  if [ -f .gitignore ]; then
    if ! grep -qE "^\.pipeline/?$" .gitignore; then
      {
        # Add a blank-line separator only if the file isn't empty.
        [ -s .gitignore ] && echo ""
        echo "# cmux-pipeline runs"
        echo ".pipeline/"
      } >> .gitignore
    fi
  else
    {
      echo "# cmux-pipeline runs"
      echo ".pipeline/"
    } > .gitignore
  fi
}

cmd_init() {
  parse_flags run-id topic -- "$@" || return $?
  local run_id="${FLAG_RUN_ID:-}"
  local topic="${FLAG_TOPIC:-}"
  [ -z "$run_id" ] && { echo "manifest: init: <run-id> required" >&2; return 1; }
  [ -z "$topic" ]  && { echo "manifest: init: <topic> required" >&2; return 1; }
  local dir="$PIPELINE_ROOT/$run_id"
  mkdir -p "$dir"/{spec,decompose,phases,decisions,logs}

  local script_dir tmpl
  script_dir=$(cd "$(dirname "$0")" && pwd)
  tmpl="$script_dir/../templates/manifest.json.tmpl"
  [ -f "$tmpl" ] || { echo "manifest: template not found: $tmpl" >&2; return 1; }

  local now_ts
  now_ts=$(now)

  # Atomic: write to .tmp then rename
  sed -e "s|{{RUN_ID}}|$run_id|g" \
      -e "s|{{TOPIC}}|$topic|g" \
      -e "s|{{TIMESTAMP}}|$now_ts|g" \
      "$tmpl" > "$dir/manifest.json.tmp"
  mv "$dir/manifest.json.tmp" "$dir/manifest.json"

  ensure_gitignore
}

cmd_read() {
  parse_flags run-id jq -- "$@" || return $?
  local run_id="${FLAG_RUN_ID:-}"
  local expr="${FLAG_JQ:-}"
  [ -z "$run_id" ] && { echo "manifest: read: <run-id> required" >&2; return 1; }
  [ -z "$expr" ]   && { echo "manifest: read: <jq-expr> required" >&2; return 1; }
  jq -r "$expr" "$PIPELINE_ROOT/$run_id/manifest.json"
}

cmd_update() {
  parse_flags run-id jq -- "$@" || return $?
  local run_id="${FLAG_RUN_ID:-}"
  local expr="${FLAG_JQ:-}"
  [ -z "$run_id" ] && { echo "manifest: update: <run-id> required" >&2; return 1; }
  [ -z "$expr" ]   && { echo "manifest: update: <jq-expr> required" >&2; return 1; }
  local file="$PIPELINE_ROOT/$run_id/manifest.json"
  [ -f "$file" ] || { echo "manifest: $file not found" >&2; return 1; }
  local now_ts
  now_ts=$(now)
  # Compose user expr with updated_at bump; atomic write via tmp+rename
  jq "($expr) | .updated_at = \"$now_ts\"" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

cmd_list() {
  [ -d "$PIPELINE_ROOT" ] || return 0
  ls -1 "$PIPELINE_ROOT" 2>/dev/null | sort
}

case "${1:-}" in
  gen-run-id) shift; cmd_gen_run_id "$@" ;;
  init)       shift; cmd_init "$@" ;;
  read)       shift; cmd_read "$@" ;;
  update)     shift; cmd_update "$@" ;;
  list)       cmd_list ;;
  --help|-h|"") usage; exit 0 ;;
  *) echo "manifest: unknown subcommand: $1" >&2; usage >&2; exit 2 ;;
esac
