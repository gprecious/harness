# Test Design Principles Reference

> Kent Beck, Martin Fowler, Kent C. Dodds, Google Testing Blog 연구 기반

## Kent Beck — 12 Test Desiderata

| # | Property | Definition |
|---|----------|-----------|
| 1 | Isolated | 실행 순서와 무관하게 동일한 결과 |
| 2 | Composable | 다른 차원의 변동성을 분리하여 테스트하고 결합 가능 |
| 3 | Deterministic | 변경 없으면 결과도 변경 없음 |
| 4 | Fast | 빠르게 실행 |
| 5 | Writable | 작성 비용이 테스트 대상 코드 대비 저렴 |
| 6 | Readable | 테스트 동기를 이해할 수 있는 가독성 |
| 7 | Behavioral | 테스트 대상의 행동 변경에 민감 |
| 8 | Structure-insensitive | 코드 구조 변경에 둔감 |
| 9 | Automated | 인간 개입 없이 실행 |
| 10 | Specific | 실패 시 원인이 명백 |
| 11 | Predictive | 전체 통과 시 프로덕션 배포 가능 |
| 12 | Inspiring | 통과 시 자신감 부여 |

"더 큰 가치의 속성을 얻지 못하면서 어떤 속성도 포기하지 마라."

## Canon TDD (2023)

1. 예상되는 모든 행동 변형을 test list로 작성
2. 정확히 하나의 항목을 구체적이고 실행 가능한 테스트로 변환
3. 테스트(및 이전 모든 테스트)가 통과하도록 코드 변경
4. 선택적으로 리팩토링
5. 리스트가 빌 때까지 반복

"테스트 순서가 프로그래밍 경험과 최종 결과에 유의미한 영향을 미친다."

## AI 테스트 생성 실패 패턴 (실증 연구)

| Pattern | Description | Detection |
|---------|-------------|-----------|
| Tautological | 구현 출력을 기대값으로 복사 | Mutation testing |
| Over-mocked | 테스트 대상까지 mock (agent 36% vs human 26%) | Mock-to-assertion ratio |
| No/Weak assertion | assertNotNull, assertTrue(true) | Mutation testing |
| Logic duplication | assertion에 구현 로직 복제 | Code review |
| Happy path only | edge/error 시나리오 누락 | Boundary analysis |
| Implementation-coupled | 리팩토링 시 깨짐 | Refactoring exercise |
| Surface-pattern | 의미 보존 리팩토링 후 18.1% 일치율 | Semantic refactoring |
| Interaction over state | "호출되었는가" vs "결과가 맞는가" | State-based review |

핵심 수치:
- 93% line coverage / 58% mutation score (34%p gap)
- AI 테스트의 평균 40% mutation 감지율
- 의미 보존 변경 후 pass rate 78.9%로 하락 (21.1%p)

## Sources

- Kent Beck, "Test-Driven Development: By Example" (2002)
- Kent Beck, "Canon TDD" (2023) — tidyfirst.substack.com
- Kent Beck, "Test Desiderata" — testdesiderata.com
- Kent Beck, "Programmer Test Principles" — Medium
- Kent Beck, "TDD's Missing Skill: Behavioral Composition" (2024)
- Kent Beck, "Augmented Coding: Beyond the Vibes" (2025)
- Martin Fowler, "Mocks Aren't Stubs" — martinfowler.com
- Kent C. Dodds, "Testing Implementation Details" — kentcdodds.com
- Google, "Software Engineering at Google" Ch.12 — abseil.io
- Schafer et al., IEEE TSE 2024 — LLM test generation evaluation
- Hora, MSR 2026 — Over-mocked tests by coding agents
- "93% Coverage, 58% Mutation Score" — dev.to/jghiringhelli
