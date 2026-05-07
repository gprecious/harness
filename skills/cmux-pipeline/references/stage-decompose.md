# Stage 2: Decompose (GSD)

## 목표
- GSD `/gsd-new-project` (greenfield) 또는 `/gsd-map-codebase` (brownfield) 진입
- design doc 을 PRD로 넘겨 `/gsd-plan-phase N --prd <design-doc>` 호출 (페이즈별 1회씩)
- 결과 페이즈 디렉토리를 `.pipeline/runs/<run-id>/decompose/phases/` 에 복사

## 절차 (claude orch)

1. manifest 갱신: `stages.decompose.status = "running"`
2. greenfield/brownfield 모드 결정:
   - `manifest.options.greenfield` 가 null 이면 자동 감지:
     - `git log --oneline | wc -l` 결과 ≤ 2 → greenfield 추정
     - 사용자에게 1회 confirm (`--no-confirm` 시 추정값 그대로 사용)
   - 결과를 `manifest.options.greenfield` 에 저장
3. **단순 작업 자동 감지** (옵션):
   - claude 가 topic 분석. 단일 파일·단일 함수·테스트 X·아키텍처 영향 X 라 판단되면
   - 사용자에게: "단순 작업으로 보입니다. spec/decompose 스킵하고 단일 페이즈로 진행할까요?"
   - 동의 시 `manifest.options.skip += "decompose"`, stage 종료
4. GSD 호출 (Skill tool):
   - greenfield: `gsd-new-project` (인터랙티브)
   - brownfield: `gsd-map-codebase` 먼저, 그 뒤
   - 모든 페이즈 별로 `gsd-plan-phase N --prd <design-doc-path>` (N = 1, 2, 3, …)
   - design-doc 은 stage-spec 에서 만든 `.pipeline/runs/<run-id>/spec/<primary_design>` 사용
5. 출력 정리:
   - `bash scripts/stage-decompose-finalize.sh <run-id>` (자동: `<repo>/.planning` 사용)
   - 또는 명시: `bash scripts/stage-decompose-finalize.sh <run-id> <planning-dir>`
6. manifest 갱신: `stages.decompose.status = "completed"`, `phase_count`, `phase_dirs`
7. checkpoint 가 `decompose` 포함 시: 안내 후 종료

## GSD 출력 레이아웃 (실측 기반)

`notes/external-skills-io.md` 참조. 실제 GSD 가 쓰는 경로:

| 명령 | 출력 파일 |
|---|---|
| `/gsd-new-project` | `.planning/{PROJECT,REQUIREMENTS,ROADMAP,STATE}.md`, `.planning/config.json`, `.planning/research/{STACK,FEATURES,ARCHITECTURE,PITFALLS,SUMMARY}.md` |
| `/gsd-map-codebase` | `.planning/codebase/{STACK,INTEGRATIONS,ARCHITECTURE,STRUCTURE,CONVENTIONS,TESTING,CONCERNS}.md` |
| `/gsd-plan-phase N` | `.planning/phases/{padded_phase}-{phase_slug}/{padded_phase}-{NN}-PLAN.md` (1+) <br> `.planning/phases/{padded_phase}-{phase_slug}/{padded_phase}-CONTEXT.md` <br> `.planning/phases/{padded_phase}-{phase_slug}/{padded_phase}-RESEARCH.md` <br> 옵션: `-VALIDATION.md`, `-PATTERNS.md`, `-SKELETON.md` |

`padded_phase` 자릿수(2자리 가정)와 `phase_slug` 의 정확한 sanitization 규칙은
`Task 32` manual verification 단계에서 최종 확인.

## stage-decompose-finalize.sh 동작 요약

- 인자: `<run-id> [<gsd-planning-dir>]` — 두 번째 인자 생략 시 `./.planning` 사용
- `<planning>/phases/*` 의 모든 디렉토리를 `.pipeline/runs/<run-id>/decompose/phases/` 로 복사
- `<planning>/{PROJECT,REQUIREMENTS,ROADMAP,STATE}.md` 가 있으면 `.pipeline/runs/<run-id>/decompose/` 로 복사 (참고 docs)
- manifest 갱신:
  - `stages.decompose.status = "completed"`
  - `stages.decompose.phase_count = <복사된 phase dir 수>`
  - `stages.decompose.phase_dirs = ["decompose/phases/<dir>", ...]`
- `<planning>/phases` 가 없거나 비어 있으면 non-zero 종료

## 다음 단계

decompose 완료 후 manifest.stages.decompose.phase_dirs 를 `stage-loop` 가 읽어
페이즈별 PLAN.md 들을 codex 에 dispatch 한다 (Task 18 이후).
