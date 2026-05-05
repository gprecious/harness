# Design: Append-only Event Log (`events.jsonl`) for `/improve`

- Date: 2026-05-05
- Status: Approved (brainstorming → writing-plans next)
- Scope: `/improve` (code-improver skill) only
- Origin: Inspired by the "Agent Harness" video's component (6) — append-only JSONL session log — adapted to our workflow-orchestrator layer

## 1. Problem

Current `/improve` derives plateau state by re-parsing `iteration-N.md` markdown files and editing `code-improver-state.md` in place. Two consequences:

- `plateau-detection.md` 알고리즘이 markdown 파싱에 의존하여 결정론적 reproducibility 가 약하다.
- 이터레이션 간 timeline (각 phase 의 시작·종료, category 별 PR 결과, verify 결과) 이 *구조화된 단일 소스* 로 존재하지 않는다 — wisdom-extractor 와 디버그가 여러 파일을 stitch 해야 한다.

## 2. Goal

`/improve` 가 single source of truth 로 사용할 수 있는 append-only event log (`events.jsonl`) 를 도입하여:

- plateau 판정이 한 파일을 grep 하면 끝나도록
- wisdom-extractor 와 `--resume` 의 입력 면적 축소
- 기존 `code-improver-state.md` / `iteration-N.md` 와 *공존* (replace 아님 — additive)

## 3. Non-Goals

- `/feature` 에 동일 패턴 적용 (별도 follow-up)
- JSON Schema 검증, `flock`, log rotation (Approach B 의 범위)
- wisdom-extractor 가 events.jsonl 을 *read* 하도록 보강 (이 design 은 *write* 책임만 다룸)
- Claude Code 의 PreCompact / SessionStart 훅과의 통합 (별도 follow-up)

## 4. Architecture

```
/improve
  → code-improver SKILL.md (각 phase 경계·결과)
    → bash log_event.sh <type> [k=v ...]
      → docs/code-improvement/<date>/events.jsonl   (append, 한 줄 = 한 event)
        ↑
        plateau-detection.md (read, ratio 도출)
```

- run dir: `docs/code-improvement/<YYYY-MM-DD>/` (기존)
- 새 파일: `events.jsonl` (run dir 안)
- 기존 파일 (`code-improver-state.md`, `iteration-N.md`) 는 그대로 유지

## 5. Event Schema

각 줄은 단일 JSON object. 필수 키:

- `ts` — ISO 8601 UTC, 예: `2026-05-05T01:23:45Z`
- `type` — 아래 카탈로그 중 하나

옵션 키:

- `iteration` — 정수 (run 단위 카운터, 1-based; `code-improver-state.md` 의 `current_iteration` 과 동일 값을 SKILL 본문이 전달. `run_started` / `run_halted` 에는 생략 가능)
- `phase` — `PREFLIGHT | AUDIT | PRIORITIZE | APPLY | VERIFY`
- 그 외는 event-specific payload

### Event 카탈로그 (9 종)

| type | 발생 시점 | payload (옵션 키) |
|---|---|---|
| `run_started` | /improve 진입 시 1회 | `mode` (full/audit/apply/verify), `args` (string), `harness_version` |
| `phase_start` | 각 phase 시작 | `iteration`, `phase` |
| `phase_end` | 각 phase 끝 | `iteration`, `phase`, `status` (ok/skip/error), `duration_s` (선택, SKILL 본문이 phase_start 의 ts 와 차이 계산해 전달) |
| `audit_completed` | AUDIT 종료 | `iteration`, `total_issues`, `by_priority` (object), `by_category` (object) |
| `category_applied` | category 별 PR/local commit 직후 | `iteration`, `category`, `pr_url\|null`, `files_changed`, `lines_added`, `lines_removed`, `verification` (object: `tests`/`lint`/`typecheck` booleans) |
| `verify_completed` | VERIFY 종료 | `iteration`, `metrics_after` (object: cognitive_complexity, dead_code, …) |
| `plateau_check` | VERIFY 직후 | `iteration`, `resolved`, `new`, `ratio`, `consecutive` |
| `iteration_completed` | 한 사이클 끝 | `iteration`, `status` (completed/plateau) |
| `run_halted` | plateau 확정 / max_iter / user stop | `reason`, `final_iteration` |

