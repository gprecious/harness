# Universal Feature Harness

Claude Code 용 multi-skill plugin. 세 가지 자율 워크플로우를 제공:

- **`/feature`** — TDD Generator-Evaluator 로 단일 feature 를 plan → contract → test → build → evaluate → integrate → learn 사이클로 처리
- **`/build`** — cmux pane + codex CLI 기반 6-stage 자율 빌드 파이프라인 (그린필드 / 큰 리팩토링용)
- **`/improve`** — 기존 코드베이스의 audit → prioritize → auto-fix → verify 4-phase 개선 루프

## Installation

```bash
claude plugin marketplace add gprecious/harness
claude plugin install harness@harness
```

업그레이드:
```bash
claude plugin marketplace update harness
claude plugin uninstall harness && claude plugin install harness@harness
```

## `/feature` — Feature Development (v0.1.0+)

```bash
# Initialize harness for a project (profiles tech stack, design system, conventions)
/feature --init

# Run feature development pipeline
/feature "description"

# Resume interrupted feature run
/feature --resume
```

### Pipeline Overview

- **Phase 0** — Plan
- **Phase 1** — Contract
- **Phase 2** — Test
- **Phase 3** — Build
- **Phase 4** — Evaluate
- **Phase 5** — Integrate
- **Phase 6** — Learn

## `/build` — Autonomous Build Pipeline (v0.5.0+)

cmux + codex CLI 위에서 동작하는 6-stage 자율 빌드. claude orchestrator (현재 세션) 가 plan/spec/refactor 담당, long-lived codex worker 가 cmux pane 안에서 test code/구현 담당. v0.6.1+ 부터 dedicated cmux workspace 가 자동 생성·정리됩니다 (사용자 focused workspace 무영향).

```bash
# 새 run
/build "add user auth flow"

# checkpoint 없이 풀-오토
/build "topic" --checkpoint=none

# 디버깅용으로 종료 후 cmux workspace 살려두기
/build "topic" --keep-workspace

# Run 관리
/build --resume <run-id>
/build --status
/build --list
/build --gc 30
```

### Stages

1. **Spec** (gstack `/office-hours`+`/autoplan`)
2. **Decompose** (gsd `/gsd-plan-phase`)
3. **Contract** (`contract-negotiator` agent)
4. **Loop** (build-loop + codex worker, per-phase RED → GREEN)
5. **Integrate** (`superpowers:verification-before-completion`)
6. **Learn** (`wisdom-extractor` agent → `docs/wisdom/`)

자세한 사용법은 `skills/cmux-pipeline/README.md` 와 `skills/cmux-pipeline/SKILL.md` 참조.

### `/build` 의 외부 의존성

`/build` 만 사용하는 경우에도 다음을 따로 설치해야 합니다:

```bash
brew install cmux jq git gh bats-core
npm install -g @openai/codex

git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack \
  && (cd ~/.claude/skills/gstack && ./setup --no-prefix)
npx -y get-shit-done-cc@latest --global --claude
claude plugin marketplace add tyroneross/build-loop
claude plugin install build-loop@build-loop
claude plugin install superpowers@claude-plugins-official
claude plugin install ralph-loop@claude-plugins-official
```

## `/improve` — Codebase Improvement (v0.3.0+)

Independent from `/feature`. Use `/improve` to iteratively improve an existing codebase through a 4-phase audit-prioritize-apply-verify workflow. Auto-fixes safe Priority 1-2 issues (dead code, magic literals, cognitive complexity reduction) into category-split PRs; reports Priority 3-5 structural/design suggestions for manual review.

### Commands

- `/improve --init` — First-time setup. Detects environment, runs web research, generates 5 project-specific reference docs
- `/improve` — Full workflow: audit → prioritize → apply fixes → verify
- `/improve --audit` — Audit only, no fixes
- `/improve --apply` — Apply last audit's Priority 1-2 fixes as category-split PRs
- `/improve --category <name>` — Restrict to one category (e.g. `dead-code`)
- `/improve --verify` — Re-audit to check progress against previous iteration; detects plateau
- `/improve --resume` — Recover from interrupted iteration

### Outputs

- `docs/code-improver/references/` — 5 project-specific reference docs (refreshed monthly)
- `docs/code-improver/code-improver-state.md` — Persistent state
- `docs/code-improvement/YYYY-MM-DD/iteration-N.md` — Per-iteration reports with auto-fixes and suggestions
- `docs/code-improvement/YYYY-MM-DD/summary.md` — Cumulative report (generated on plateau)
- `.code-improver-ignore` — Project-root glob rules (similar syntax to gitignore)
- `docs/code-improvement/YYYY-MM-DD/events.jsonl` (v0.4.0+) — Append-only structured event log used by plateau detection and crash recovery

### Design & Plan

- Design: `docs/plans/2026-04-16-code-improver-design.md` (parent repo)
- Implementation plan: `docs/plans/2026-04-16-code-improver-impl.md` (parent repo)

## Required Plugins

`/feature` 가 의존하는 외부 plugin:

- feature-dev
- code-review
- pr-review-toolkit
- security-guidance
- superpowers

`/build` 의 외부 의존성은 위 "/build 의 외부 의존성" 섹션 참조 (cmux, codex, gstack, gsd, build-loop, ralph-loop 등). `/improve` 는 별도 외부 plugin 없이 동작합니다.
