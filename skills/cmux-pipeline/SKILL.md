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
