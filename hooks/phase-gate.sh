#!/bin/bash
# Phase gate: blocks harness-state.md updates if current phase evidence is missing.
# Fires on PreToolUse for Edit/Write targeting harness-state.md.
# Delegates validation to harness-lint.sh (Computational Feedforward).
#
# Input: JSON from stdin with tool_input containing file path and content
# Output: exit 2 + stderr message to block, or exit 0 + empty JSON to allow

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
input=$(cat)

# Extract the file path being edited/written
file_path=$(echo "$input" | python3 -c "
import json, sys
data = json.load(sys.stdin)
ti = data.get('tool_input', {})
print(ti.get('file_path', ti.get('path', '')))
" 2>/dev/null)

# Only gate harness-state.md writes
case "$file_path" in
  *harness-state.md) ;;
  *) echo '{}'; exit 0 ;;
esac

run_dir=$(dirname "$file_path")

# Read current phase from EXISTING file (before modification)
if [ ! -f "$file_path" ]; then
  echo '{}'; exit 0
fi

current_phase=$(grep "^- current_phase:" "$file_path" 2>/dev/null | sed 's/.*: //')

# Detect if this write is advancing the phase
new_content=$(echo "$input" | python3 -c "
import json, sys
data = json.load(sys.stdin)
ti = data.get('tool_input', {})
print(ti.get('new_string', ti.get('content', '')))
" 2>/dev/null)

is_phase_transition=false
if echo "$new_content" | grep -q "current_phase:"; then
  new_phase=$(echo "$new_content" | grep "current_phase:" | sed 's/.*current_phase:[[:space:]]*//' | head -1)
  if [ -n "$new_phase" ] && [ "$new_phase" != "$current_phase" ]; then
    is_phase_transition=true
  fi
fi

# --- Determine which lint checks to run based on current phase ---
lint_checks=""
case "$current_phase" in
  PLAN)
    lint_checks="state"
    # Plan artifacts are checked by file existence
    for required in exploration.md architecture.md plan.md; do
      if [ ! -f "$run_dir/$required" ]; then
        echo "Phase 'PLAN' 완료 조건 미충족: $required 가 없습니다." >&2
        exit 2
      fi
    done
    echo '{}'; exit 0
    ;;
  CONTRACT)
    lint_checks="contract"
    ;;
  TEST)
    lint_checks="test"
    ;;
  BUILD_EVALUATE)
    lint_checks="evaluation screenshots"
    ;;
  *)
    echo '{}'; exit 0
    ;;
esac

# --- Run harness-lint.sh ---
lint_output=$("$SCRIPT_DIR/harness-lint.sh" "$run_dir" $lint_checks 2>/dev/null)
lint_exit=$?

# --- Additional BUILD_EVALUATE check: verdict PASS only on phase transition ---
if [ "$current_phase" = "BUILD_EVALUATE" ] && [ "$is_phase_transition" = true ]; then
  latest_eval=$(find "$run_dir/evaluations" -name "iteration-*.md" 2>/dev/null | sort | tail -1)
  if [ -n "$latest_eval" ]; then
    verdict=$(grep -i "^### Verdict:" "$latest_eval" 2>/dev/null | sed 's/.*Verdict:[[:space:]]*//' | tr '[:lower:]' '[:upper:]')

    if [ -z "$verdict" ]; then
      lint_output="${lint_output}\n[evaluation] Verdict가 없습니다.\n  Fix: evaluation에 '### Verdict: PASS' 또는 '### Verdict: FAIL' 행을 추가하세요."
      lint_exit=1
    elif [ "$verdict" != "PASS" ]; then
      iteration=$(grep "^- iteration:" "$file_path" 2>/dev/null | sed 's/.*: //' | cut -d'/' -f1)
      max_iter=$(grep "^- iteration:" "$file_path" 2>/dev/null | sed 's/.*: //' | cut -d'/' -f2)
      plateau=$(grep "^- plateau_detected:" "$file_path" 2>/dev/null | sed 's/.*: //')
      failing=$(grep "^- failing_criteria:" "$latest_eval" 2>/dev/null | sed 's/.*: //')

      if [ "$plateau" = "true" ]; then
        lint_output="${lint_output}\n[verdict] FAIL + plateau 감지됨.\n  Fix: 사용자에게 개입을 요청하세요 (기준 완화 / 방향 전환 / 중단)."
      elif [ -n "$max_iter" ] && [ -n "$iteration" ] && [ "$iteration" -ge "$max_iter" ] 2>/dev/null; then
        lint_output="${lint_output}\n[verdict] FAIL + max iterations ($max_iter) 도달.\n  Fix: 사용자에게 현황을 보고하고 계속/중단을 결정받으세요."
      else
        lint_output="${lint_output}\n[verdict] FAIL (미달: ${failing:-unknown}). Phase 전환 차단.\n  Fix: 다음 iteration에서 failing criteria를 수정하세요. 모든 hard thresholds 통과 필요."
      fi
      lint_exit=1
    fi
  fi
fi

# --- Result ---
if [ "$lint_exit" -eq 0 ]; then
  echo '{}'
  exit 0
fi

echo -e "$lint_output" >&2
exit 2
