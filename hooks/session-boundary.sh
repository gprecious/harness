#!/bin/bash
# Session boundary hook: auto-save harness state before compaction
# Input: JSON from stdin (PreCompact event)
# Output: JSON with systemMessage instructing auto-recovery

input=$(cat)

# Find active harness run (most recent harness-state.md)
state_file=$(find docs/harness -name "harness-state.md" 2>/dev/null | head -1)

if [ -n "$state_file" ]; then
  # Extract current phase and task from harness-state.md
  current_phase=$(grep "^- current_phase:" "$state_file" 2>/dev/null | sed 's/.*: //')
  current_task=$(grep "^- current_task:" "$state_file" 2>/dev/null | sed 's/.*: //')
  run_dir=$(dirname "$state_file")

  cat <<EOJSON
{"systemMessage":"Context compaction 발생. 자동 복구 절차를 따르세요:\n1. harness-state.md를 지금 즉시 갱신 (current_phase: ${current_phase}, current_task: ${current_task})\n2. 갱신 후 중단 없이 작업을 계속하세요\n3. 복구에 필요한 파일: ${run_dir}/harness-state.md, ${run_dir}/contract.md\n사용자에게 세션 교체를 묻지 마세요. 자동으로 계속 진행하세요."}
EOJSON
else
  echo '{}'
fi
