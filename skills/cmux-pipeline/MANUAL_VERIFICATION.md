# cmux-pipeline v0.4.0 검증 로그

날짜: 2026-05-07
환경: macOS Darwin 25.3, cmux 0.62.2 (77), codex-cli 0.128.0, bats 1.13.0, jq 1.8.1

## 자동화 검증 (subagent-driven 실행 시점)

### bats 결과

| Suite | Total | Pass | Fail | Skip |
|---|---|---|---|---|
| unit | 81 | 81 | 0 | 0 |
| integration | 51 | 50 | 0 | 1 |
| e2e | 3 | 3 | 0 | 0 |

(integration 의 1 skip 은 `pane-compact: timeout test` — 실 cmux pane 의 echo 동작과 충돌해 flake 가 큰 시뮬레이션이라 의도적으로 skip 표기됨. unit 과 e2e 는 skip 없음.)

### 모든 script 의 --help 동작 확인

```bash
for s in skills/cmux-pipeline/scripts/*.sh; do
  echo "=== $s ==="
  bash "$s" --help 2>&1 | head -3
done
```

대부분의 스크립트가 `--help` 응답 정상 (`Usage:` 출력 + exit 0).

다음 스크립트들은 `--help` 를 별도 플래그로 처리하지 않고 일반 인자로 취급해 다른 메시지로 종료한다 (정상 호출 경로에서는 문제 없으나, 플래그 일관성 차원에서 차후 보강 후보):

- `stage-decompose-finalize.sh`: `.planning/phases not found` 출력 후 exit 0 (`--help` 가 디렉토리 인자로 해석됨; 동작 자체는 안전)
- `stage-loop.sh`: `<worker-pane-id> required` 출력 후 exit 1
- `phase-prompt-build.sh`: `<phase-id> required` + `Usage:` 라인 노출 후 exit 1
- `stage-spec-finalize.sh`: `gstack-out dir not found: …` 출력 후 exit 1

## Pending — Human Manual Verification

다음 검증은 실제 인터랙티브 claude 세션에서 사용자가 직접 수행해야 하며, subagent-driven 실행 단계에서는 자동화할 수 없다:

### 1. 실제 sandbox 프로젝트에서 `/build` 1회 실행

```bash
mkdir -p /tmp/cmux-pipeline-manual-verify && cd /tmp/cmux-pipeline-manual-verify
git init -q && git commit --allow-empty -m "init"
# 새 claude code 세션을 이 디렉토리에서 열고:
# /build "add hello world function"  --checkpoint=spec,decompose,loop
```

### 2. 각 stage 결과 수동 확인

- Stage 1 (spec / GStack `/office-hours`): 인터랙티브 design 문답 + `~/.gstack/projects/<slug>/<user>-<branch>-design-<datetime>.md` 생성 확인
- Stage 2 (decompose / GSD `/gsd-plan-phase`): `.planning/phases/01-*/01-01-PLAN.md` 생성 확인
- Stage 3 (loop / codex worker): cmux 새 pane + codex 인터랙티브 시작; 페이즈 prompt 전송 후 sentinel `==DONE==<run-id>==phase-<id>==SUCCESS==` 수신
- Stage 4 (integrate): `superpowers:verification-before-completion` 통과 → manifest `status = "completed"`

### 3. manifest.json 무결성 확인

```bash
cat .pipeline/runs/<run-id>/manifest.json | jq .
# schema_version, run_id, topic, status, stages.* 모두 채워져있고
# atomic write 흔적 (.tmp 파일) 없음을 확인
```

### 4. Phase 0 deferred 검증 (Task 32 가 마지막 보루)

다음 항목들은 Phase 0 discovery 단계에서 verified=NO 로 표시되어 Task 32 까지 미뤘다:

- `notes/codex-cli-flags.md` §"compaction installed" 문자열 — 실제 codex TUI 에서 `/compact` 실행 결과 화면을 읽어 정확한 완료 마커 capture; `pane-compact.sh` 의 marker 폴링 로직을 그 결과에 맞춰 갱신할 수 있음.
- `notes/external-skills-io.md` §"Pending — Task 32 재확인":
  - GStack design-doc 파일명의 `<branch>` 슬래시 처리 (`feature/x` → `feature-x` 인지)
  - GSD `padded_phase` 가 phase 100+ 시 자릿수 어떻게 늘어나는지
  - GStack/GSD 의 incremental update 동작
  - 옵션 GSD artifact (VALIDATION/PATTERNS/SKELETON) 의 default visibility

이 항목들은 1회 실제 실행으로 모두 확인 가능. 실행 후 결과를 본 파일에 추가 기록하고 finalize 스크립트(stage-spec/decompose-finalize)의 가정을 갱신.

### 5. 결과 기록 템플릿

(Manual verification 후 아래 채울 것)

```markdown
## 실측 결과 (YYYY-MM-DD)

### /build "add hello world function"

- 총 시간: <Xm>
- Stage 1 (spec): PASS / FAIL — <노트>
- Stage 2 (decompose): PASS / FAIL — <페이즈 수>
- Stage 3 (loop): PASS / FAIL — <페이즈 통과율, /compact 횟수>
- Stage 4 (integrate): PASS / FAIL

### 발견된 이슈

- (issue 1)
- (issue 2)

### 후속 조치

- (필요한 수정)
```
