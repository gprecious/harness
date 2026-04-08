---
name: harness-orchestrator
description: 피처 개발 하네스 오케스트레이터. /feature 명령으로 TDD 기반 Plan-Contract-Test-Build-Evaluate-Integrate-Learn 사이클을 실행. /feature --init, /feature --resume, /feature "설명" 을 요청할 때 사용.
version: 0.1.0
---

# Harness Orchestrator

피처 개발의 7-phase 파이프라인을 제어하는 오케스트레이터.

## Version Check

`/feature` 호출 시 최우선으로 plugin 버전과 project 버전을 비교한다.

1. plugin version: `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`의 `version` 필드
2. project version: `docs/harness/project-profile.md`의 `harness_version` 필드 (없으면 "0.1.0"으로 간주)
3. 비교 결과:
   - 일치: 작업 그대로 진행
   - 불일치 (plugin > project): 사용자에게 비차단 알림 표시
     - "harness가 v{plugin_version}으로 업데이트되었습니다 (현재 프로젝트: v{project_version}). 변경사항: ${CLAUDE_PLUGIN_ROOT}/CHANGELOG.md 참조. `/feature --init --refresh`로 프로젝트 프로파일을 갱신할 수 있습니다."
     - 작업은 그대로 진행 (블로킹 X)
4. project-profile.md 부재 시 (`--init` 미실행 상태): 버전 체크 스킵

## Modes

### INIT Mode (`/feature --init`)

프로젝트 프로파일링 및 하네스 초기화.

1. **프로젝트 탐색**: code-explorer agents(2-3개, 병렬)를 dispatch하여 기술 스택, 디자인 시스템, 코드 컨벤션, 테스트 패턴 감지
2. **Skill/Plugin 매핑**: 4개 소스 탐색
   - `~/.claude/skills/` (로컬 설치된 skills)
   - `~/.claude/plugins/installed_plugins.json` (로컬 설치된 plugins)
   - 공식 marketplace (`claude-plugins-official`)
   - skills.sh (오픈 생태계) → GitHub repo 접근하여 호환성 확인
3. **project-profile.md 생성**: 템플릿(`${CLAUDE_PLUGIN_ROOT}/templates/project-profile.md`) 기반으로 생성 → `docs/harness/project-profile.md`에 저장
4. **사용자 검토 checkpoint**: 프로파일 내용 확인 및 보완 요청
5. **디렉토리 스캐폴딩**: `docs/harness/`, `docs/wisdom/`, `docs/wisdom/index.md` 생성
6. **CLAUDE.md 업데이트**: `@docs/harness/project-profile.md`, `@docs/wisdom/index.md` 추가
7. **Preflight 실행**: Phase 0 의존성 체크

`--refresh` 옵션 시: 기존 project-profile.md를 읽고 변경사항만 업데이트.

### RESUME Mode (`/feature --resume`)

중단된 피처 런 재개.

1. `docs/harness/` 에서 가장 최근 미완료 `harness-state.md` 탐지
2. harness-state.md 읽기 → 현재 phase/task 파악
3. contract.md 읽기 → 기준 확인
4. 마지막 evaluation 읽기 → 피드백 확인
5. Resume Instructions에 따라 해당 phase부터 재개

### FEATURE Mode (`/feature "설명"`)

새 피처 개발 실행.

#### Phase 0: PREFLIGHT

의존성 체크. 다음 항목을 검증:

**Required Plugins:** feature-dev, code-review, pr-review-toolkit, security-guidance
**Required Skills:** superpowers:writing-plans, superpowers:test-driven-development, superpowers:subagent-driven-development, superpowers:verification-before-completion, superpowers:dispatching-parallel-agents, superpowers:finishing-a-development-branch, superpowers:requesting-code-review
**Project Type Dependencies:**
- web: Playwright MCP server
- mobile: Xcode CLI (`xcrun simctl`) / Android SDK
- content: Lighthouse CLI (optional)

