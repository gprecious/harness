# Evaluation Criteria by Project Type

> 디자인 문서 Section 5.3 기반. design-evaluator 및 harness-orchestrator가 프로젝트 타입별 평가 기준으로 참조.

## Threshold Floor Rules

모든 프로젝트 타입에 공통 적용:
- 디자인 4축 (functionality, design_quality, originality, craft): **최소 threshold 7/10**
- test_coverage: **최소 threshold 80%**
- security: **PASS (예외 없음)**
- Floor 미만 설정은 사용자 명시적 승인 필요

## Web Application

| Criterion | Description | Verification |
|-----------|-------------|--------------|
| functionality | 사용성, 작업 완료 가능성 | Playwright E2E |
| design_quality | 일관된 전체, 독특한 분위기/정체성 | 스크린샷 평가 |
| originality | 커스텀 결정 흔적, AI slop 없음 | 스크린샷 + 코드 분석 |
| craft | 타이포그래피, 간격, 색상, 명암비 | 스크린샷 + axe-core |
| test_coverage | 행동적 커버리지 | pr-test-analyzer |
| security | OWASP top 10 | security-guidance hook |

### 세부 기준

- **functionality**: 모든 핵심 사용자 작업(user task)이 완료 가능해야 함. 폼 제출, 네비게이션, CRUD 동작이 정상 작동.
- **design_quality**: 색상 팔레트 일관성, 레이아웃 균형, 컴포넌트 스타일 통일성, project-profile.md 디자인 시스템 준수.
- **originality**: AI slop 패턴(흰색 카드+보라 그라데이션, 과도한 둥근 모서리+그림자) 배제. 프로젝트 고유의 디자인 결정 흔적 필요.
- **craft**: WCAG 4.5:1 명암비 필수, 8px grid 또는 프로젝트 spacing scale 준수, 명확한 타이포그래피 계층(h1>h2>h3>body).
- **test_coverage**: pr-test-analyzer로 측정한 행동적 커버리지. 라인 커버리지가 아닌 사용자 행동 기반.
- **security**: security-guidance plugin의 PreToolUse 경고 0건. OWASP top 10 취약점 없음.

## Mobile Application

| Criterion | Description | Verification |
|-----------|-------------|--------------|
| functionality | 네이티브 UX 패턴 준수, 작업 완료 | 시뮬레이터/에뮬레이터 |
| performance | 렌더링 성능, 메모리 | Instruments/Profiler |
| test_coverage | 유닛 + UI 테스트 | XCTest/Espresso |
| security | 데이터 저장, 네트워크 보안 | 코드 분석 |

### 세부 기준

- **functionality**: 플랫폼 네이티브 UX 패턴 준수 (iOS HIG / Material Design). 제스처, 네비게이션, 접근성 지원.
- **performance**: 60fps 렌더링, 메모리 릭 없음, 배터리 소모 최소화. Instruments(iOS) 또는 Android Profiler로 검증.
- **test_coverage**: XCTest(iOS) 또는 Espresso(Android)로 유닛 + UI 테스트. 핵심 사용자 흐름 커버.
- **security**: Keychain/Keystore 사용, 네트워크 통신 암호화, 민감 데이터 로깅 금지.

## Content / Marketing

| Criterion | Description | Verification |
|-----------|-------------|--------------|
| design_quality | 일관된 비주얼 아이덴티티 | 스크린샷 평가 |
| originality | 템플릿/AI slop 탈피 | 스크린샷 + 코드 |
| craft | 타이포그래피, 간격, 색상 조화 | 스크린샷 |
| seo | 메타태그, 구조화 데이터, 성능 | Lighthouse + audit |
| readability | 가독성 점수 | 텍스트 분석 |

### 세부 기준

- **design_quality**: 브랜드 아이덴티티와 일치하는 비주얼. 일관된 색상, 이미지 스타일, 레이아웃 패턴.
- **originality**: 템플릿 그대로 사용하지 않음. 브랜드 고유의 시각적 차별화. AI 생성 느낌의 제네릭한 디자인 배제.
- **craft**: 가독성 높은 타이포그래피, 적절한 행간/자간, 색상 대비, 이미지 최적화.
- **seo**: 메타 타이틀/디스크립션, Open Graph 태그, 구조화 데이터(JSON-LD), Core Web Vitals 통과.
- **readability**: 대상 독자에 맞는 난이도, 적절한 문단 길이, 명확한 헤딩 구조, 스캔 가능한 레이아웃.
