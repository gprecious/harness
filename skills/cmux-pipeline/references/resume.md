# Resume

## 목표
- paused/failed run을 재개. 이전 상태·산출물 모두 보존하고 paused_at 부터 다시 진행.

## 절차 (claude orch)

1. `bash scripts/resume-prepare.sh <run-id>` 호출 → JSON 출력 (`{run_id, topic, resume_from, worker_pane_id, options}`)
2. JSON 파싱:
   - `resume_from`: "spec" | "decompose" | "loop:<phase-id>" | "integrate"
   - `worker_pane_id`: 살아있는지 확인 (`cmux list-panes` 에 보이나)
3. worker pane 살아있음 → 재사용, 컨텍스트 그대로
   worker pane 죽음 → fresh pane + `codex-launch.sh` + 직전 phase 산출 요약 주입
4. resume_from 부터 정상 stage 진행 (Stage 1~4)

## resume_from 해석

| paused_at | 재개 stage | 비고 |
|---|---|---|
| `spec` | Stage 1 spec | 거의 없음 (spec 은 인터랙티브) |
| `decompose` | Stage 2 decompose | GSD 재호출 |
| `loop:<phase-id>` | Stage 3 loop, 해당 phase 부터 | failed_phases 에 있는 첫 phase 부터 retry |
| `integrate` | Stage 4 integrate | verification 재실행 |