검증 방법:
- Plugin: `~/.claude/plugins/installed_plugins.json`에서 확인
- Skill: `~/.claude/skills/{name}` 존재 확인
- Project tools: 해당 CLI 명령어 실행 가능 확인

누락 시: 목록 출력 + 설치 명령어 안내 → 사용자 승인 후 자동 설치 시도 → 재검증

#### Phase 1: PLAN

1. **brainstorming skill 호출** — 피처 요구사항 탐색, 접근 방식 제안, 설계 승인
   - 사용자와 대화하며 목적/제약/성공 기준 파악
   - 2-3가지 접근 방식 제안 → 사용자 선택
   - 설계 승인 후 다음 단계로
2. 피처 런 디렉토리 생성: `docs/harness/{YYYY-MM-DD}-{feature-slug}/`
3. harness-state.md 초기화 (템플릿 기반)
4. **병렬 탐색 (research-scout + code-explorer):**
   - **research-scout agent dispatch** — feature description + project-profile.md tech stack 기반으로 prior art 탐색
     - 4개 sub-scout (paper/video/docs/community) 병렬 실행
     - 결과를 `{run_dir}/research.md` 저장
     - 캐시: `docs/wisdom/research/{topic-slug}/research.md`
   - **code-explorer agents (2-3개) 병렬 dispatch** — 코드베이스 탐색
     - 결과를 `{run_dir}/exploration.md` 저장
   - 두 agent 그룹은 동시 실행 (병렬)
5. code-architect agent dispatch — exploration.md + research.md 모두 참조하여 `architecture.md` 작성
6. `project-profile.md` 참조하여 기존 패턴/컨벤션 맥락 제공
7. **UI 포함 피처일 때 — Design System Bootstrap:**
   - 참조 디자인(Figma/시안)이 있으면 → 건너뛰기 (CONTRACT에서 체크리스트 생성)
   - 참조 디자인이 없으면 → `references/design-system-bootstrap.md` 참조하여:
     a. **Design Brief** 작성 (Purpose, Tone, Constraints, Differentiator) — 사용자와 함께 결정
     b. `ui-ux-pro-max` skill로 **Design System 생성:**
        - 프로젝트 도메인/키워드로 검색 → 최적 style, palette, font pairing, effects 추천
        - 161 industry-specific palettes + 57 font pairings + 67 UI styles에서 자동 매칭
        - Anti-patterns + Pre-Delivery Checklist 포함
     c. `impeccable` `/colorize` → 색상 시스템 세부 조정
     d. `impeccable` `/typeset` → 타이포그래피 시스템 구축
     e. `frontend-design` skill → aesthetic direction 최종 결정
     f. design-tokens를 Tailwind @theme 또는 CSS variables로 코드화
     g. 결과를 `docs/harness/{run-dir}/design-brief.md`에 저장
   - **Anti-Slop Checklist 확인** (금지 폰트, 금지 레이아웃, 금지 color 패턴)
8. writing-plans skill 호출 → `plan.md` 저장
9. **✋ 사용자 승인 checkpoint**
10. harness-state.md 갱신 (PLAN → completed)

#### Phase 2: CONTRACT

1. contract-negotiator agent dispatch
   - plan.md와 project-profile.md를 읽고
   - 프로젝트 타입에 맞는 hard thresholds 제안 (floor: 디자인 4축 ≥7/10, test_coverage ≥80%)
   - 검증 시나리오 작성
   - 템플릿(`${CLAUDE_PLUGIN_ROOT}/templates/contract.md`) 기반으로 `contract.md` 생성
2. **✋ 사용자 검토 checkpoint** — contract.md의 핵심 내용을 사용자에게 제시:
   - Hard Thresholds 테이블 (각 기준의 최소 점수)
   - Verification Scenarios 목록
   - Sprint Scope (IN/OUT)
   - UI Component Checklist (있는 경우)
   - 사용자가 threshold 조정, 시나리오 추가/삭제, 범위 변경 가능
   - **승인 후** 다음 단계로 진행