### 예시

```json
{"ts":"2026-05-05T01:23:45Z","type":"run_started","mode":"full","harness_version":"0.4.0"}
{"ts":"2026-05-05T01:23:46Z","type":"phase_start","iteration":1,"phase":"AUDIT"}
{"ts":"2026-05-05T01:24:10Z","type":"audit_completed","iteration":1,"total_issues":42,"by_priority":{"P1":12,"P2":18,"P3":8,"P4":4},"by_category":{"dead-code":15,"unused-imports":12,"complexity":8}}
{"ts":"2026-05-05T01:24:11Z","type":"phase_end","iteration":1,"phase":"AUDIT","status":"ok","duration_s":25}
{"ts":"2026-05-05T01:25:30Z","type":"category_applied","iteration":1,"category":"dead-code","pr_url":"https://github.com/owner/repo/pull/142","files_changed":12,"lines_added":0,"lines_removed":234,"verification":{"tests":true,"lint":true,"typecheck":true}}
{"ts":"2026-05-05T01:30:00Z","type":"plateau_check","iteration":1,"resolved":22,"new":8,"ratio":0.36,"consecutive":0}
{"ts":"2026-05-05T01:30:01Z","type":"iteration_completed","iteration":1,"status":"completed"}
```

## 6. Helper: `scripts/log_event.sh`

위치: `skills/code-improver/scripts/log_event.sh`

호출 인터페이스:

```bash
bash $SKILL_DIR/scripts/log_event.sh <event_type> [key=value ...]
```

- positional 첫 인자 = `type`
- 나머지는 `key=value` 쌍
- dotted key (`verification.tests=true`) → nested object 로 머지
- bare value 가 `true`/`false`/숫자 패턴이면 JSON primitive 로, 아니면 string 으로

내부 동작:

1. run dir 자동 탐색 — `find docs/code-improvement -maxdepth 2 -name code-improver-state.md | sort | tail -1` → `dirname`
2. run dir 못 찾으면 stderr 한 줄 + exit 1
3. `ts` 자동 주입 (`date -u +%FT%TSZ`), `type` 주입
4. `jq -cn` 으로 JSON 직렬화 (한 줄, escape 안전)
5. `>> $run_dir/events.jsonl` (POSIX append, 1 줄 ≤ ~4KB 가정 시 atomic)
6. exit 0 정상, exit 1 만 stderr

스킬 본문은 호출 실패를 무시한다 (event log 손실은 critical 아님 — 다만 stderr 는 hook 로그에서 확인 가능).

### Atomicity 가정

- /improve 는 single-process single-run (concurrent run 금지). 따라서 `flock` 불필요.
- 한 라인 ≤ PIPE_BUF (Linux 4096 바이트) 일 때 `>>` 는 atomic. payload 가 큰 경우 (예: `audit_completed.by_category` 가 100+ 카테고리) 라인이 4KB 를 넘을 수 있으나 single-writer 환경에서는 무관.

## 7. Reader 변경

### `references/plateau-detection.md`

Algorithm 섹션을 갱신:

```markdown
## Algorithm (events.jsonl 기반)

`docs/code-improvement/<date>/events.jsonl` 을 grep 으로 `plateau_check` 이벤트만 추출:

  jq -c 'select(.type=="plateau_check")' events.jsonl | tail -2

마지막 2 개의 `ratio` 가 모두 ≥ 0.80 이면 plateau 확정.

## Fallback

events.jsonl 가 없는 기존 run 에서는 이전 알고리즘 (iteration-N.md 의 "Plateau Check" 섹션 파싱) 으로 자동 fallback.
```

### `skills/code-improver/SKILL.md`

각 phase 경계와 카테고리 적용 후 한 줄씩 추가 (~9 곳):

