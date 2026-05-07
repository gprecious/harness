# build-loop dispatch hook 분석

조사 일자: 2026-05-07
조사 대상: https://github.com/tyroneross/build-loop

## 발견 사항

- repo SHA: `e3c4e910da38d435179da45cd3b1f9d91a4851a9` (clone --depth 1, main HEAD at 2026-05-07)
- repo 구조 요약:
  - 듀얼 호스트(Claude Code + Codex) 플러그인. `.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` 동시 제공.
  - 핵심 사이클은 `agents/build-orchestrator.md` 의 **5-phase 루프 (Assess → Plan → Execute → Review → Iterate, +Learn)**.
  - 워커는 `agents/implementer.md` (Sonnet, parallel ≤4). 추가로 `architecture-scout`, `sonnet-critic`, `fact-checker`, `mock-scanner` 등 다수의 보조 에이전트가 있음.
  - Codex 호스트용 어댑터: `skills/build-loop/references/codex-subagents.md` + `skills/build-loop/templates/codex-worker-prompt.md`.
- dispatch hook 위치 (Claude 측):
  - 일차: `references/iterate-protocol.md:48` — `Top-level mode: dispatch up to 4 implementer subagents in parallel via Agent(subagent_type="build-loop:implementer", ...)` (Phase 5 Iterate 의 fan-out 규약)
  - 동일 패턴: `skills/build-loop/SKILL.md:527` (Phase 5 Iterate 의 SKILL.md 본문 측 서술 — `iterate-protocol.md` 와 동일한 top-level mode 문구), `references/phase-gate-checklist.md` (Review-D, architecture-scout 호출). Phase 3 Execute (`SKILL.md:320` 이하) 도 parallel subagent 를 쓰지만 별도 문구.
  - 즉, Claude 호스트에서는 **Claude Code 네이티브 `Agent()` 툴**로 호출. 외부 스크립트/wrapper/env-var 없음.
- dispatch hook 위치 (Codex 측):
  - `skills/build-loop/SKILL.md:328` — Phase 3 Execute 의 항목 5: "If running in Codex, load `references/codex-subagents.md` before any spawn decision. Spawn `explorer` or `worker` subagents only when the Codex permission gate passed."
  - `skills/build-loop/references/codex-subagents.md` — Codex 의 네이티브 `worker` / `explorer` 역할로 매핑되는 가이드. 코드가 아니라 **lead 세션에 대한 prompt 지침** 형태.
- 패턴: **B (워커 호출이 prompt에 직접 박혀있음)** — 다만 중요한 뉘앙스가 있음 (아래 결정 절 참조).
- 패턴 근거 (핵심 인용):

  `references/iterate-protocol.md:48` (Phase 5 Iterate 의 fan-out 규약, on-demand 로드되는 protocol 문서) 인용:
  ```
  Top-level mode: dispatch up to 4 implementer subagents in parallel via
  Agent(subagent_type="build-loop:implementer", ...). Hard cap from
  ~/.claude/CLAUDE.md §Sub-Agents. Sequential groups process after the parallel batch.
  ```
  → Claude 호스트에선 Claude Code 의 `Agent()` 툴 호출이 prompt 안에 하드코딩. config / env / hook 으로 교체할 수 있는 dispatcher 슬롯이 없다. Phase 3 Execute (별도, `SKILL.md:320` 이하) 도 parallel subagent 를 쓰지만 같은 결론.

  `skills/build-loop/SKILL.md:328` 인용:
  ```
  Codex execution adapter: If running in Codex, load references/codex-subagents.md
  before any spawn decision. Spawn explorer or worker subagents only when the Codex
  permission gate passed; otherwise execute locally.
  ```
  → Codex 호스트에선 "Codex 의 네이티브 subagent (worker / explorer)" 를 사용하라고 prompt 가 직접 지시. 다시 한 번, 외부 dispatcher 가 끼어들 슬롯 없음.

  `hooks/hooks.json` 의 hook 들은 SessionStart / PreToolUse / PostToolUse / Stop 의 architecture-scan, retrieval, deploy-gate, transcript-mining 용. **워커 호출 자체와 무관**. 즉 Claude Code 의 hook 시스템을 통해 dispatcher 를 가로챌 자리도 없다.

## 결정

- 경로: **B (fork 또는 우회 호출 필요)** — 단, 우리가 build-loop "내부" 를 fork 할 필요는 거의 없을 것으로 판단됨.
- 근거:
  1. build-loop 의 워커 호출은 **호스트 에이전트(Claude Code 또는 Codex) 의 네이티브 subagent 시스템** 위에서만 동작한다. 우리가 별도의 cmux pane 에 떠있는 codex 세션을 build-loop 의 워커로 직접 끼워 넣을 수 있는 공식 슬롯은 없다.
  2. 그러나 build-loop 자체를 수정할 필요는 없다. cmux-pipeline 에서 우리는 build-loop 을 **호출하는 쪽**이지 dispatcher 를 교체하는 쪽이 아니다. build-loop 은 stage 3 (Build) 의 한 변형으로 사용될 수 있는 "외부 도구" 인데, 그 통합 모델은 두 가지 중 하나여야 한다:
     - **(B-1)** build-loop 을 stage 의 **Claude pane 안에서** 그대로 실행한다 → build-loop 이 자기가 띄운 `Agent()` 워커로 작업하고, 그 결과를 우리가 stage 결과로 받는다. cmux 의 codex pane 은 이 시나리오와 무관 (build-loop 이 모르고, 알 필요도 없다).
     - **(B-2)** build-loop 을 우리 파이프라인의 **build stage 한 단계로 부르지 않고**, build-loop 의 _orchestration 모델만 차용_ 해서 우리만의 stage-loop 으로 그 패턴을 재구현한다. 이 경우 build-loop 은 참고 자료(레퍼런스) 일 뿐 install/실행되지 않는다.
  3. FSL-1.1-MIT 라이선스는 "Permitted Purpose" 안에서의 use/copy/modify/derivative work 를 허용하므로, fork 든 차용이든 license 적으로는 가능. 다만 **redistribute 시 license 사본/링크 첨부 + 저작권 표기 유지** 의무가 있다. 또한 "Competing Use" 금지가 적용되므로 build-loop 과 substantially similar 한 product/service 를 만드는 건 안 된다 — cmux-pipeline 은 build-loop 을 대체하는 것이 아니라, cmux 위에 codex pane 을 등장시키는 다른 카테고리의 도구이므로 충돌하지 않을 것으로 판단.

