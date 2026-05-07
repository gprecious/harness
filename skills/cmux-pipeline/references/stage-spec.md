# Stage 1: Spec (GStack)

## 목표
- GStack 의 `/office-hours` (필요 시 `/autoplan`) 으로 design doc + 페르소나 리뷰 생성
- 결과를 `.pipeline/runs/<run-id>/spec/` 에 복사
- manifest 갱신

## 외부 skill I/O 요약 (자세한 근거: `notes/external-skills-io.md`)

GStack 산출물은 **프로젝트별 글로벌 디렉토리** `~/.gstack/projects/<slug>/` 밑에 떨어진다.
우리가 호출 시 출력 경로를 지정할 수는 없다.

- `/office-hours` → `~/.gstack/projects/<slug>/<user>-<branch>-design-<datetime>.md`
- `/autoplan` (옵션) → 같은 디렉토리에:
  - `<branch>-autoplan-restore-<datetime>.md` (사용자 plan 파일을 in-place 수정한 restore point)
  - `<user>-<branch>-test-plan-<datetime>.md` (test plan artifact)

`<slug>` 는 `~/.claude/skills/gstack/bin/gstack-slug` 가 산출 (PATH 등록 안 됨 — 절대경로 호출).

## 절차 (claude orch 가 수행)

1. manifest 갱신: `stages.spec.status = "running"`, `started_at = now`
   ```bash
   bash scripts/manifest.sh update <run-id> '.stages.spec.status = "running" | .stages.spec.started_at = now | .stages.spec.started_at |= todate'
   ```
2. 사용자에게 안내 출력:
   ```
   ▶ Stage 1/4: Spec (gstack)
   ```
3. **`Skill` tool 로 `gstack:office-hours` 실행** — 인터랙티브, 사용자가 design doc 작성에 참여.
   - 산출물: `~/.gstack/projects/<slug>/<user>-<branch>-design-<datetime>.md`
4. (옵션) `--autoplan` 플래그 또는 사용자 승인 시 **`Skill` tool 로 `gstack:autoplan` 실행**.
5. GStack 출력 파일들을 `.pipeline/runs/<run-id>/spec/` 으로 정리:
   ```bash
   # 기본: gstack-slug 으로 자동 디렉토리 발견
   bash scripts/stage-spec-finalize.sh <run-id>

   # 또는 명시적으로 디렉토리 지정 (테스트 / 다른 슬러그 강제 시)
   bash scripts/stage-spec-finalize.sh <run-id> <gstack-output-dir>
   ```
   이 스크립트가 수행하는 일:
   - 디렉토리의 모든 `*.md` 파일을 `spec/` 으로 copy
   - mtime 가장 최근 `*-design-*.md` 를 `stages.spec.primary_design` 에 기록
   - `stages.spec.status = "completed"`, `stages.spec.outputs = [...]` 로 manifest 갱신
6. checkpoint 가 `spec` 을 포함하는 경우 (기본값):
   - 사용자에게 출력:
     ```
     ▶ Stage 1 완료. spec/ 검토 후 `/build --resume <run-id>` 으로 계속하세요.
     ```
   - 종료 (다음 stage 로 자동 진행하지 않음).

## 실패 처리
- `/office-hours` 도중 사용자가 중단하거나 design doc 이 생성되지 않은 경우:
  - `stage-spec-finalize.sh` 가 "no .md files in <dir>" 로 실패 종료 (exit 1)
  - manifest 의 `stages.spec.status` 는 `running` 그대로 — orch 가 `failed` 로 마킹할지 결정
- gstack-slug 실행 실패 시: 사용자에게 출력 디렉토리를 직접 지정하도록 안내 (인자 2)

## 참고
- 이 stage 는 **항상 사용자 인터랙션 필요** — 자동화 불가
- spec/ 디렉토리에 들어간 파일들은 다음 stage (decompose) 의 입력으로 사용됨
