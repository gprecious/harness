## Evaluation: Iteration {N}

### Scores
| Criterion | Score | Threshold | Status | Trend |
|-----------|-------|-----------|--------|-------|
| functionality | {N}/10 | {T}/10 | ✓/✗ | ↑/→/↓ |
| design_quality | {N}/10 | {T}/10 | ✓/✗ | ↑/→/↓ |
| originality | {N}/10 | {T}/10 | ✓/✗ | ↑/→/↓ |
| craft | {N}/10 | {T}/10 | ✓/✗ | ↑/→/↓ |
| test_coverage | {N}% | {T}% | ✓/✗ | ↑/→/↓ |
| security | PASS/FAIL | PASS | ✓/✗ | |

### Score Evidence
> 각 축 5/10 출발, 증거 기반 가감. 증거 없는 가산 금지.

| Criterion | 가산 근거 | 감산 근거 | 최종 |
|-----------|----------|----------|------|
| functionality | | | /10 |
| design_quality | | | /10 |
| originality | | | /10 |
| craft | | | /10 |

### Verdict: {PASS/FAIL}
- failing_criteria: [{미달 기준 목록}]
- recommendation: {refine/pivot}
- first_pass_skepticism: {통과/미실행} (iteration 1인 경우 필수)

### Detailed Feedback
> FAIL 기준별 구체적 피드백. 각 항목에 위치, 현재 상태, 기준, 수정 방향 포함.

1. {문제}: {구체적 위치/요소}
   현재: {현재 상태}
   기준: {threshold 기준}
   수정 방향: {구체적 개선 방법}

### Test Results
- total: {N}, passed: {N}, failed: {N}
- failed_tests:
  - {test name}: {failure reason} (diagnosis: implementation_bug/test_bug)

### Screenshots
- {run_dir}/screenshots/{filename}: {description}
