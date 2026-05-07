#!/usr/bin/env bash
# scripts/phase-status.sh — per-phase status.json state management
#
# Subcommands:
#   init     <run-id> <phase-id> <pane-id>            Create status.json (status=started)
#   complete <run-id> <phase-id> <sentinel> <commit>  Set completed/failed + duration_sec
#   retry    <run-id> <phase-id> <new-pane-id>        Increment attempts; reset state
#   read     <run-id> <phase-id> <jq-expr>            jq -r on status.json

set -uo pipefail

PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"

usage() {
  cat <<'USAGE'
Usage: phase-status.sh <subcommand> <args>

  init <run-id> <phase-id> <pane-id>
  complete <run-id> <phase-id> <sentinel> <commit-sha>
  retry <run-id> <phase-id> <new-pane-id>
  read <run-id> <phase-id> <jq-expr>
USAGE
}

phase_dir() {
  echo "$PIPELINE_ROOT/$1/phases/$2"
}

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Convert ISO8601 UTC to epoch seconds. macOS BSD vs GNU compat.
to_epoch() {
  local iso="$1"
  if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s >/dev/null 2>&1; then
    date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s
  else
    date -d "$iso" +%s
  fi
}

cmd_init() {
  local run_id="${1:?run-id required}"
  local phase_id="${2:?phase-id required}"
  local pane_id="${3:?pane-id required}"
  local dir
  dir=$(phase_dir "$run_id" "$phase_id")
  mkdir -p "$dir"
  local now_ts
  now_ts=$(now)
  cat > "$dir/status.json.tmp" <<EOF
{
  "phase_id": "$phase_id",
  "status": "started",
  "attempts": 1,
  "started_at": "$now_ts",
  "ended_at": null,
  "duration_sec": null,
  "worker_pane_id": "$pane_id",
  "compact_before": false,
  "sentinel_status": null,
  "commit_sha": null,
  "tokens_estimate": 0
}
EOF
  mv "$dir/status.json.tmp" "$dir/status.json"
}

cmd_complete() {
  local run_id="${1:?run-id required}"
  local phase_id="${2:?phase-id required}"
  local sentinel="${3:?sentinel required}"
  local commit="${4:?commit required}"
  local dir
  dir=$(phase_dir "$run_id" "$phase_id")
  local file="$dir/status.json"
  [ -f "$file" ] || { echo "phase-status: $file not found" >&2; return 1; }

  local started now_ts started_ts now_epoch dur status
  started=$(jq -r '.started_at' "$file")
  now_ts=$(now)
  started_ts=$(to_epoch "$started")
  now_epoch=$(to_epoch "$now_ts")
  dur=$((now_epoch - started_ts))
  [ "$dur" -lt 0 ] && dur=0  # clock skew safety

  status="completed"
  [ "$sentinel" = "FAILED" ] && status="failed"

  jq --arg s "$sentinel" --arg c "$commit" --arg n "$now_ts" --arg st "$status" --argjson d "$dur" \
     '.status = $st | .sentinel_status = $s | .commit_sha = $c | .ended_at = $n | .duration_sec = $d' \
     "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

cmd_retry() {
  local run_id="${1:?run-id required}"
  local phase_id="${2:?phase-id required}"
  local new_pane="${3:?new-pane-id required}"
  local file
  file=$(phase_dir "$run_id" "$phase_id")/status.json
  [ -f "$file" ] || { echo "phase-status: $file not found" >&2; return 1; }
  local now_ts
  now_ts=$(now)
  jq --arg p "$new_pane" --arg n "$now_ts" \
     '.attempts += 1 | .status = "retrying" | .worker_pane_id = $p | .started_at = $n | .ended_at = null | .duration_sec = null' \
     "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

cmd_read() {
  local run_id="${1:?run-id required}"
  local phase_id="${2:?phase-id required}"
  local expr="${3:?jq expr required}"
  jq -r "$expr" "$(phase_dir "$run_id" "$phase_id")/status.json"
}

case "${1:-}" in
  init)     shift; cmd_init "$@" ;;
  complete) shift; cmd_complete "$@" ;;
  retry)    shift; cmd_retry "$@" ;;
  read)     shift; cmd_read "$@" ;;
  --help|-h|"") usage; exit 0 ;;
  *) echo "phase-status: unknown subcommand: $1" >&2; usage >&2; exit 2 ;;
esac