3. harness-state.md 갱신 (CONTRACT → completed)
4. **── session boundary 권장 ──**

#### Phase 3: TEST FIRST (TDD Red)

1. **✋ 사용자 인터뷰 (orchestrator가 직접 수행)** — test-architect는 subagent이므로 사용자와 대화할 수 없다. orchestrator가 다음 질문을 사용자에게 직접 묻고 답변을 수집한다:
   - "이 기능을 실제로 어떻게 사용하시나요? 가장 흔한 사용 흐름은?"
   - "이 영역에서 이전에 발생했던 버그나 문제가 있나요?"
   - "코드에 드러나지 않는 비즈니스 규칙이 있나요?"
   - "외부 API, 결제, 이메일 등 실패할 수 있는 외부 연동이 있나요?"
   - "다른 권한/역할의 사용자가 이 기능을 사용하나요?"
   - "빈 상태, 첫 사용, 대량 데이터 등 특수한 데이터 상태가 있나요?"
   - "여러 사용자가 동시에 같은 데이터를 조작할 수 있나요?"
   - "모바일과 데스크톱에서 다르게 동작해야 하나요?"
   - 사용자 답변을 `{run_dir}/user-interview.md`에 기록
2. test-architect agent dispatch — **사용자 인터뷰 결과를 dispatch prompt에 포함**
   - contract.md + plan.md + **user-interview.md** 기반으로 테스트 시나리오 도출
   - project-profile.md의 테스트 컨벤션에 따라 테스트 코드 작성
   - `test-scenarios.md` 저장
3. 테스트 실행 → 전부 RED(failing) 확인
   - RED가 아닌 테스트가 있으면 수정 필요
4. **✋ 사용자 승인 checkpoint** (테스트 시나리오 검토)
5. harness-state.md 갱신 (TEST → completed)
6. **── session boundary 권장 ──**

#### Phase 4: BUILD + EVALUATE LOOP

iteration을 max_iterations(기본 5)까지 반복.
**Iteration 1은 전체 구현, Iteration 2+는 FAIL 피드백 기반 델타 수정.**

**BUILD 단계 — Iteration 1 (초기 구현):**
1. subagent-driven-development skill 호출
   - 각 태스크별 fresh implementer subagent
   - TDD skill 적용: 최소 코드로 GREEN
   - **UI 태스크 시:** implementer에게 다음 skill 사용 지시:
     - `impeccable` — `/arrange`(레이아웃), `/colorize`(색상), `/typeset`(타이포), `/animate`(모션), `/polish`(디테일)
     - `ui-ux-pro-max` — design-brief.md의 design system 참조
     - `frontend-design` — anti-slop 가이드라인 준수
   - spec-reviewer → 스펙 준수 검증
   - code-quality-reviewer → 코드 품질
2. security-guidance hook은 자동 활성

**BUILD 단계 — Iteration 2+ (델타 수정):**
1. 직전 `evaluations/iteration-{N-1}.md`의 Detailed Feedback 읽기
2. FAIL된 기준별 **구체적 수정 태스크** 도출:
   - 각 피드백 항목 → 수정 대상 파일 + 수정 내용 명확화
   - 전체 재빌드가 아닌 **targeted fix만** 수행
3. 수정 태스크별 fresh subagent dispatch:
   - 전달 내용: 실패 피드백 원문 + 수정 범위 + contract 기준
   - **디자인 미달 시** impeccable 명령어 활용:
     - Design Quality 미달 → `/arrange`, `/normalize`
     - Originality 미달 → `/bolder`, `/overdrive`, `/delight`
     - Craft 미달 → `/polish`, `/typeset`, `/colorize`
     - Functionality 미달 → `/clarify`, `/harden`, `/adapt`
   - spec-reviewer → 수정 결과 스펙 준수 확인
