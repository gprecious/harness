#!/bin/bash
# harness-lint.sh — Computational Feedforward linter for harness artifacts.
#
# Validates harness artifacts structurally and deterministically.
# Every error message includes a Fix: line so agents can self-correct.
#
# Usage:
#   bash harness-lint.sh <run_dir> [check ...]
#   bash harness-lint.sh docs/harness/2026-04-02-feature/ contract evaluation state test screenshots all
#
# Exit: 0 = pass, 1 = violations found (violations printed to stdout as JSON array)

set -euo pipefail

run_dir="${1:?Usage: harness-lint.sh <run_dir> [checks...]}"
shift
checks=("${@:-all}")

# Resolve project root
project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$project_root" ]; then
  project_root=$(cd "$run_dir/../.." 2>/dev/null && pwd)
fi

# Read state if available
state_file="$run_dir/harness-state.md"
project_type=""
current_phase=""
if [ -f "$state_file" ]; then
  project_type=$(grep "^- type:" "$state_file" 2>/dev/null | sed 's/.*: //' | head -1)
  current_phase=$(grep "^- current_phase:" "$state_file" 2>/dev/null | sed 's/.*: //')
fi

violations=()

# --- Helper: add violation with fix instruction ---
add_violation() {
  local category="$1"
  local message="$2"
  local fix="$3"
  violations+=("[$category] $message\n  Fix: $fix")
}

# --- Check: contract.md ---
lint_contract() {
  local contract="$run_dir/contract.md"
  if [ ! -f "$contract" ]; then
    add_violation "contract" "contract.md가 존재하지 않습니다." \
      "contract-negotiator agent를 실행하세요. 템플릿: \${CLAUDE_PLUGIN_ROOT}/templates/contract.md"
    return
  fi

  # Required sections
  for section in "Hard Thresholds" "Verification Scenarios" "Sprint Scope"; do
    if ! grep -q "$section" "$contract" 2>/dev/null; then
      add_violation "contract" "contract.md에 '$section' 섹션이 없습니다." \
        "contract.md 템플릿의 필수 섹션을 모두 포함하세요. See templates/contract.md"
    fi
  done

  # Threshold floor validation (design 4-axis ≥ 7)
  for criterion in functionality design_quality originality craft; do
    score=$(grep -i "| $criterion " "$contract" 2>/dev/null | grep -o '[0-9]\+/10' | head -1 | cut -d'/' -f1)
    if [ -n "$score" ] && [ "$score" -lt 7 ] 2>/dev/null; then
      add_violation "contract" "$criterion threshold가 ${score}/10입니다 (floor: 7/10)." \
        "contract.md에서 | $criterion | 행의 점수를 7/10 이상으로 수정하세요. 7 미만은 사용자 승인 필요."
    fi
  done

  # test_coverage floor (≥ 80%)
  coverage=$(grep -i "| test_coverage " "$contract" 2>/dev/null | grep -o '[0-9]\+%' | head -1 | tr -d '%')
  if [ -n "$coverage" ] && [ "$coverage" -lt 80 ] 2>/dev/null; then
    add_violation "contract" "test_coverage threshold가 ${coverage}%입니다 (floor: 80%)." \
      "contract.md에서 | test_coverage | 행의 값을 80% 이상으로 수정하세요."
  fi
}