## 후속 phase 에 미치는 영향

### Task 21 (stage-loop.sh) 에 미치는 영향

원래 가설(Pattern A) 이었다면 stage-loop.sh 는 그저 환경변수 / config 한 줄로 build-loop dispatcher 를 우리 codex pane 으로 향하게 했을 것이다. 실제로는 그게 안 되므로 stage-loop.sh 의 의사결정이 달라진다:

1. **build-loop 의존도를 낮춘다.** stage-loop.sh 는 build-loop 의 Phase 3 dispatcher 를 hook 으로 가로채려 하지 말 것. 대신 stage-loop.sh 가 자체적으로 codex pane 에 메시지를 보내고 (`cmux-pane-chat` 패턴), 결과를 회수하는 루프를 돈다. 즉 stage-loop.sh 가 곧 우리의 "dispatcher" 가 된다.
2. **build-loop 은 옵션 stage 로만 활용.** 만약 사용자가 "이 build stage 는 build-loop 의 5-phase 사이클로 돌려줘" 라고 명시하면, stage-loop.sh 는 codex pane 안에서 build-loop 의 `/build-loop:run` 을 실행시키고 (`Codex execution adapter` 분기), build-loop 의 결과(Markdown 보고 + 코드 변경)를 stage 결과로 회수한다. 이때 build-loop 은 codex 자신의 worker/explorer subagent 시스템을 사용하므로 우리가 dispatcher 로 끼어들 필요가 없음.
3. **codex-launch + cmux pane 식별.** build-loop 가 우리 codex pane 을 "알 필요" 가 없다 — 우리가 codex pane 안에서 build-loop 을 실행시키는 흐름이므로 build-loop 입장에서는 "현재 호스트가 Codex" 이기만 하면 된다. cmux pane 식별은 **stage-loop.sh ↔ cmux-pane-chat ↔ codex pane** 사이에서만 의미가 있고, build-loop 자체로의 전달은 prompt 컨텐츠로 충분하다.

### Task 18 (codex worker prompt 작성) 에 미치는 영향

build-loop 은 자체 codex worker prompt 템플릿(`templates/codex-worker-prompt.md`) 을 이미 보유하고 있다. 우리 Task 18 은 이걸 출발점으로 삼되, 우리 stage-loop 의 입출력 contract (stage 입력 패킷, stage 결과 envelope) 에 맞게 rebrand 한다. 자세한 템플릿은 `build-loop-codex-prompt-template.md` 에 복사해 둠.

### 라이선스 이행 영향

- build-loop 을 우리 marketplace 에 **번들** 하지 않는다 (사용자가 직접 install). cmux-pipeline 은 build-loop 의 install 을 권장만 하고, 호출 contract 만 알고 있으면 됨.
- build-loop 의 prompt 템플릿(`codex-worker-prompt.md`) 을 우리 repo 에 복사해 둘 때는 출처 + FSL-1.1-MIT 표기를 함께 둔다 (해당 파일에 명시).

## License 메모

- build-loop 라이선스: **FSL-1.1-MIT** (Functional Source License v1.1, MIT Future License). Copyright 2026 Tyrone Ross.
- 핵심 조항:
  - **Permitted Purpose**: 내부 사용 / 비상업적 교육 / 비상업적 연구 / 라이선시에게 제공하는 전문 서비스. Competing Use (build-loop 을 대체하거나 substantially similar 한 상업적 product/service) 는 금지.
  - **Redistribution**: 복사본 / 수정본 / 파생물 재배포 시 라이선스 사본/링크 + 저작권 표기 유지 필수.
  - **Future License**: 일정 기간(정확히 2년 — FSL-1.1-MIT 정의상 고정) 후 MIT 로 전환되는 조건이 본문에 명시 (LICENSE 87줄 이하).
- 우리 cmux-pipeline 의 위치:
  - cmux-pipeline 자체는 build-loop 의 source 를 redistribute 하지 않는다. build-loop 은 사용자가 별도 install 하는 외부 plugin 으로만 다룬다.
  - 우리가 build-loop 의 **prompt 템플릿** 일부를 우리 repo 에 복사해 두는 경우 (`build-loop-codex-prompt-template.md`), 그 파일에 출처와 FSL-1.1-MIT 표기를 함께 둔다.
  - cmux-pipeline 은 build-loop 의 5-phase 오케스트레이션 모델을 일부 차용할 수 있으나, build-loop 자체와 substantially similar 한 product 가 되어선 안 된다 — cmux-pipeline 의 차별점은 "cmux 의 멀티 pane 위에서 codex 세션을 활용한다" 이며, 이는 build-loop 의 host-internal dispatch 모델과 카테고리가 다르다. Competing Use 위험 낮음.