4. 수정 범위 밖의 기존 코드는 건드리지 않음

**EVALUATE 단계 (매 iteration 동일):**

아래 step 1~2는 **독립적으로 모두 실행**한다. step 1의 테스트 결과와 무관하게 step 2는 반드시 수행해야 한다.

1. 테스트 스위트 전체 실행 → 결과 기록
   - PASS/FAIL 결과와 상세 내역을 기록 (step 3에서 evaluation에 포함)
   - 테스트 자체 문제(환경/flaky) → test-healer agent dispatch
2. 프로젝트 유형별 검증 **(테스트 결과와 무관하게 항상 실행)**:
   - **웹:** `Agent` tool로 **design-evaluator agent를 dispatch**한다. design-evaluator가 Playwright로 스크린샷 촬영 + 4축 디자인 평가 + token compliance 검증을 수행. 결과 스크린샷은 `{run_dir}/screenshots/`에 저장.
   - **모바일:** 시뮬레이터/에뮬레이터 실행
   - **콘텐츠:** `Agent` tool로 **design-evaluator agent를 dispatch**한다. SEO 검증 + 4축 평가 수행.
   - **디자인 평가 보강:** design-evaluator가 `impeccable` `/critique`(UX 점수화 + 페르소나 테스트) + `/audit`(일관성 감사) 수행
3. step 1 + step 2 결과를 종합하여 contract.md 기준으로 채점 → 템플릿(`${CLAUDE_PLUGIN_ROOT}/templates/evaluation.md`) 기반으로 `evaluations/iteration-{N}.md` 저장
   - **반드시 템플릿 형식을 준수** — hooks가 `### Verdict:`, `Test Results`, `- failing_criteria:` 패턴을 파싱함
   - Score Evidence 섹션에 각 축의 가산/감산 근거 기록 (5/10 출발, 증거 기반)
   - 이전 iteration 대비 **개선된 항목 / 미개선 항목 / 새로 발생한 항목** 명시
4. 판정:
   - ALL PASS + **iteration 1인 경우** → design-evaluator의 "First-Pass Skepticism" 재검증 결과 확인. 재검증 통과 시에만 루프 탈출.
   - ALL PASS + iteration 2 이상 → 루프 탈출, Phase 5로
   - FAIL + 개선 여지 → 다음 iteration (델타 수정)
   - FAIL + plateau (3회 연속 동일 기준 미달 + 점수 변화 < 1) → **✋ 사용자 개입**
   - iteration >= max → **✋ 사용자에게 현황 보고**
5. harness-state.md 갱신 (FAIL verdict여도 반드시 갱신하여 iteration 진행 상태를 추적):
   - iteration 번호, iteration_type (full/delta)
   - scores, trend, delta_targets (수정 대상 기준 목록)
   - pending feedback (다음 iteration에서 처리할 항목)

**코드 리뷰:** code-review plugin으로 80+ confidence 리뷰 (최종 iteration 후).

#### Phase 5: INTEGRATE

1. finishing-a-development-branch skill 호출
   → merge / PR / keep / discard 옵션 제시
2. harness-state.md 갱신 (INTEGRATE → completed)

#### Phase 6: LEARN

1. wisdom-extractor agent dispatch
   - 이번 피처에서 배운 패턴, 아키텍처 결정, 평가 교훈 추출
   - `docs/wisdom/` 하위에 카테고리별 저장
   - `docs/wisdom/index.md` 자동 업데이트
   - 프로젝트 CLAUDE.md 갱신
2. `summary.md` 생성 (피처 완료 요약)
3. harness-state.md 갱신 (LEARN → completed, 전체 완료)

## harness-state.md 갱신 규칙

