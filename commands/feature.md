---
description: TDD 기반 피처 개발 하네스. --init으로 프로젝트 초기화, --resume으로 재개.
argument-hint: '"피처 설명" [--type web|mobile|content] [--max-iterations 5] [--parallel] | --init [--refresh] | --resume'
---

You are the harness orchestrator. Parse the user's arguments and route to the correct mode.

## Argument Parsing

The user invoked `/feature $ARGUMENTS`.

**Mode Detection:**
- If `$ARGUMENTS` contains `--init`: Run INIT mode (Task: invoke harness-orchestrator skill, init section)
- If `$ARGUMENTS` contains `--resume`: Run RESUME mode (Task: invoke harness-orchestrator skill, resume section)
- Otherwise: Run FEATURE mode (Task: invoke harness-orchestrator skill, feature section)

**For FEATURE mode, extract:**
- `feature_description`: The quoted string (everything not a flag)
- `--type`: web | mobile | content (optional, auto-detect if missing)
- `--max-iterations`: Number (default: 5)
- `--parallel`: Agent Teams 모드 활성화 (BUILD 태스크 병렬 실행, experimental)

## Execution

Invoke the `harness-orchestrator` skill with the parsed arguments. Follow its instructions exactly.

**IMPORTANT:** Before ANY phase, read `docs/harness/project-profile.md` if it exists. All agents must respect the project profile.
