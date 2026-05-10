# cmux-pipeline

cmux + codex CLI 기반 자율 빌드 파이프라인.

`/build <topic>` 한 줄로 spec → 페이즈 분해 → contract → TDD 루프 → 통합 → wisdom 추출까지 자동.

## 6-Stage Pipeline

1. **Spec** (gstack): `/office-hours` (+ optional `/autoplan`) — design doc 생성
2. **Decompose** (gsd): `/gsd-new-project` 또는 `/gsd-map-codebase` + `/gsd-plan-phase` — 페이즈 분해
3. **Contract** (harness): `contract-negotiator` agent → `contract.md` — 페이즈 간 계약 정의
4. **Loop** (build-loop + codex worker via cmux pane): per-phase RED → GREEN → review
5. **Integrate**: `superpowers:verification-before-completion` — 전체 검증
6. **Learn** (harness): `wisdom-extractor` agent → `docs/wisdom/{patterns,decisions,evaluations,test-recipes}/` — 재사용 자산 누적

claude orchestrator (현재 세션) 가 plan/spec/refactor/test scenario 담당, long-lived codex worker 가 cmux pane 안에서 test code/구현 담당. 컨텍스트는 codex `/compact` 으로 관리.

## Quick Start

```bash
# 외부 바이너리
brew install cmux jq git gh bats-core
npm install -g @openai/codex

# Plugin 의존성
git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack \
  && (cd ~/.claude/skills/gstack && ./setup --no-prefix)
npx -y get-shit-done-cc@latest --global --claude
claude plugin marketplace add tyroneross/build-loop
claude plugin install build-loop@build-loop
claude plugin install superpowers@claude-plugins-official
claude plugin install ralph-loop@claude-plugins-official

# 사용
/build "add auth flow"
/build --resume 20260507-1430-add-auth-flow
/build --status
/build --list
/build --gc 30
```

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
| `--phase-timeout=<sec>` | `1200` | phase 당 timeout |
| `--compact-every=<n>` | auto | N 페이즈마다 강제 codex `/compact` |
| `--no-confirm` | `false` | confirm 없이 진행 |
| `--dry-run` | `false` | preflight 만 |
| `--verbose` | `false` | codex pane scrollback tail |
| `--model=<name>` | (codex 기본) | codex 모델 override |
| `--keep-workspace` | `false` | 정상 완료/abort 후에도 cmux workspace 유지 (post-mortem 디버깅용) |

## Workspace Lifecycle (v0.6.1+)

`/build` 가 cmux workspace 를 자동 관리합니다. 사용자의 focused workspace 는 절대 건드리지 않습니다.

| 시점 | 동작 |
|---|---|
| Stage 4 (Loop) 진입 직전 | 새 workspace 생성 (제목: `cmux-pipeline:<run-id>`) — 사용자 view 무영향 |
| Stage 6 (Learn) 정상 완료 | 자동 close (`--keep-workspace` 미지정 시) |
| 사용자 abort `[a]` | manifest.status = `aborted` 마킹 + close |
| `/build --gc` | old run 디렉토리 삭제 시 workspace 도 함께 close |
| 새 run 시작 시 preflight | orphan workspace (manifest 없거나 completed/aborted) 자동 sweep — `paused` 는 보존 |

## Architecture

자세한 디자인 결정은 `SKILL.md` + `references/{stage-spec,stage-decompose,stage-contract,stage-loop,stage-integrate,stage-learn,resume,failure-handling}.md` 참조.

### 디렉토리 구조

```text
<repo-root>/
├── .pipeline/runs/<run-id>/
│   ├── manifest.json                   # run 상태 (atomic write)
│   ├── spec/                           # Stage 1 산출
│   ├── decompose/phases/<phase-id>/    # Stage 2 산출 — phase 별 PLAN.md
│   ├── contract.md                     # Stage 3 산출
│   └── phases/<phase-id>/              # Stage 4 progress — prompt.md, status.json, error.log
└── docs/wisdom/                        # Stage 6 산출 (cross-run 누적)
    ├── patterns/
    ├── decisions/
    ├── evaluations/
    ├── test-recipes/
    └── index.md
```

`.pipeline/` 는 ephemeral run state (gitignore 됨). `docs/wisdom/` 은 commit 대상 자산.

## Testing

```bash
cd harness/skills/cmux-pipeline
bats tests/unit/         # 109+ unit tests
bats tests/integration/  # cmux 의존 (cmux daemon 필요)
bats tests/e2e/          # full pipeline 시뮬레이션
```

## License

Repo와 동일 (harness 의 license 따름).