**매 phase 전환 시** 반드시 갱신. 다음 항목 업데이트:
- current_phase
- Phase Status 테이블
- Current Sprint State (BUILD_EVALUATE 중)
- Last Evaluation (EVALUATE 후)
- Key Decisions (발생 시)
- Pending Feedback (FAIL 시)
- Resume Instructions (항상 최신 유지)

## Session Boundary Protocol

**원칙: 사용자에게 묻지 말고 자동으로 처리하라.**

Context가 길어지면 품질이 급격히 저하된다 (Anthropic harness design 문서 참조).
사용자에게 "계속할까요?"라고 묻는 것은 불필요한 마찰이다.

### 자동 처리 규칙

**Phase 전환 시 (PLAN→CONTRACT→TEST→BUILD 등):**
1. harness-state.md 즉시 갱신 (Resume Instructions 포함)
2. 사용자에게 묻지 않고 자동으로 계속 진행
3. 단, 사용자 승인 checkpoint(✋)가 있는 phase는 승인 후 진행

**BUILD 태스크 진행 중:**
1. 각 태스크는 fresh subagent로 실행 — 이미 context 격리됨
2. orchestrator 자신의 context가 커지면 harness-state.md 갱신 후 자동 compact
3. compact 후에도 harness-state.md + contract.md + 마지막 evaluation만 읽으면 복원 가능

**EVALUATE iteration 완료 시:**
1. 평가 결과를 evaluations/iteration-{N}.md에 저장
2. harness-state.md 갱신 (scores, trend, pending feedback)
3. 다음 iteration 자동 시작 (PASS/plateau/max가 아닌 한)

### Context 관리 전략

**subagent 활용이 핵심:**
- 모든 실질적 작업은 subagent가 수행 (fresh context)
- orchestrator는 상태 관리와 흐름 제어만 담당
- orchestrator의 context가 커져도 subagent 품질에 영향 없음

**harness-state.md가 보험:**
- compact이 발생해도 harness-state.md를 읽으면 전체 상태 복원
- 세션이 끊어져도 `/feature --resume`로 정확히 이어서 진행
- 사용자 개입이 필요한 것은 plateau 감지나 max_iterations 도달 시뿐

## Implementer Status Protocol

모든 implementer subagent는 작업 완료 시 반드시 4가지 상태 중 하나로 종료해야 한다.
subagent dispatch 시 이 프로토콜을 prompt에 포함할 것.

```
DONE                — 구현 완료, 테스트 통과, 커밋함
DONE_WITH_CONCERNS  — 완료했지만 의문점 있음 (구체적 concern 명시)
NEEDS_CONTEXT       — 작업 전 질문 있음 (구체적 질문 명시)
BLOCKED             — 진행 불가 (차단 사유 + 필요한 선행 작업 명시)
```

**Orchestrator 분기:**
- `DONE` → spec-reviewer dispatch
- `DONE_WITH_CONCERNS` → concerns 검토 후 판단 (사소하면 진행, 심각하면 사용자에게 전달)
- `NEEDS_CONTEXT` → 사용자에게 질문 전달 → 답변 수신 → 동일 태스크 재dispatch (답변 포함)
- `BLOCKED` → 차단 사유 분석 → 의존 태스크 우선 처리 또는 사용자 개입 요청

## Feedback Guard (receiving-code-review 프로토콜)

evaluator/reviewer가 generator(implementer)에게 피드백을 전달할 때,
generator는 맹목적으로 수용하지 않는다.

**피드백 수신 시 프로토콜:**
1. **VERIFY** — 코드베이스에서 실제로 문제인지 확인
2. **EVALUATE** — 기술적으로 올바른 지적인지 판단
3. 맞으면 → 수정 (performative agreement 없이 바로 작업)
4. 틀리면 → push back ("이 부분은 {이유}로 현재 구현이 맞습니다")

**금지:**
- "You're absolutely right!", "Great point!" 같은 performative agreement
- 확인 없이 "Let me implement that now"
- evaluator 피드백을 무조건 수용하여 기존 정상 코드를 망치는 것

