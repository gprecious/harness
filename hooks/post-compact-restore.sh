#!/bin/bash
# Post-compact context restore: re-inject harness state after compaction
# Fires on SessionStart with "compact" matcher
#
# Input: JSON from stdin (SessionStart event)
# Output: JSON with systemMessage containing current harness state

input=$(cat)

# Find active harness run
state_file=$(find docs/harness -name "harness-state.md" 2>/dev/null | head -1)

if [ -z "$state_file" ]; then
  echo '{}'
  exit 0
fi

run_dir=$(dirname "$state_file")

# Extract key state fields
current_phase=$(grep "^- current_phase:" "$state_file" 2>/dev/null | sed 's/.*: //')
iteration=$(grep "^- iteration:" "$state_file" 2>/dev/null | sed 's/.*: //')
project_type=$(grep "^- type:" "$state_file" 2>/dev/null | sed 's/.*: //' | head -1)
feature=$(grep "^- feature:" "$state_file" 2>/dev/null | sed 's/.*: //')
iteration_type=$(grep "^- iteration_type:" "$state_file" 2>/dev/null | sed 's/.*: //')
delta_targets=$(grep "^- delta_targets:" "$state_file" 2>/dev/null | sed 's/.*: //')
plateau=$(grep "^- plateau_detected:" "$state_file" 2>/dev/null | sed 's/.*: //')

# Extract last evaluation scores if in BUILD_EVALUATE
last_eval=""
if [ "$current_phase" = "BUILD_EVALUATE" ]; then
  latest_eval_file=$(find "$run_dir/evaluations" -name "iteration-*.md" 2>/dev/null | sort | tail -1)
  if [ -n "$latest_eval_file" ]; then
    verdict=$(grep -i "^### Verdict:" "$latest_eval_file" 2>/dev/null | sed 's/.*Verdict:[[:space:]]*//')
    failing=$(grep "^- failing_criteria:" "$latest_eval_file" 2>/dev/null | sed 's/.*: //')
    last_eval="Verdict: ${verdict}, Failing: ${failing}"
  fi
fi

cat <<EOJSON
{"systemMessage":"[Harness Context Restored] Feature: ${feature} | Phase: ${current_phase} | Iteration: ${iteration} (${iteration_type}) | Type: ${project_type} | Plateau: ${plateau} | ${last_eval}\nResume: ${run_dir}/harness-state.md + contract.md 읽고 계속 진행하세요. 사용자에게 세션 교체를 묻지 마세요."}
EOJSON
