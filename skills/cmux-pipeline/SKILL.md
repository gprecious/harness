---
name: cmux-pipeline
description: GStack + GSD + Superpowers + build-loop을 cmux pane + codex CLI 기반으로 통합하는 자율 빌드 파이프라인. /build <topic> 한 줄로 spec → 페이즈 분해 → TDD 루프 → 통합까지 진행. 현재 세션은 launcher/final-report receiver 로 남고, 새 cmux workspace 의 remote orchestrator session 이 plan/refactor와 worker coordination을 담당한다. 컨텍스트는 /compact로 관리.
version: 0.7.0
tools: Read, Write, Edit, Bash, Grep, Glob, Agent
---

# cmux-pipeline

## Overview

`/build <topic>` 한 줄로 spec → 페이즈 분해 → contract → TDD 루프 → 통합 → learn 까지 자동 실행. 기존 harness skill 들과 독립.

6-stage:
1. **Spec** (GStack): `/office-hours` + `/autoplan`
2. **Decompose** (GSD): `/gsd-new-project` 또는 `/gsd-map-codebase`, `/gsd-plan-phase --prd`
3. **Contract** (harness): `contract-negotiator` agent → `contract.md`
4. **Loop** (build-loop + codex worker): per-phase RED → GREEN → review
5. **Integrate**: `superpowers:verification-before-completion`
6. **Learn** (harness): `wisdom-extractor` agent → `docs/wisdom/`

현재 세션은 launcher/final-report receiver 로만 동작한다. 새 run/resume 은 전용 cmux workspace 안에 remote orchestrator Codex session 을 만들고, 그 session 이 plan/spec/test scenario/refactor와 worker coordination을 담당한다. long-lived codex worker는 같은 workspace 안의 별도 cmux pane에서 test code/구현을 작성한다. 컨텍스트는 codex `/compact` 명령으로 관리.

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
| `--checkpoint=<stages>` | `spec,decompose,contract` | 정지점. `none` 으로 풀-오토 |
| `--skip=<stages>` | `` | `spec,decompose` 스킵 가능 |
| `--greenfield` / `--brownfield` | auto-detect | GSD 진입점 |
| `--phase-timeout=<sec>` | `1200` | phase timeout |
| `--compact-every=<n>` | auto | N 페이즈마다 강제 /compact |
| `--no-confirm` | `false` | confirm 없이 진행 |
| `--dry-run` | `false` | preflight 만 |
| `--verbose` | `false` | codex pane scrollback tail |
| `--model=<name>` | (codex default) | codex 모델 override |
| `--keep-workspace` | `false` | 정상 완료/abort 후에도 cmux workspace 유지 (post-mortem 디버깅용). 기본은 자동 close. |

## Dependencies (preflight 검증)

- cmux CLI (Apple silicon 또는 Linux)
- codex CLI (OpenAI)
- jq, git, bats-core (테스트 시)
- claude plugin: gstack, gsd, build-loop, superpowers, ralph-loop

자세한 내부 구조는 `references/` 참조.

## Orchestration Workflow

`/build` 가 호출되면 현재 세션은 launcher 로 동작하고, 새 workspace 안의 remote orchestrator session 이 실제 cmux-pipeline orchestration 을 수행한다.

### Launcher / Remote Orchestrator Split

- `/build` 를 실행한 현재 세션은 preflight 가능한 sub-command(`--status`, `--list`, `--gc`) 외에는 직접 orchestration 하지 않는다.
- 새 run/resume 은 `scripts/orchestrator-launch.sh --cwd "$REPO_ROOT" --request "<original /build args>"` 로 시작한다.
- launcher 는 focused pane ref 를 `CMUX_LAUNCHER_PANE` 로 기록하고, remote orchestrator 에게 최종 보고 대상만 알려준다.
- launcher 는 작업 중 progress message 를 보내거나 worker pane 과 대화하지 않는다.
- remote orchestrator 는 `CMUX_WORKSPACE_ID` 로 지정된 새 workspace 안에서만 progress, retry, worker communication 을 처리한다.
- remote orchestrator 는 completed/paused/failed/aborted 중 하나에 도달했을 때 `CMUX_LAUNCHER_PANE` 으로 exactly one final report 만 보낸다.
- final report 전송은 예외적으로 `PANE_SEND_ALLOW_FOCUSED=1 scripts/pane-send.sh --pane "$CMUX_LAUNCHER_PANE" --text "<final report>"` 를 사용할 수 있다.

### Workspace / Pane Isolation Hard Rule

- 절대 launcher/current focused workspace 에 worker pane 을 만들거나 입력을 보내지 않는다.
- 새 run 은 반드시 `orchestrator-launch.sh` 가 전용 cmux workspace 를 먼저 만들고, remote orchestrator 와 모든 worker pane 은 그 workspace 안에만 둔다.
- 모든 `pane-create.sh` 호출은 `--workspace "$CMUX_WORKSPACE_ID"` 또는 manifest 의 `options.workspace_id` 를 명시한다.
- 생성한 workspace ref 는 즉시 `manifest.options.workspace_id` 에 기록한다. retry/relaunch 는 이 manifest 값만 신뢰한다.
- pane 재사용은 이 run 이 직접 생성했고 manifest 에 기록된 worker pane 에 한정한다. 사용자가 이미 열어둔 pane, focused pane, 출처가 불명확한 pane 은 재사용하지 않는다.
- **메시지 송신 직전 pane ID 재검증 (필수)**: launcher → orchestrator, orchestrator → worker, worker → orchestrator 등 모든 cross-pane send 직전에 다음 3 단계를 통과해야 한다.
  1. 송신 대상 pane ref 가 `manifest.options.workspace_id` 와 동일한 workspace 안에 있는지 `cmux tree` 또는 `cmux pane list --workspace "$CMUX_WORKSPACE_ID"` 로 확인.
  2. 의도한 role 과 pane ID 매핑이 manifest 의 `worker_panes` / `orchestrator_pane` / `launcher_pane_id` 기록과 일치하는지 대조. 일치하지 않으면 send 중단.
  3. 발동 직전 한 줄 trace: `send: from=<role>(surface:X workspace:N) to=<role>(surface:Y workspace:N) channel=<purpose>` 를 stage log 에 남긴다.
