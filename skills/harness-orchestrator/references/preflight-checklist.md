# Preflight Checklist

> 디자인 문서 Section 3.2 기반. Phase 0에서 harness-orchestrator가 의존성을 검증할 때 참조.

## Required Plugins

하네스 실행에 필수적인 Claude Code 플러그인. 하나라도 누락 시 Phase 1 진입 불가.

| Plugin | 역할 | 설치 명령어 |
|--------|------|-------------|
| feature-dev | code-explorer, code-architect agents 제공 | `claude plugin install feature-dev@claude-plugins-official` |
| code-review | 80+ confidence 코드 리뷰 | `claude plugin install code-review@claude-plugins-official` |
| pr-review-toolkit | pr-test-analyzer, code-simplifier 제공 | `claude plugin install pr-review-toolkit@claude-plugins-official` |
| security-guidance | PreToolUse 보안 경고 (9가지 패턴) | `claude plugin install security-guidance@claude-plugins-official` |

### 검증 방법
```bash
# 설치된 플러그인 목록에서 확인
cat ~/.claude/plugins/installed_plugins.json | grep -E "feature-dev|code-review|pr-review-toolkit|security-guidance"
```

## Required Skills

하네스의 워크플로우를 지원하는 핵심 skill. superpowers 번들에 포함.

| Skill | 역할 | 설치 명령어 |
|-------|------|-------------|
| superpowers:writing-plans | Phase 1: 2-5분 단위 태스크 분해 | `claude skill install superpowers:writing-plans` |
| superpowers:test-driven-development | Phase 3, 4: Red-Green-Refactor 프로토콜 | `claude skill install superpowers:test-driven-development` |
| superpowers:subagent-driven-development | Phase 4: 태스크별 fresh subagent + 2단계 리뷰 | `claude skill install superpowers:subagent-driven-development` |
| superpowers:verification-before-completion | Phase 4: 증거 기반 완료 확인 | `claude skill install superpowers:verification-before-completion` |
| superpowers:dispatching-parallel-agents | Phase 1, 4: 독립 도메인 병렬 처리 | `claude skill install superpowers:dispatching-parallel-agents` |
| superpowers:finishing-a-development-branch | Phase 5: merge/PR/keep/discard | `claude skill install superpowers:finishing-a-development-branch` |
| superpowers:requesting-code-review | Phase 4: code-reviewer dispatch | `claude skill install superpowers:requesting-code-review` |

### 검증 방법
```bash
# 각 skill 디렉토리/심링크 존재 확인
ls ~/.claude/skills/superpowers:writing-plans
ls ~/.claude/skills/superpowers:test-driven-development
ls ~/.claude/skills/superpowers:subagent-driven-development
ls ~/.claude/skills/superpowers:verification-before-completion
ls ~/.claude/skills/superpowers:dispatching-parallel-agents
ls ~/.claude/skills/superpowers:finishing-a-development-branch
ls ~/.claude/skills/superpowers:requesting-code-review
```

## Project Type Dependencies

프로젝트 타입에 따른 추가 의존성. `--type` 플래그 또는 자동 감지 결과에 따라 검증.

### Web
| 의존성 | 용도 | 검증 명령어 |
|--------|------|-------------|
| Playwright MCP server | E2E 테스트 + 스크린샷 + 디자인 평가 | `mcp__plugin_playwright_playwright__browser_navigate` 도구 응답 확인 |
| Node.js runtime | 빌드 + 테스트 실행 | `node --version` |

### Mobile
| 의존성 | 용도 | 검증 명령어 |
|--------|------|-------------|
| Xcode CLI (iOS) | 시뮬레이터 실행 + 빌드 | `xcrun simctl list` |
| Android SDK (Android) | 에뮬레이터 실행 + 빌드 | `emulator -list-avds` |

### Content
| 의존성 | 용도 | 검증 명령어 |
|--------|------|-------------|
| Lighthouse CLI | SEO + 성능 평가 (선택) | `lighthouse --version` |

> Lighthouse는 선택 사항. 미설치 시 경고만 출력하고 계속 진행.
> 설치: `npm install -g lighthouse`

## Preflight 결과 처리

```
ALL OK → "✅ Preflight 완료. Phase 1로 진행합니다."
MISSING → 누락 목록 출력 (카테고리별 정리)
         → 각 항목에 설치 명령어 제공
         → "자동 설치를 시도할까요?" (사용자 승인 요청)
         → 승인 시: 순차 설치 실행 → 재검증
         → 여전히 실패 시: 중단 + 수동 설치 가이드
```
