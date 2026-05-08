# Stage 6: Learn (wisdom extraction)

## 목표
- 완료된 run 의 모든 아티팩트에서 재사용 가능한 지식 추출
- `docs/wisdom/{patterns,decisions,evaluations,test-recipes}/` 에 마크다운 파일 누적
- `docs/wisdom/index.md` 자동 갱신
- manifest 의 `stages.learn` 마킹

이 단계는 **항상 자동 실행** (checkpoint 옵션 없음). 실패해도 run 자체는 `completed` 유지 (학습은 부가).

## 절차 (claude orch)

1. manifest 갱신: `stages.learn.status = "running"`

2. 사용자에게 안내:
   ```
   ▶ Stage 6/6: Learn (wisdom extraction)
   ```

3. **`Agent` tool 로 `wisdom-extractor` agent 를 dispatch.**
   prompt 에 다음 입력 경로를 명시한다:
   - `.pipeline/runs/<run-id>/contract.md` (있으면)
   - `.pipeline/runs/<run-id>/decompose/{PROJECT,REQUIREMENTS,ROADMAP}.md` (있는 것)
   - `.pipeline/runs/<run-id>/decompose/phases/*/PLAN.md` 전체
   - `.pipeline/runs/<run-id>/manifest.json` (run state, retry/compaction 통계, completed/failed phases)
   - `git diff <base_branch>..<feature_branch>` 결과 — 코드 변경 전체

   agent 의 Write 출력 경로:
   - `docs/wisdom/patterns/<topic-slug>-<n>.md`
   - `docs/wisdom/decisions/<topic-slug>-<n>.md`
   - `docs/wisdom/evaluations/<topic-slug>.md`
   - `docs/wisdom/test-recipes/<topic-slug>-<n>.md`
   - `docs/wisdom/index.md` 갱신 (append 또는 항목 추가)

4. finalize:
   ```bash
   bash scripts/stage-learn.sh <run-id>
   ```
   - `docs/wisdom/` 하위 *.md (index.md 제외) 1개 이상 존재 검증
   - manifest: `stages.learn.status = "completed"`, `artifacts = [...]`

5. **사용자 안내 (final summary)**:
   ```
   [/build] DONE in <duration>.
     contract: contract.md
     completed phases: <N>
     wisdom artifacts: <K> file(s) under docs/wisdom/
     PR 생성: gh pr create --base main --head <feature_branch>
   ```

## 입력 어댑테이션 노트

`wisdom-extractor` 는 harness-orchestrator 의 `plan.md`, `test-scenarios.md`, `evaluations/iteration-*.md`, `harness-state.md` 를 기대한다. cmux-pipeline 에서는:

| 원본 입력 | cmux-pipeline 대체 |
|---|---|
| `plan.md` | `decompose/phases/*/PLAN.md` 합집합 |
| `test-scenarios.md` | 없음 (codex worker 내부에서 작성됨) — git diff 의 `*.test.*` 변경에서 역추출 |
| `evaluations/iteration-*.md` | `manifest.json` 의 retry/sentinel 라우팅 결과 |
| `harness-state.md` | `manifest.json` |
| `summary.md` | 없음 — orch 가 prompt 에 final summary 텍스트 inline |

orch 는 prompt 에 위 매핑을 명시하고, agent 가 빈 카테고리(예: test-recipes 가 빈약)를 그냥 skip 하도록 허용한다 (강제 4-카테고리 X).

## 실패 처리

- agent 가 wisdom 파일을 하나도 쓰지 않으면 `stage-learn.sh` 가 exit 1.
- orch: `manifest.stages.learn.status = "failed"` 로 마킹하되 `manifest.status` 는 `completed` 유지 (run 자체는 성공).
- 사용자에게 경고만: "wisdom 추출 실패. integrate 는 성공. 수동 추출 가능."