- 검증 실패 시 send 를 중단하고 manifest 에 mismatch 사실을 기록한 뒤 `failure-handling.md` 의 critical 절차를 따른다. 잘못된 pane 에 한 번이라도 메시지가 들어가면 사용자 컨텍스트가 오염된 것으로 간주하고 그 run 은 paused 처리한다.

### Workspace Lifecycle

생성과 close 가 대칭이다. 생성 시점은 launcher 의 `orchestrator-launch.sh` 실행 시점이다. 자동 close 시점은 4가지:

| 시점 | 트리거 | 동작 |
|---|---|---|
| Stage 6 (Learn) 완료 | `stage-learn.sh` 가 `manifest.stages.learn.status = completed` 로 마킹한 직후 | `manifest.options.keep_workspace` 가 false 면 final report 전송 후 workspace-close. status = `completed`. |
| 사용자 abort | `failure-handling.md` 의 2회 실패 / contract 실패 prompt 에서 `[a]` 선택 | manifest.status = `aborted`, workspace-close. resume 불가. |
| `/build --gc` | old run 디렉토리 삭제 직전 | manifest 의 workspace_id 가 살아있으면 close 후 rm -rf. orphan workspace 누적 방지. |
| `preflight` orphan sweep | 새 run 시작 시 `preflight.sh` 가 cmux 의 `cmux-pipeline:<run-id>` 패턴 workspace 들을 스캔 | manifest 가 없거나 status in (completed, aborted) 인 것만 close. running/paused 는 보존. |

`paused` 상태는 resume 가능하므로 close 하지 않는다. 디버깅용으로 정상 종료 후에도 workspace 를 살리고 싶으면 `--keep-workspace` 사용.

### 1. 입력 파싱
- 첫 인자: topic (또는 `--resume <run-id>`, `--status`, `--list`, `--gc`)
- options 추출

### 2. Sub-command 분기
- `--list` → `bash skills/cmux-pipeline/scripts/build-list.sh`
- `--status` → `bash skills/cmux-pipeline/scripts/build-status.sh [<run-id>]`
- `--gc` → `bash skills/cmux-pipeline/scripts/build-gc.sh [<days>]`
- `--resume <run-id>` → see Resume workflow (`references/resume.md`)
- 그 외 → 새 run 시작

### 3. 새 run 시작 (launcher)

1. 현재 세션에서 `bash skills/cmux-pipeline/scripts/orchestrator-launch.sh --cwd "$REPO_ROOT" --request "<original /build args>"` 실행
2. 출력된 `run_id`, `workspace`, `orchestrator_pane` 는 launcher 의 로컬 추적 정보일 뿐이며 progress reporting 으로 사용하지 않는다.
3. remote orchestrator 가 최종 보고를 보낼 때까지 현재 세션은 추가 send 를 하지 않는다.

### 4. 새 run 시작 (remote orchestrator)
1. preflight: `bash skills/cmux-pipeline/scripts/preflight.sh`
2. run-id 결정: launcher prompt 의 `RUN_ID`/`CMUX_PIPELINE_RUN_ID` 를 우선 사용. 없을 때만 `manifest.sh gen-run-id`.
3. manifest init: `bash .../scripts/manifest.sh init "$RUN_ID" "<topic>"`
4. options 적용: `manifest.options.workspace_id = "$CMUX_WORKSPACE_ID"`, 필요 시 `launcher_pane_id`, `keep_workspace`, `model`, `sandbox` 도 기록
5. feature branch 생성: `git checkout -b feat/<topic-slug>`
6. greenfield 모드 결정 (자동 detect → confirm)

### 5. Stage 진행
- Stage 1: `references/stage-spec.md`
- Stage 2: `references/stage-decompose.md`
- Stage 3: `references/stage-contract.md`
- Stage 4: `references/stage-loop.md`
- Stage 5: `references/stage-integrate.md`
- Stage 6: `references/stage-learn.md`

각 stage 끝에 checkpoint가 활성화되어 있으면 `▶ Stage N 완료` + resume 안내 출력하고 종료.

### 6. Failure 처리
- `references/failure-handling.md` 참조

### 7. 출력 디자인
- 명확한 진행 1줄/이벤트 (▶ Stage N/6, [phase X/Y] ✓ Ms)
- Quiet by default — codex 출력 표시 X. log 위치만 안내.
- `--verbose` 시 codex pane scrollback tail
- 출력은 remote orchestrator workspace 안에서만 표시한다. launcher pane 에는 final report 전까지 아무 progress 도 보내지 않는다.
