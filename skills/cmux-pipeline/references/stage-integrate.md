# Stage 4: Integrate

## 목표
- 모든 페이즈 commit이 feature branch에 누적된 상태에서 전체 검증
- `superpowers:verification-before-completion` Skill 호출
- 통과 시 PR 생성 안내, 실패 시 paused

## 절차 (claude orch)

1. manifest 갱신: `stages.integrate.status = "running"`
2. claude orch 가 `superpowers:verification-before-completion` Skill 호출:
   - 전체 테스트 / 타입체크 / lint 실행
   - 결과 분석
3. 통과:
   - `bash scripts/stage-integrate.sh complete <run-id>`
   - manifest: `stages.integrate.status = "completed"`, `status = "completed"`
   - 사용자에게 안내: "[/build] DONE in <duration>. PR 생성: gh pr create --base main --head feat/<topic>"
4. 실패:
   - `bash scripts/stage-integrate.sh fail <run-id> "<짧은 사유>"`
   - manifest: paused, 실패 원인 기록
   - 사용자에게 수동 개입 요청