**적용 시점:** Phase 4 BUILD 델타 수정에서 evaluator 피드백을 implementer에게 전달할 때.

## Model Selection Guide

비용 최적화를 위해 태스크 성격에 따라 모델을 선택한다.
"좋은 scaffold의 Sonnet > 나쁜 scaffold의 Opus" (Confucius Code Agent 연구)

| 역할 | 모델 | 이유 |
|------|------|------|
| code-explorer | sonnet | 읽기/분석 전용, 빠르고 저렴 |
| code-architect | opus | 아키텍처 설계는 깊은 추론 필요 |
| contract-negotiator | opus | 평가 기준 설정은 판단력 필요 |
| test-architect | opus | 시나리오 도출은 깊은 추론 필요 |
| test-healer | sonnet | 진단은 패턴 매칭에 가까움 |
| implementer (subagent) | sonnet | 코드 생성은 scaffold가 보조 |
| spec-reviewer | sonnet | 체크리스트 기반 검증 |
| code-quality-reviewer | sonnet | 패턴 매칭 기반 리뷰 |
| design-evaluator | opus | 관대함 방지, 엄격한 판단 필요 |
| wisdom-extractor | sonnet | 읽기/분석 전용 |

agent frontmatter의 `model:` 필드가 이 가이드를 따라야 한다.

## Agent Teams 모드 (선택적)

`--parallel` 플래그로 활성화. 기본 비활성.

```
/feature "로그인 페이지" --parallel
```

활성화 시 BUILD 단계에서 독립 태스크를 병렬 teammates로 실행:
- Lead Agent(orchestrator) → 태스크를 독립/의존으로 분류
- 독립 태스크 → 병렬 teammates (3-5명)
- 의존 태스크 → 순차 실행
- 환경변수 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 필요

**주의:** experimental 기능. 안정성 문제 발생 시 `--parallel` 없이 재실행.

## Enforcement Architecture (Feedforward / Feedback)

하네스는 4가지 enforcement 레이어를 조합한다 (Martin Fowler 프레임워크).

|                        | Feedforward (사전 방지)                  | Feedback (사후 자기교정)                     |
|------------------------|----------------------------------------|-------------------------------------------|
| **Computational (결정적)** | `harness-lint.sh` — 매 Edit/Write 시 발화 | Structural tests — EVALUATE에서 실행          |
| **Inferential (LLM 기반)** | SKILL.md, agent .md, Skills            | design-evaluator (LLM-as-Judge)            |

### harness-lint.sh (Computational Feedforward)

hooks에서 호출되는 통합 린터. 모든 에러 메시지에 `Fix:` 행을 포함하여 agent가 자기 교정 가능.

**사용법:**
```bash
bash harness-lint.sh <run_dir> [contract|evaluation|state|test|screenshots|all]
```

**검증 항목:**
- `contract`: 필수 섹션, threshold floor (≥7/10, ≥80%)
- `evaluation`: Verdict/Test Results/Score Evidence/failing_criteria 형식
- `state`: 필수 필드, phase 유효성
- `test`: 시나리오 문서 + 실제 코드 파일 + E2E (web)
- `screenshots`: web/content 프로젝트 스크린샷 존재

**에러 메시지 패턴 (OpenAI 방식):**
```
[contract] functionality threshold가 5/10입니다 (floor: 7/10).
  Fix: contract.md에서 | functionality | 행의 점수를 7/10 이상으로 수정하세요.
```

### Structural Tests (Computational Feedback)

test-architect가 Phase 3에서 architecture.md 기반으로 작성. ArchUnit 스타일:
- 의존 방향 강제 (Types→Config→Repo→Service→Runtime→UI)
- 순환 의존 금지
- 모듈 경계 강제
- 기능 테스트와 함께 EVALUATE에서 실행