# --- Check: evaluation ---
lint_evaluation() {
  local eval_dir="$run_dir/evaluations"
  local eval_count=$(find "$eval_dir" -name "iteration-*.md" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$eval_count" = "0" ]; then
    add_violation "evaluation" "evaluations/iteration-N.md가 없습니다." \
      "contract.md 기준으로 채점을 수행하고 evaluations/iteration-1.md를 생성하세요. 템플릿: templates/evaluation.md"
    return
  fi

  local latest_eval=$(find "$eval_dir" -name "iteration-*.md" 2>/dev/null | sort | tail -1)

  # Required sections
  if ! grep -q "### Verdict:" "$latest_eval" 2>/dev/null; then
    add_violation "evaluation" "evaluation에 '### Verdict:' 행이 없습니다." \
      "$latest_eval에 '### Verdict: PASS' 또는 '### Verdict: FAIL' 행을 추가하세요. hooks가 이 패턴을 파싱합니다."
  fi

  if ! grep -q "Test Results" "$latest_eval" 2>/dev/null; then
    add_violation "evaluation" "evaluation에 'Test Results' 섹션이 없습니다." \
      "$latest_eval에 '### Test Results' 섹션을 추가하고 테스트 실행 결과를 기록하세요."
  fi

  if ! grep -q "Score Evidence" "$latest_eval" 2>/dev/null; then
    add_violation "evaluation" "evaluation에 'Score Evidence' 섹션이 없습니다." \
      "$latest_eval에 '### Score Evidence' 섹션을 추가하세요. 각 축의 5/10 출발 기반 가산/감산 근거 필수."
  fi

  if ! grep -q "^- failing_criteria:" "$latest_eval" 2>/dev/null; then
    add_violation "evaluation" "evaluation에 'failing_criteria' 필드가 없습니다." \
      "$latest_eval의 Verdict 아래에 '- failing_criteria: [목록]' 행을 추가하세요."
  fi
}

# --- Check: harness-state.md ---
lint_state() {
  if [ ! -f "$state_file" ]; then
    add_violation "state" "harness-state.md가 존재하지 않습니다." \
      "harness-state.md를 templates/harness-state.md 기반으로 생성하세요."
    return
  fi

  # Required fields
  for field in "current_phase" "type" "iteration" "run_dir" "feature"; do
    if ! grep -q "^- $field:" "$state_file" 2>/dev/null; then
      add_violation "state" "harness-state.md에 '$field' 필드가 없습니다." \
        "harness-state.md에 '- $field: <값>' 행을 추가하세요."
    fi
  done

  # Phase must be valid
  if [ -n "$current_phase" ]; then
    case "$current_phase" in
      PLAN|CONTRACT|TEST|BUILD_EVALUATE|INTEGRATE|LEARN) ;;
      *) add_violation "state" "current_phase '$current_phase'는 유효하지 않습니다." \
           "유효한 phase: PLAN, CONTRACT, TEST, BUILD_EVALUATE, INTEGRATE, LEARN" ;;
    esac
  fi
}

# --- Check: test files ---
lint_tests() {
  if [ ! -f "$run_dir/test-scenarios.md" ]; then
    add_violation "test" "test-scenarios.md가 없습니다." \
      "test-architect agent를 실행하여 테스트 시나리오를 도출하세요."
  fi

  local test_count=$(find "$project_root" \
    -path "*/node_modules" -prune -o \
    -path "*/.git" -prune -o \
    -path "*/.worktrees" -prune -o \
    \( -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.*" -o -name "*Test.*" \) \
    -type f -print 2>/dev/null | wc -l | tr -d ' ')

  if [ "$test_count" = "0" ]; then
    add_violation "test" "테스트 코드 파일이 0개입니다 (*.test.*, *.spec.*)." \
      "test-architect가 시나리오 문서뿐 아니라 실제 테스트 코드도 작성해야 합니다. 웹: 유닛 + 컴포넌트(Testing Library) + E2E(Playwright)"
  fi

  # Web projects: check for component/E2E test files
  if [ "$project_type" = "web" ] || [ "$project_type" = "content" ]; then
    local e2e_count=$(find "$project_root" \
      -path "*/node_modules" -prune -o \
      -path "*/.git" -prune -o \
      -path "*/.worktrees" -prune -o \
      \( -name "*.e2e.*" -o -name "*.spec.ts" -o -path "*/e2e/*" -o -path "*/playwright/*" \) \
      -type f -print 2>/dev/null | wc -l | tr -d ' ')

    if [ "$e2e_count" = "0" ]; then
      add_violation "test" "E2E 테스트 파일이 0개입니다 (web 프로젝트 필수)." \
        "Playwright E2E 테스트를 작성하세요. contract.md의 Verification Scenarios를 E2E로 구현. webapp-testing skill 활용."
    fi
  fi
}

# --- Check: screenshots ---
lint_screenshots() {
  if [ "$project_type" != "web" ] && [ "$project_type" != "content" ]; then
    return  # screenshots only required for web/content
  fi

  local ss_count=$(find "$run_dir/screenshots" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$ss_count" = "0" ]; then
    add_violation "screenshots" "screenshots/ 가 비어있습니다 ($project_type 프로젝트 필수)." \
      "design-evaluator agent를 dispatch하세요. Playwright로 스크린샷을 촬영하고 {run_dir}/screenshots/에 저장합니다."
  fi
}

# --- Run requested checks ---
should_run() {
  local check="$1"
  for c in "${checks[@]}"; do
    if [ "$c" = "all" ] || [ "$c" = "$check" ]; then
      return 0
    fi
  done
  return 1
}

should_run "contract"    && lint_contract
should_run "evaluation"  && lint_evaluation
should_run "state"       && lint_state
should_run "test"        && lint_tests
should_run "screenshots" && lint_screenshots

# --- Output ---
if [ ${#violations[@]} -eq 0 ]; then
  echo "PASS: all checks passed (${checks[*]})"
  exit 0
fi

echo "FAIL: ${#violations[@]} violation(s) found"
echo ""
for v in "${violations[@]}"; do
  echo -e "  $v"
  echo ""
done
exit 1
