---
description: cmux + codex 기반 자율 빌드 파이프라인 (GStack → GSD → loop → integrate)
---

cmux-pipeline skill을 호출해 사용자 입력을 처리한다.

입력 파싱:
- 첫 인자: topic (또는 `--resume <run-id>`, `--status`, `--list`, `--gc`)
- 옵션: `--checkpoint=`, `--skip=`, `--greenfield`, `--brownfield`, `--phase-timeout=`, `--compact-every=`, `--no-confirm`, `--dry-run`, `--verbose`, `--model=`

위임: cmux-pipeline skill에 사용자의 원본 입력을 그대로 전달.