- `/improve` 진입 직후: `log_event.sh run_started mode=$MODE harness_version=$VER` (`$VER` = `.claude-plugin/plugin.json` 의 `version` 필드)
- 각 phase 시작/종료: `log_event.sh phase_start iteration=$N phase=$P` / `phase_end ... status=ok duration_s=$D`
- AUDIT 완료: `log_event.sh audit_completed iteration=$N total_issues=$T ...`
- 카테고리 PR 완료: `log_event.sh category_applied iteration=$N category=$C pr_url=$U ...`
- VERIFY 완료: `log_event.sh verify_completed iteration=$N ...`
- plateau 판정 직후: `log_event.sh plateau_check iteration=$N resolved=$R new=$NEW ratio=$R consecutive=$C`
- 사이클 끝: `log_event.sh iteration_completed iteration=$N status=...`
- halt 시: `log_event.sh run_halted reason=... final_iteration=$N`

### `templates/code-improver-state.md`

frontmatter 에 한 줄 추가:

```yaml
events_log: events.jsonl
```

미래에 위치 변경 시 hop point 역할.

## 8. 테스트 전략

### 단위 테스트 (`tests/log_event.test.sh`)

bash 기반 4 케이스:

1. **simple event** — `log_event.sh phase_start iteration=1 phase=AUDIT` → events.jsonl 에 valid JSON 라인 1개, `ts`/`type`/`iteration`/`phase` 모두 포함
2. **dotted key nesting** — `log_event.sh category_applied verification.tests=true verification.lint=false` → `{"verification":{"tests":true,"lint":false}}`
3. **value type coercion** — `key=42`/`key=3.14`/`key=true`/`key=hello` → 각각 number/number/bool/string
4. **append-only** — 두 번 호출하면 라인 2개, 첫 라인 unchanged, 둘 다 valid JSON

### 통합 테스트 (수동)

dummy fixture 프로젝트에서 `/improve --audit` 1회 실행 후 events.jsonl 에 최소 `run_started`/`phase_start`/`audit_completed`/`phase_end` 4 종 이벤트 존재 확인.

## 9. Backward Compat & Rollout

- 기존 run 디렉터리에 `events.jsonl` 없을 수 있음 → reader 가 silent fallback (이전 algorithm 그대로)
- 신규 run 부터 자동 기록 — migration 스크립트 없음
- 버전: harness 0.4.0 (semver minor — 기능 추가, 호환 깨짐 없음)
- README / CHANGELOG 갱신: events.jsonl 도입 한 줄 + plateau-detection 알고리즘 갱신 한 줄

## 10. 변경 파일 요약

신규:

- `skills/code-improver/scripts/log_event.sh`
- `skills/code-improver/tests/log_event.test.sh` (단위 테스트)

수정:

- `skills/code-improver/SKILL.md` (~9 곳에 log_event.sh 호출 추가)
- `skills/code-improver/references/plateau-detection.md` (Algorithm 섹션 events.jsonl 우선 + fallback 명시)
- `skills/code-improver/templates/code-improver-state.md` (frontmatter `events_log: events.jsonl` 추가)
- `CHANGELOG.md` (0.4.0 entry)
- `README.md` (events.jsonl 한 줄 언급)
- `.claude-plugin/plugin.json` (version bump 0.3.0 → 0.4.0)

총 신규 2 + 수정 6 = 8 파일.

## 11. Risks & Open Questions

- `jq` 의존성 — 대부분 환경에서 기본 설치이지만 minimal Docker image 등에서 부재 가능. 현재 harness 의 다른 hook 들도 `jq` 를 직접 쓰지는 않음 (python3 사용). bash `printf` + 수동 escape 로 대체 가능하나 dotted-key nesting 이 복잡해짐. → 결정: jq 가 없으면 stderr warn + skip (event 누락은 비-치명).
- run dir 자동 탐색 시 동시에 두 run 디렉터리가 존재하면 `tail -1` 이 잘못된 dir 을 고를 수 있음. → mitigation: state.md 의 `current_phase != idle` 인 dir 만 후보로 필터.
- payload 크기 4KB 초과 (audit_completed.by_category 가 100+ 일 때) → 현재 시점에서 발생 가능성 낮으나, 발생 시 atomic append 보장 안 됨. 필요 시 추후 flock 추가 (Approach B).
