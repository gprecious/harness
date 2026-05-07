#!/usr/bin/env bash
# scripts/manifest.sh — run-id generation + manifest.json state management
#
# Subcommands:
#   gen-run-id <topic>           Print YYYYMMDD-HHMM-<slug>
#   init <run-id> <topic>        Create .pipeline/runs/<run-id>/ + manifest.json
#   read <run-id> <jq-expr>      Print jq -r result against manifest.json
#   update <run-id> <jq-expr>    Apply jq expr atomically; bumps updated_at
#   list                         Print run-ids one per line

set -uo pipefail

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"

usage() {
  cat <<'USAGE'
Usage: manifest.sh <subcommand> [args]

Subcommands:
  gen-run-id <topic>            Print YYYYMMDD-HHMM-<slug>
  init <run-id> <topic>         Create .pipeline/runs/<run-id>/ + manifest.json
  read <run-id> <jq-expr>       jq -r against manifest.json
  update <run-id> <jq-expr>     Apply expr atomically; bumps updated_at
  list                          Print run-ids one per line
USAGE
}

slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-30
}

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

cmd_gen_run_id() {
  local topic="${1:?topic required}"
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
  local run_id="${1:?run-id required}"
  local topic="${2:?topic required}"
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
  local run_id="${1:?run-id required}"
  local expr="${2:?jq expr required}"
  jq -r "$expr" "$PIPELINE_ROOT/$run_id/manifest.json"
}

cmd_update() {
  local run_id="${1:?run-id required}"
  local expr="${2:?jq expr required}"
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
