#!/usr/bin/env bash
# Append-only event logger for /improve.
# Usage: log_event.sh <event_type> [key=value ...]
#   - First positional arg becomes the "type" field.
#   - Remaining key=value pairs are merged into the JSON object.
#   - "ts" is auto-injected (ISO 8601 UTC).
# Writes a single JSON line to docs/code-improvement/<date>/events.jsonl,
# where <date> is the run dir of the most recent code-improver-state.md.
# Failures (no run dir, jq missing) exit 1 with a stderr message; the caller
# is expected to ignore the failure (event-log loss is non-critical).
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "log_event.sh: usage: log_event.sh <event_type> [key=value ...]" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "log_event.sh: jq not installed; skipping event log" >&2
  exit 1
fi

type_arg="$1"; shift

# Discover run dir = parent of the most recent code-improver-state.md.
state_file=$(find docs/code-improvement -maxdepth 2 -name code-improver-state.md 2>/dev/null | sort | tail -1)
if [ -z "$state_file" ]; then
  echo "log_event.sh: no run dir (no docs/code-improvement/*/code-improver-state.md)" >&2
  exit 1
fi
run_dir=$(dirname "$state_file")

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build the JSON object: start with {ts, type}, then merge each key=value.
jq_args=(--arg ts "$ts" --arg type "$type_arg")
filter='{ts:$ts, type:$type}'
for kv in "$@"; do
  k="${kv%%=*}"
  v="${kv#*=}"
  # Sanitize key for jq variable name (only alphanum + underscore).
  safe_k=$(printf '%s' "$k" | tr -c 'A-Za-z0-9_' '_')
  jq_args+=(--arg "v_$safe_k" "$v")
  # Use setpath so dotted keys nest correctly later (Task 5 will extend this).
  filter="$filter | .[\"$k\"] = \$v_$safe_k"
done

jq -cn "${jq_args[@]}" "$filter" >> "$run_dir/events.jsonl"
