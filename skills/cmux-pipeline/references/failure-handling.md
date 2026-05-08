# Failure Handling

## phase 결과 라우팅 (stage-loop.sh가 수행)

| sentinel | 조치 |
|---|---|
| SUCCESS | commit_sha 캡처, 다음 phase |
| NEEDS_HELP | claude orch가 prompt 보강 → 같은 pane 1회 재시도 |
| FAILED | fresh pane + codex 재시작 → 재시도 |
| TIMEOUT (exit 124) | fresh pane + 단순화 prompt 재시도 |
| 2회 실패 | manifest paused, 사용자 알림, 종료 (exit 2) |

## 사용자 confirm prompt (2회 실패 시)

```
✗ phase 0004 middleware: 2회 실패
  마지막 에러:
    .pipeline/runs/.../phases/0004-middleware/error.log:42-58
  옵션:
    [r] 재시도 (fresh pane)
    [s] 스킵 (manifest 표시 후 다음 페이즈)
    [a] 중단 (manifest aborted, workspace 자동 close)
    [e] error.log 열기
  선택 [r/s/a/e]:
```

`[a] 중단` 선택 시 orch 가:
1. `bash scripts/manifest.sh update <run-id> '.status = "aborted" | .checkpoints.aborted_at = "loop:<phase-id>" | .checkpoints.paused_reason = "user aborted after phase failure"'`
2. `manifest.options.workspace_id` 가 있고 `manifest.options.keep_workspace` 가 true 가 아니면 `bash scripts/workspace-close.sh --workspace "$WORKSPACE"` (idempotent — 실패해도 무시)
3. exit 2

> 차이: `paused` 는 resume 가능 (workspace + worker pane 보존), `aborted` 는 사용자가 명시적으로 종료 의사를 밝힌 상태이므로 workspace 도 함께 정리한다.

## error.log 작성

`stage-loop.sh` 에서 phase 실패 시 직전 200줄을 `phases/<phase-id>/error.log`로 dump.

## resume from paused

`/build --resume <run-id>` 실행 시:

1. `bash scripts/resume-prepare.sh <run-id>` 호출 → JSON 메타
2. `resume_from` 필드 확인:
   - `loop:<phase-id>` → 해당 phase 부터 재시도 (failed_phases 에서 첫 phase)
   - 그 외 stage → 해당 stage 부터 재실행
3. worker_pane_id 가 살아있으면 재사용; 없으면 fresh pane + codex-launch

## Stage 3 (contract) 실패

`contract-negotiator` agent 가 contract.md 를 쓰지 못한 경우:

```bash
bash scripts/manifest.sh update <run-id> \
  '.stages.contract.status = "failed"
   | .status = "paused"
   | .checkpoints.paused_at = "contract"
   | .checkpoints.paused_reason = "<reason>"'
```

사용자에게 안내:
```
✗ contract 실패: <reason>
  옵션:
    [r] contract-negotiator 재dispatch
    [m] contract.md 수동 작성 후 stage-contract.sh 재실행
    [a] 중단 (workspace 자동 close)
  선택 [r/m/a]:
```

`[a] 중단` 선택 시 orch 가:
1. `bash scripts/manifest.sh update <run-id> '.status = "aborted" | .checkpoints.aborted_at = "contract"'`
2. `manifest.options.workspace_id` 가 있고 `manifest.options.keep_workspace` 가 true 가 아니면 `bash scripts/workspace-close.sh --workspace "$WORKSPACE"`
3. exit 2

resume from `contract`:
- `/build --resume <run-id>` 시 `resume_from = "contract"` 라우팅.
- orch 가 `references/stage-contract.md` 절차 처음부터 재실행.

## Stage 6 (learn) 실패

`stage-learn.sh` 가 exit 1 (wisdom artifact 0 개) 인 경우:
- `manifest.stages.learn.status = "failed"` 만 마킹, `manifest.status = "completed"` 유지 (run 성공).
- 사용자에게 경고만 — 차단 X.
- resume 시 `--resume <run-id>` 의 `resume_from = "learn"` 으로 재시도 가능.
