---
name: cmux-pipeline
description: GStack + GSD + Superpowers + build-loop을 cmux pane + codex CLI 기반으로 통합하는 자율 빌드 파이프라인. /build <topic> 한 줄로 spec → 페이즈 분해 → TDD 루프 → 통합까지 진행. claude orch가 plan/refactor를 담당하고 long-lived codex worker가 코드 작성. 컨텍스트는 /compact로 관리.
version: 0.1.0
tools: Read, Write, Edit, Bash, Grep, Glob, Agent
---

# cmux-pipeline

## Overview

`/build <topic>` 한 줄로 spec 작성 → 페이즈 분해 → TDD 루프 → 통합 까지 자동 실행. 기존 harness skill 들과 독립.

4-stage:
1. **Spec** (GStack): `/office-hours` + `/autoplan`
2. **Decompose** (GSD): `/gsd-new-project` 또는 `/gsd-map-codebase`, `/gsd-plan-phase --prd`
3. **Loop** (build-loop + codex worker): per-phase RED → GREEN → review
4. **Integrate**: `superpowers:verification-before-completion`

claude orch (현재 세션)이 plan/spec/test scenario/refactor를 담당하고, long-lived codex worker가 cmux pane에서 test code/구현 작성. 컨텍스트는 codex `/compact` 명령으로 관리.

## When to Use

- 신규 기능 / 큰 리팩토링 / 그린필드 PoC
- spec → 페이즈 분해 → TDD가 정당화되는 규모

Don't use:
- 한 줄 변경 / 타이포 / 파일 한 개 수정 (직접 편집)
- 보안 인시던트 (수동 triage)
- 기존 harness `/feature` 가 더 적합한 경우

## Commands

| Command | Action |
|---|---|
| `/build <topic>` | 새 run 시작 |
| `/build --resume <run-id>` | paused/failed run 재개 |
| `/build --status [<run-id>]` | run 상태 |
| `/build --list` | 모든 run 목록 |
| `/build --gc [<days>]` | N일 이상 run 삭제 (default 30) |

## Options

| Option | Default | 설명 |
|---|---|---|
| `--checkpoint=<stages>` | `spec,decompose` | 정지점. `none` 으로 풀-오토 |
| `--skip=<stages>` | `` | `spec,decompose` 스킵 가능 |
| `--greenfield` / `--brownfield` | auto-detect | GSD 진입점 |
| `--phase-timeout=<sec>` | `1200` | phase timeout |
| `--compact-every=<n>` | auto | N 페이즈마다 강제 /compact |
| `--no-confirm` | `false` | confirm 없이 진행 |
| `--dry-run` | `false` | preflight 만 |
| `--verbose` | `false` | codex pane scrollback tail |
| `--model=<name>` | (codex default) | codex 모델 override |

## Dependencies (preflight 검증)

- cmux CLI (Apple silicon 또는 Linux)
- codex CLI (OpenAI)
- jq, git, bats-core (테스트 시)
- claude plugin: gstack, gsd, build-loop, superpowers, ralph-loop

자세한 내부 구조는 `references/` 참조.

## Orchestration Workflow

`/build` 가 호출되면 claude orchestrator는 다음 절차를 따른다.

### Workspace / Pane Isolation Hard Rule

- 절대 현재 focused workspace 에 worker pane 을 만들거나 입력을 보내지 않는다.
- 새 run 은 반드시 `workspace-create.sh` 로 전용 cmux workspace 를 먼저 만들고, 모든 `pane-create.sh` 호출은 `--workspace <created-workspace>` 를 명시한다.
- 생성한 workspace ref 는 즉시 `manifest.options.workspace_id` 에 기록한다. retry/relaunch 는 이 manifest 값만 신뢰한다.
- pane 재사용은 이 run 이 직접 생성했고 manifest 에 기록된 worker pane 에 한정한다. 사용자가 이미 열어둔 pane, focused pane, 출처가 불명확한 pane 은 재사용하지 않는다.

### 1. 입력 파싱
- 첫 인자: topic (또는 `--resume <run-id>`, `--status`, `--list`, `--gc`)
- options 추출

### 2. Sub-command 분기
- `--list` → `bash skills/cmux-pipeline/scripts/build-list.sh`
- `--status` → `bash skills/cmux-pipeline/scripts/build-status.sh [<run-id>]`
- `--gc` → `bash skills/cmux-pipeline/scripts/build-gc.sh [<days>]`
- `--resume <run-id>` → see Resume workflow (`references/resume.md`)
- 그 외 → 새 run 시작

### 3. 새 run 시작
1. preflight: `bash skills/cmux-pipeline/scripts/preflight.sh`
2. run-id 생성: `RUN_ID=$(bash .../scripts/manifest.sh gen-run-id "<topic>")`
3. manifest init: `bash .../scripts/manifest.sh init "$RUN_ID" "<topic>"`
4. options 적용: `bash .../scripts/manifest.sh update "$RUN_ID" '<jq expr>'`
5. feature branch 생성: `git checkout -b feat/<topic-slug>`
6. greenfield 모드 결정 (자동 detect → confirm)

### 4. Stage 진행
- Stage 1: `references/stage-spec.md`
- Stage 2: `references/stage-decompose.md`
- Stage 3: `references/stage-loop.md`
- Stage 4: `references/stage-integrate.md`

각 stage 끝에 checkpoint가 활성화되어 있으면 `▶ Stage N 완료` + resume 안내 출력하고 종료.

### 5. Failure 처리
- `references/failure-handling.md` 참조

### 6. 출력 디자인
- 명확한 진행 1줄/이벤트 (▶ Stage N/4, [phase X/Y] ✓ Ms)
- Quiet by default — codex 출력 표시 X. log 위치만 안내.
- `--verbose` 시 codex pane scrollback tail
