# build-loop codex worker prompt template

본 파일은 build-loop 가 Codex 호스트의 worker 서브에이전트에게 전달하는 prompt 템플릿을 그대로 복사한 것이다. 우리 Task 18 (cmux-pipeline 의 codex worker prompt) 작성 시 출발점으로 사용한다.

## 출처 및 라이선스

- 원본 repo: <https://github.com/tyroneross/build-loop>
- 원본 위치: `tyroneross/build-loop` repo 의 `skills/build-loop/templates/codex-worker-prompt.md`
- 원본 SHA (clone 시점): `e3c4e910da38d435179da45cd3b1f9d91a4851a9`
- 라이선스: **FSL-1.1-MIT** — Copyright 2026 Tyrone Ross
- 라이선스 원문: <https://fsl.software/FSL-1.1-MIT.template.md>
- 본 파일을 cmux-pipeline 에서 추가 가공 / 재배포 할 경우, FSL-1.1-MIT 의 redistribution 조항(라이선스 사본/링크 + 저작권 표기 유지)을 따라야 한다. 위 라이선스 링크가 그 의무를 충족시키는 사본 링크 역할을 한다.

## 보조 자료 — Codex subagent 호출 규약

build-loop 가 Codex 의 `worker` 역할에게 prompt 를 전달할 때 동반하는 어댑터 가이드는 같은 repo 의 `skills/build-loop/references/codex-subagents.md` 에 있다. 핵심 골격은:

- `task` — 한 가지 구체적 outcome
- `owns` / `does_not_own` — 편집 가능한/불가능한 파일/디렉토리
- `context` — Phase 1·2 의 응축 사실
- `interface_contract` — 보존하거나 노출해야 할 함수/라우트/스키마/Props/CLI flag/문서
- `integration_checkpoint` — lead 가 머지 전에 검증할 항목
- `validation` — worker 가 가능하면 실행할 검증 명령
- `return_format` — changed files, summary, validation, unresolved risks, integration notes

또한 모든 worker prompt 에는 다음 문구가 포함된다:
> "You are not alone in the codebase. Do not revert edits made by others; adapt around them and report conflicts."

---

## 원본 템플릿 (그대로 복사)

# Codex Worker Prompt Template

You are a Codex worker inside a Build Loop run. You are not alone in the codebase. Do not revert edits made by others; adapt around them and report conflicts.

## Task

<one concrete outcome>

## Ownership

Owns:
- <exact files/directories this worker may edit>

Does not own:
- <files/directories/responsibilities this worker must not edit>

## Context

- Goal: <goal from .build-loop/goal.md>
- Intent: <north star/update intent relevant to this task>
- Current state: <short facts from assessment>
- Dependencies: <upstream tasks or known constraints>

## Interface Contract

- <function/route/schema/component/CLI/doc contract to preserve or expose>

## Implementation Rules

- Keep the change scoped to owned files.
- Prefer the repo's existing patterns over new abstractions.
- Do not add dependencies unless the lead explicitly assigned that.
- Surface pre-existing issues separately from task changes.
- If ownership is unclear, stop and report the conflict instead of broadening scope.

## Validation

Run if feasible:

```bash
<validation command>
```

If validation is not feasible, explain why and what the lead should run.

## Return Format

Changed files:
- <path>: <what changed>

Validation:
- <command or "not run">: <result or reason>

Integration notes:
- <contract, migration, or ordering notes>

Unresolved risks:
- <risk or "none known">

---

## cmux-pipeline 으로 가져갈 때 변경할 부분 (Task 18 메모)

1. "Build Loop run" 표현을 "cmux-pipeline stage" 로 교체.
2. Ownership 정의를 stage scope 로 매핑 (각 stage 입력 패킷의 `files_touched` 를 그대로 사용).
3. Validation 섹션은 cmux-pipeline 의 stage 별 검증 명령(`stage-loop.sh --verify <stage>`) 을 디폴트로 박는다.
4. Return format 은 cmux-pipeline 이 stage envelope 으로 파싱할 수 있는 JSON 으로 변환 (현재 build-loop 은 markdown 자유서식). Task 18 에서 envelope schema 를 확정.
5. "You are not alone in the codebase" 경고문은 그대로 유지 — cmux-pipeline 도 다중 pane 환경이라 의미 동일.
