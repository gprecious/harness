# Stage 3: Contract (minimal hook)

## 목표
- decompose 산출물(GSD docs + 페이즈 PLAN) 을 입력으로 `contract-negotiator` agent 를 호출
- `.pipeline/runs/<run-id>/contract.md` 에 sprint contract 작성
- manifest 갱신

이 단계는 **정적 기준 문서**만 만든다. per-phase 평가/iteration 은 하지 않는다 (의식적 결정 — 2026-05-08 plan).

## 절차 (claude orch)

1. manifest 갱신: `stages.contract.status = "running"`
   ```bash
   bash scripts/manifest.sh update <run-id> '.stages.contract.status = "running" | .stages.contract.started_at = now | .stages.contract.started_at |= todate'
   ```

2. 사용자에게 안내:
   ```
   ▶ Stage 3/6: Contract (sprint contract negotiation)
   ```

3. **`Agent` tool 로 `contract-negotiator` agent 를 dispatch.**
   prompt 에 다음 입력 경로를 명시한다:
   - `decompose/PROJECT.md` (있으면) — 프로젝트 개요
   - `decompose/REQUIREMENTS.md` (있으면) — 요구사항
   - `decompose/ROADMAP.md` (있으면)
   - `decompose/phases/*/PLAN.md` 전체 (페이즈별 계획) — plan.md 등가물로 사용
   - `docs/harness/project-profile.md` (있으면; 없으면 cmux-pipeline 컨벤션을 prompt 로 명시)
   - 템플릿: `${CLAUDE_PLUGIN_ROOT}/templates/contract.md`

   agent 의 출력 경로를 `.pipeline/runs/<run-id>/contract.md` 로 명시한다 (Write tool target).

4. **✋ 사용자 검토 checkpoint** (default checkpoint 에 `contract` 포함):
   - Hard Thresholds 테이블
   - Verification Scenarios
   - Sprint Scope (IN/OUT)
   - 사용자가 수정 가능. 수정 후 contract.md 직접 편집 또는 agent 재dispatch.

5. finalize:
   ```bash
   bash scripts/stage-contract.sh <run-id>
   ```
   - contract.md 존재/비어있지 않음 검증
   - manifest: `stages.contract.status = "completed"`, `contract_path = "contract.md"`

6. checkpoint 가 활성이면 안내 후 종료:
   ```
   ▶ Stage 3 완료. contract/ 검토 후 `/build --resume <run-id>` 으로 계속하세요.
   ```

## 입력 어댑테이션 노트

`contract-negotiator` agent 는 원래 harness-orchestrator 의 `plan.md` + `project-profile.md` 를 기대한다. cmux-pipeline 에서는:

- `plan.md` 부재 → `decompose/phases/*/PLAN.md` 들의 **합쳐진 형태**가 plan 등가물.
  orch 는 prompt 에 "plan.md 위치 대신 다음 GSD phase plan 들의 합집합을 plan 으로 간주하라" 명시.
- `project-profile.md` 부재 → 다음 정보를 prompt 에 inline 으로 전달:
  - feature branch name
  - greenfield/brownfield 모드
  - decompose/PROJECT.md 의 stack 섹션
  - 사용자가 `--init` 을 돌렸으면 `docs/harness/project-profile.md` 그대로 첨부

## 실패 처리

- agent 가 contract.md 를 쓰지 않거나 비었으면 `stage-contract.sh` 가 exit 1.
- orch: `bash scripts/manifest.sh update <run-id> '.stages.contract.status = "failed" | .status = "paused" | .checkpoints.paused_at = "contract" | .checkpoints.paused_reason = "<reason>"'`
- 사용자에게 paused 알림 + resume 안내.

## 후속 단계

contract 완료 후 **stage-loop 의 phase prompt 에 contract.md 경로가 자동 주입**된다 (`phase-prompt-build.sh` 가 contract.md 존재 시 prompt 의 "Contract Reference" 섹션에 path 를 inline). codex worker 는 이를 *informational* 으로 받는다 — sentinel 라우팅은 변하지 않음.
