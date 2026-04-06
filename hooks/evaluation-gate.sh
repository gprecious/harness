#!/bin/bash
# Evaluation gate: block Stop if active harness run lacks required verification evidence.
# Delegates validation to harness-lint.sh (Computational Feedforward).
#
# Input: JSON from stdin (Stop event)
# Output: JSON with decision "block" if evidence missing

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
input=$(cat)

# Find active harness run
state_file=$(find docs/harness -name "harness-state.md" 2>/dev/null | head -1)

# No active harness run — allow stop
if [ -z "$state_file" ]; then
  echo '{}'
  exit 0
fi

run_dir=$(dirname "$state_file")
current_phase=$(grep "^- current_phase:" "$state_file" 2>/dev/null | sed 's/.*: //')

# Only gate during BUILD_EVALUATE phase
if [ "$current_phase" != "BUILD_EVALUATE" ]; then
  echo '{}'
  exit 0
fi

# Allow stop after plateau or max iterations (user has been informed)
iteration=$(grep "^- iteration:" "$state_file" 2>/dev/null | sed 's/.*: //' | cut -d'/' -f1)
max_iter=$(grep "^- iteration:" "$state_file" 2>/dev/null | sed 's/.*: //' | cut -d'/' -f2)
plateau=$(grep "^- plateau_detected:" "$state_file" 2>/dev/null | sed 's/.*: //')

if [ "$plateau" = "true" ]; then
  echo '{}'; exit 0
fi
if [ -n "$max_iter" ] && [ -n "$iteration" ] && [ "$iteration" -ge "$max_iter" ] 2>/dev/null; then
  echo '{}'; exit 0
fi

# --- Run harness-lint.sh for evaluation + screenshots ---
lint_output=$("$SCRIPT_DIR/harness-lint.sh" "$run_dir" evaluation screenshots 2>/dev/null)
lint_exit=$?

# --- Additional: verdict must be PASS to stop ---
latest_eval=$(find "$run_dir/evaluations" -name "iteration-*.md" 2>/dev/null | sort | tail -1)
if [ -n "$latest_eval" ]; then
  verdict=$(grep -i "^### Verdict:" "$latest_eval" 2>/dev/null | sed 's/.*Verdict:[[:space:]]*//' | tr '[:lower:]' '[:upper:]')
  if [ -n "$verdict" ] && [ "$verdict" != "PASS" ]; then
    failing=$(grep "^- failing_criteria:" "$latest_eval" 2>/dev/null | sed 's/.*: //')
    lint_output="${lint_output}\n[verdict] FAIL (미달: ${failing:-unknown}). 세션 종료 차단.\n  Fix: 다음 iteration을 수행하여 모든 hard thresholds를 통과하세요."
    lint_exit=1
  fi
fi

# All checks passed
if [ "$lint_exit" -eq 0 ]; then
  echo '{}'
  exit 0
fi

# Build block response
block_reasons=$(echo -e "$lint_output" | sed 's/"/\\"/g' | tr '\n' ' ')

cat <<EOJSON
{
  "decision": "block",
  "reason": "$block_reasons"
}
EOJSON
