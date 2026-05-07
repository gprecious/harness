# Stage 3: Loop

## 목표
- `decompose/phases/<phase-id>/` 디렉토리들을 순차 실행
- 각 페이즈: prompt 생성 → codex pane 에 dispatch → sentinel 대기 → 결과 기록
- 실패 시 retry 라우팅, 2회 실패 시 paused (exit 2)

## 절차 (claude orch)

1. manifest 갱신: `stages.loop.status = "running"`
   ```bash
   bash scripts/manifest.sh update <run-id> '.stages.loop.status = "running"'
   ```
2. worker pane 생성 + codex 인터랙티브 시작:
   ```bash
   pane=$(bash scripts/pane-create.sh --direction down)
   bash scripts/codex-launch.sh --pane "$pane" --cwd "$REPO_ROOT"
   bash scripts/manifest.sh update <run-id> ".stages.loop.worker_pane_id = \"$pane\""
   ```
3. `bash scripts/stage-loop.sh <run-id> <pane>` 호출 → 본 스크립트가 모든 페이즈를 처리.
4. 모든 phase SUCCESS → `stage-loop.sh` 가 manifest `stages.loop.status = "completed"` 로 마킹하고 exit 0.
5. 한 페이즈가 2회 연속 실패 → `stage-loop.sh` 가 manifest 를 `paused` 로 마킹하고 exit 2 — orch 가 사용자에게 알리고 종료한다.

## 페이즈 처리 절차 (stage-loop.sh 가 수행)

`.pipeline/runs/<run-id>/decompose/phases/` 의 디렉토리를 sort 순서대로 순회한다 (`01-*`, `02-*`, ...).
각 phase dir 마다:

1. **context check** — manifest 의 `stages.loop.context_estimate_tokens > $COMPACT_THRESHOLD` (기본 218000) 면
   - `bash scripts/pane-compact.sh --pane "$pane" --marker "C_<phase-id>"`
   - manifest: `compactions += 1`, `context_estimate_tokens = 50000`
2. **prompt build** — `bash scripts/phase-prompt-build.sh <run-id> <phase-id>` (산출물: `.pipeline/runs/<run-id>/phases/<phase-id>/prompt.md`)
3. **status init** — `bash scripts/phase-status.sh init <run-id> <phase-id> <pane>`
4. **attempt 1 dispatch**:
   - `result=$(bash scripts/phase-dispatch.sh --pane <pane> --run-id <run-id> --phase-id <phase-id> --timeout $T --poll 5)`
   - exit 0 + SUCCESS → `commit_sha = git rev-parse HEAD`, `phase-status complete ... SUCCESS`, manifest `completed_phases += [<phase-id>]`, `context_estimate_tokens += 30000`, 다음 페이즈로 continue
5. **attempt 2 라우팅**:
   - `NEEDS_HELP` → 같은 pane 에서 재시도
   - `FAILED` / `TIMEOUT` (exit 124) → `pane-close.sh` 후 `pane-create.sh` + `codex-launch.sh` 로 fresh pane 만들고 재시도; manifest `worker_pane_id` 갱신
   - `phase-status.sh retry <run-id> <phase-id> <new-pane>` 로 attempts 증가
6. **attempt 2 결과**:
   - SUCCESS → 동일하게 commit + manifest 갱신
   - 그 외 → `phase-status.sh complete ... FAILED`, manifest `failed_phases += [<phase-id>] | .status = "paused" | .checkpoints.paused_at = "loop:<phase-id>" | .checkpoints.paused_reason = "phase failed twice"`, **exit 2**

## 환경변수

| 변수 | 기본 | 의미 |
|---|---|---|
| `PHASE_TIMEOUT` | `1200` | 한 phase 의 dispatch 대기 한도 (sec) |
| `COMPACT_THRESHOLD` | `218000` | `context_estimate_tokens` 가 이 값 초과 시 `/compact` |
| `PIPELINE_ROOT` | `.pipeline/runs` | 파이프라인 루트 |
| `CMUX_WORKSPACE_ID` | (자동) | `manifest.options.workspace_id` 가 있으면 stage-loop 가 자동 export. 호출자가 미리 set 하지 않아도 retry pane 이 isolated workspace 에 생성됨. |

## manifest options

orch 가 `stages.loop.status = "running"` 직전 `manifest.options.*` 에 기록 가능한 옵션:

| 키 | 타입 | 기본 | 의미 |
|---|---|---|---|
| `model` | string | (codex 기본) | retry 시 codex-launch 에 `--model <value>` 전달 |
| `sandbox` | string | (codex 기본) | retry 시 codex-launch 에 `--sandbox <value>` 전달 |
| `workspace_id` | string | (현 focused) | stage-loop 가 `CMUX_WORKSPACE_ID` export. retry pane 이 사용자 active workspace 가 아닌 isolated workspace 에 생성됨. orch 는 시작 시 `bash scripts/workspace-create.sh` 로 만든 ref 를 여기 기록하고, 종료 시 `workspace-close.sh` 로 정리해야 한다. |

## 다음 단계

`stage-loop.sh` 종료 후:
- exit 0 → orch 가 `stage-integrate` (Task 22+) 로 진입
- exit 2 → orch 가 `manifest.checkpoints` 를 읽어 사용자에게 paused phase 알리고 종료
