#!/usr/bin/env bash
# scripts/stage-loop.sh — Stage 3 phase loop with retry routing
#
# Iterates every directory under .pipeline/runs/<run-id>/decompose/phases/ in
# sort order. For each phase: optional /compact, prompt build, status init,
# dispatch attempt 1, retry attempt 2 with pane-routing on failure, and final
# manifest update. Two attempts both failing pauses the manifest and exits 2.
#
# Usage:
#   stage-loop.sh <run-id> <worker-pane-id>
#
# Env:
#   PHASE_TIMEOUT       Per-phase dispatch timeout sec (default: 1200)
#   COMPACT_THRESHOLD   context_estimate_tokens > this triggers /compact (218000)
#   PIPELINE_ROOT       Pipeline runs root (default: .pipeline/runs)
#
# Retry routing:
#   - SUCCESS                        → record commit, next phase
#   - NEEDS_HELP                     → retry on the SAME pane
#   - FAILED  / TIMEOUT (exit 124)   → close pane, create fresh pane + codex
#                                       relaunch, retry on the new pane
#   - second attempt fails           → manifest paused, exit 2

set -uo pipefail

RUN_ID="${1:-}"
WORKER_PANE="${2:-}"
[ -z "$RUN_ID" ]      && { echo "stage-loop: <run-id> required" >&2; exit 1; }
[ -z "$WORKER_PANE" ] && { echo "stage-loop: <worker-pane-id> required" >&2; exit 1; }

PHASE_TIMEOUT="${PHASE_TIMEOUT:-1200}"
COMPACT_THRESHOLD="${COMPACT_THRESHOLD:-218000}"
PIPELINE_ROOT="${PIPELINE_ROOT:-.pipeline/runs}"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MANIFEST="$SCRIPT_DIR/manifest.sh"
PHASE_STATUS="$SCRIPT_DIR/phase-status.sh"
PHASE_PROMPT_BUILD="$SCRIPT_DIR/phase-prompt-build.sh"
PHASE_DISPATCH="$SCRIPT_DIR/phase-dispatch.sh"
PANE_CREATE="$SCRIPT_DIR/pane-create.sh"
PANE_CLOSE="$SCRIPT_DIR/pane-close.sh"
PANE_COMPACT="$SCRIPT_DIR/pane-compact.sh"
CODEX_LAUNCH="$SCRIPT_DIR/codex-launch.sh"

# Read codex model + sandbox from manifest options so retries on a fresh pane
# get the same flags the orchestrator chose at run start. nohup-background
# subprocesses don't inherit the orchestrator's $CODEX_MODEL/$CODEX_SANDBOX
# env vars, so without this we'd fall back to codex-launch.sh defaults — the
# bug found in the first sandbox verification.
RUN_MODEL=$("$MANIFEST" read "$RUN_ID" '.options.model // empty' 2>/dev/null || echo "")
[ "$RUN_MODEL" = "null" ] && RUN_MODEL=""
RUN_SANDBOX=$("$MANIFEST" read "$RUN_ID" '.options.sandbox // empty' 2>/dev/null || echo "")
[ "$RUN_SANDBOX" = "null" ] && RUN_SANDBOX=""

# Honor manifest.options.workspace_id so retry pane creation lands in the same
# isolated workspace the orchestrator created. Without this, a fresh pane on
# retry would default to the user's currently-focused cmux workspace and
# clutter their view — the bug the workspace-create.sh primitive was added to
# prevent. Caller may also pre-export CMUX_WORKSPACE_ID; manifest wins so the
# pipeline state is the single source of truth.
RUN_WORKSPACE=$("$MANIFEST" read "$RUN_ID" '.options.workspace_id // empty' 2>/dev/null || echo "")
[ "$RUN_WORKSPACE" = "null" ] && RUN_WORKSPACE=""
[ -n "$RUN_WORKSPACE" ] && export CMUX_WORKSPACE_ID="$RUN_WORKSPACE"

codex_launch_args=()
[ -n "$RUN_MODEL" ]   && codex_launch_args+=( --model "$RUN_MODEL" )
[ -n "$RUN_SANDBOX" ] && codex_launch_args+=( --sandbox "$RUN_SANDBOX" )

PHASES_DIR="$PIPELINE_ROOT/$RUN_ID/decompose/phases"
[ -d "$PHASES_DIR" ] || {
  echo "stage-loop: phases dir missing: $PHASES_DIR" >&2
  exit 1
}

# Mark the loop as running and record the initial worker pane.
"$MANIFEST" update "$RUN_ID" \
  ".stages.loop.status = \"running\" | .stages.loop.worker_pane_id = \"$WORKER_PANE\""

# Run a single dispatch attempt and route by outcome.
# Echoes "result|exit_code" on stdout so the caller can inspect both.
run_dispatch() {
  local pane="$1"
  local set_e_was_on=0
  case "$-" in *e*) set_e_was_on=1 ;; esac
  set +e
  local out
  out=$("$PHASE_DISPATCH" --pane "$pane" --run-id "$RUN_ID" --phase-id "$phase_id" \
                          --timeout "$PHASE_TIMEOUT" --poll 5)
  local ec=$?
  [ "$set_e_was_on" -eq 1 ] && set -e
  echo "$out|$ec"
}

