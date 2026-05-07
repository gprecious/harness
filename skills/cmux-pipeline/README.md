# cmux-pipeline

cmux + codex CLI 기반 자율 빌드 파이프라인.

`/build <topic>` 한 줄로 spec → 페이즈 분해 → TDD 루프 → 통합까지 자동.

## 4-Stage Pipeline

1. **Spec** (GStack): `/office-hours` (+ optional `/autoplan`) — design doc 생성
2. **Decompose** (GSD): `/gsd-new-project` 또는 `/gsd-map-codebase` + `/gsd-plan-phase` — 페이즈 분해
3. **Loop** (codex worker via cmux pane): per-phase RED → GREEN → review
4. **Integrate**: `superpowers:verification-before-completion` — 전체 검증

claude orchestrator (현재 세션) 가 plan/spec/refactor 담당, long-lived codex worker 가 cmux pane 안에서 test code/구현 담당. 컨텍스트는 codex `/compact` 으로 관리.

## Quick Start

```bash
# 의존성 install
brew install cmux jq gh bats-core
npm install -g @openai/codex

# Skills (claude plugin 마켓플레이스)
git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack \
  && (cd ~/.claude/skills/gstack && ./setup --no-prefix)
npx -y get-shit-done-cc@latest --global --claude
claude plugin marketplace add tyroneross/build-loop
claude plugin install build-loop@build-loop

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

## Architecture

자세한 디자인 결정은 `SKILL.md` + `references/{stage-spec,stage-decompose,stage-loop,stage-integrate,resume,failure-handling}.md` 참조.

## Testing

```bash
cd harness/skills/cmux-pipeline
bats tests/unit/         # ~60 unit tests
bats tests/integration/  # cmux 의존 (cmux daemon 필요)
bats tests/e2e/          # full pipeline 시뮬레이션
```

## License

Repo와 동일 (harness 의 license 따름).