# Enumerate phase dirs in sorted order. Use ls -1d so trailing-slash globs
# expand only to directories.
shopt -s nullglob
phase_paths=( "$PHASES_DIR"/*/ )
shopt -u nullglob

# Stable sort by path (lexical).
IFS=$'\n' phase_paths_sorted=( $(printf '%s\n' "${phase_paths[@]}" | sort) )
unset IFS

if [ "${#phase_paths_sorted[@]}" -eq 0 ]; then
  echo "stage-loop: no phase directories found in $PHASES_DIR" >&2
  exit 1
fi

for phase_path in "${phase_paths_sorted[@]}"; do
  phase_id=$(basename "${phase_path%/}")
  echo "[stage-loop] phase $phase_id: start"

  # 1) Optional /compact based on the running estimate.
  ctx=$("$MANIFEST" read "$RUN_ID" '.stages.loop.context_estimate_tokens // 0')
  if [ "$ctx" -gt "$COMPACT_THRESHOLD" ]; then
    echo "[stage-loop] phase $phase_id: context $ctx > $COMPACT_THRESHOLD → /compact"
    "$PANE_COMPACT" --pane "$WORKER_PANE" --marker "C_${phase_id}" || true
    "$MANIFEST" update "$RUN_ID" \
      '.stages.loop.compactions = (.stages.loop.compactions // 0) + 1
       | .stages.loop.context_estimate_tokens = 50000'
  fi

  # 2) Build the prompt and initialize the per-phase status file.
  "$PHASE_PROMPT_BUILD" "$RUN_ID" "$phase_id" >/dev/null
  "$PHASE_STATUS" init "$RUN_ID" "$phase_id" "$WORKER_PANE"

  # 3) Attempt 1 dispatch.
  set +e
  result=$("$PHASE_DISPATCH" --pane "$WORKER_PANE" --run-id "$RUN_ID" \
             --phase-id "$phase_id" --timeout "$PHASE_TIMEOUT" --poll 5)
  exit_code=$?
  set -e

  if [ "$exit_code" -eq 0 ] && [ "$result" = "SUCCESS" ]; then
    commit=$(git rev-parse HEAD 2>/dev/null || echo "n/a")
    "$PHASE_STATUS" complete "$RUN_ID" "$phase_id" "SUCCESS" "$commit"
    "$MANIFEST" update "$RUN_ID" \
      ".stages.loop.completed_phases += [\"$phase_id\"]
       | .stages.loop.context_estimate_tokens = ((.stages.loop.context_estimate_tokens // 0) + 30000)"
    echo "[stage-loop] phase $phase_id: SUCCESS commit=$commit"
    continue
  fi

  # Not SUCCESS — log and proceed to retry.
  echo "[stage-loop] phase $phase_id: attempt 1 failed (result=${result:-?} exit=$exit_code) → retrying"

  # 4) Decide retry pane: same for NEEDS_HELP, fresh otherwise.
  if [ "$result" = "NEEDS_HELP" ]; then
    new_pane="$WORKER_PANE"
    echo "[stage-loop] phase $phase_id: retrying on same pane $new_pane (NEEDS_HELP)"
  else
    "$PANE_CLOSE" --pane "$WORKER_PANE" || true
    if ! new_pane=$("$PANE_CREATE" --direction down); then
      echo "[stage-loop] failed to create fresh pane" >&2
      exit 1
    fi
    # Empty-array safe expansion for mac bash 3.2 with `set -u`.
    "$CODEX_LAUNCH" --pane "$new_pane" --cwd "$(pwd)" ${codex_launch_args[@]+"${codex_launch_args[@]}"} || true
    WORKER_PANE="$new_pane"
    "$MANIFEST" update "$RUN_ID" ".stages.loop.worker_pane_id = \"$new_pane\""
    echo "[stage-loop] phase $phase_id: retrying on fresh pane $new_pane"
  fi

  "$PHASE_STATUS" retry "$RUN_ID" "$phase_id" "$new_pane"

  # 5) Attempt 2 dispatch.
  set +e
  result2=$("$PHASE_DISPATCH" --pane "$new_pane" --run-id "$RUN_ID" \
              --phase-id "$phase_id" --timeout "$PHASE_TIMEOUT" --poll 5)
  ec2=$?
  set -e

  if [ "$ec2" -eq 0 ] && [ "$result2" = "SUCCESS" ]; then
    commit=$(git rev-parse HEAD 2>/dev/null || echo "n/a")
    "$PHASE_STATUS" complete "$RUN_ID" "$phase_id" "SUCCESS" "$commit"
    "$MANIFEST" update "$RUN_ID" ".stages.loop.completed_phases += [\"$phase_id\"]"
    echo "[stage-loop] phase $phase_id: SUCCESS (retry) commit=$commit"
    continue
  fi

  # 6) Both attempts failed — pause the pipeline and exit 2.
  "$PHASE_STATUS" complete "$RUN_ID" "$phase_id" "FAILED" "n/a"
  "$MANIFEST" update "$RUN_ID" \
    ".stages.loop.failed_phases += [\"$phase_id\"]
     | .status = \"paused\"
     | .checkpoints.paused_at = \"loop:$phase_id\"
     | .checkpoints.paused_reason = \"phase failed twice\""
  echo "[stage-loop] phase $phase_id: FAILED twice → pipeline paused" >&2
  exit 2
done

# All phases passed.
"$MANIFEST" update "$RUN_ID" '.stages.loop.status = "completed"'
echo "[stage-loop] all phases done."
exit 0
