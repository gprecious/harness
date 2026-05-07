# codex CLI flag 검증

**codex 버전**: `codex-cli 0.128.0` (`@openai/codex@0.128.0`, native binary `codex-darwin-arm64`)
**검증 일자**: 2026-05-07
**검증 환경**: macOS Darwin 25.3, Node v24.12.0, zsh
**설치 경로**: nvm-managed Node 24, 패키지 `@openai/codex@0.128.0` (Node shim → 네이티브 Rust binary `@openai/codex-darwin-arm64`)

## --help 캡처 요약

### 서브커맨드 (top-level)

```
exec        Run Codex non-interactively  [aliases: e]
review      Run a code review non-interactively
login       Manage login
logout      Remove stored authentication credentials
mcp         Manage external MCP servers for Codex   ← list/get/add/remove/login/logout
plugin      Manage Codex plugins
mcp-server  Start Codex as an MCP server (stdio)
app-server  [experimental] Run the app server
app         Launch the Codex desktop app
sandbox     Run commands within a Codex-provided sandbox
apply       Apply latest agent diff as `git apply`
resume      Resume a previous interactive session
fork        Fork a previous interactive session
features    Inspect feature flags
help        Print help
```

서브커맨드 없이 `codex` 만 실행하면 **interactive TUI 모드** 진입 (디자인이 가정한 대화형 모드).

### 우리가 쓸 만한 top-level flag (interactive 모드 = 서브커맨드 없음)

| Flag | 인자 | 의미 |
|---|---|---|
| `-c, --config <key=value>` | TOML override | `~/.codex/config.toml` 의 임의 키를 CLI 에서 override (점 표기법 지원, repeatable) |
| `--enable <FEATURE>` | 이름 | `-c features.<name>=true` 동등 |
| `--disable <FEATURE>` | 이름 | `-c features.<name>=false` 동등 |
| `-m, --model <MODEL>` | 모델명 | 모델 선택 |
| `-p, --profile <PROFILE>` | 이름 | `config.toml` 프로필 선택 |
| `-s, --sandbox <MODE>` | `read-only` / `workspace-write` / `danger-full-access` | 모델이 실행하는 셸 명령의 샌드박스 정책 |
| `--dangerously-bypass-approvals-and-sandbox` | (없음) | 모든 prompt 건너뛰고 샌드박스 없이 실행. EXTREMELY DANGEROUS. |
| `-C, --cd <DIR>` | 경로 | agent 의 working root |
| `--add-dir <DIR>` | 경로 | 추가 쓰기 가능 디렉토리 |
| `-a, --ask-for-approval <POLICY>` | `untrusted` / `on-failure` / `on-request` / `never` | 명령 실행 전 사람 승인 정책 |
| `--search` | (없음) | 라이브 웹 검색 활성화 |
| `--no-alt-screen` | (없음) | TUI 를 alt-screen 안 쓰고 inline 으로. **cmux/zellij 등 멀티플렉서에서 스크롤백 보존에 중요** |
| `-i, --image <FILE>...` | 이미지 | 초기 프롬프트에 이미지 첨부 |
| `[PROMPT]` | 위치 인자 | 시작 프롬프트 |

`exec` 서브커맨드 추가 flag (interactive 와 다름):
- `--skip-git-repo-check`, `--ephemeral`, `--ignore-user-config`, `--ignore-rules`,
- `--output-schema <FILE>`, `--json`, `-o, --output-last-message <FILE>`
- (주의) `exec` 에는 `-a, --ask-for-approval` 가 **없음** — 비대화식이므로 항상 `never` 동등 동작

## 우리 design assumption 대비 매핑

설계 문서 (`docs/plans/2026-05-06-cmux-pipeline-design.md` §7.2 / line 297-301)가 가정한 라인:
```bash
codex \
  --model ${CODEX_MODEL:-gpt-5.5-codex} \
  --no-mcp \
  --auto-approve \
  --reasoning high
```

| 의도 | 우리 design | 실제 flag (또는 대안) | verified | 비고 / 위험 |
|---|---|---|---|---|
| 모델 지정 | `--model <name>` | **`-m, --model <MODEL>`** (긴 이름 그대로 존재) | YES | 가정 일치. `-m` 단축형도 가능. |
| MCP 비활성 | `--no-mcp` | **존재하지 않음.** 대안: `-c mcp_servers={}` (TOML 빈 테이블로 override) 또는 `--ignore-user-config` (`exec` 전용) | YES (부재 확인) | 디자인 수정 필요. interactive 모드에서는 `--ignore-user-config` 가 없으므로 `-c mcp_servers={}` 사용. **단**: `-c` 인자는 TOML 파싱 — 빈 테이블 표기 정확도 한 번 더 실측 검증 권장 (Task 13 구현 시). 차선책: `~/.codex/config.toml` 의 `[mcp_servers.*]` 섹션을 사용자 안내로 임시 비활성화. |
| 자동 승인 | `--auto-approve` | **존재하지 않음.** 가장 가까운 등가: `-a never` (= `--ask-for-approval never`). 더 강한 `--dangerously-bypass-approvals-and-sandbox` 도 있으나 위험. | YES (부재 확인) | 디자인 수정 필요. 권장 조합: **`-a never -s workspace-write`** (승인 안 묻고, 워크스페이스 내 쓰기 허용, 네트워크/시스템 쓰기는 샌드박스로 차단). 디자인 R5 ("의도치 않은 실행 위험") 와 정합 — sandbox 가 안전망. **`--dangerously-bypass-approvals-and-sandbox` 는 사용 금지** (cmux pane 은 외부 sandbox 가 아니므로 위험). |
| 추론 강도 | `--reasoning high` | **flag 형태 존재하지 않음.** 대안: `-c model_reasoning_effort="high"` (config 키 override). 가능 값 (실측): `none` / `minimal` / `low` / `medium` / `high` / `xhigh` — `codex exec -c 'model_reasoning_effort="bogus"'` 의 에러 메시지가 enum 전체를 노출하며, `xhigh` 는 `codex exec` 가 실제로 받아들이고 startup 배너에 `reasoning effort: xhigh` 로 표기됨을 확인. default 는 모델별로 `defaultReasoningEffort` 가 결정. | YES (실측됨) | 디자인 수정 필요. plan-mode 용으로는 `plan_mode_reasoning_effort` 키도 별도 존재. |
| 작업 디렉토리 | `--cd <path>` | **`-C, --cd <DIR>`** (긴 이름 그대로 존재, 단축은 `-C`) | YES | 가정 일치. |

추가 권장 flag (디자인이 명시 안 했지만 cmux 환경에서 필요):
- `--no-alt-screen` — cmux pane 은 zellij/tmux 와 비슷하게 멀티플렉서 환경. alt-screen 모드에서 스크롤백을 잃을 수 있음. **cmux pane 안에서는 켜는 것을 강력 권장**.

## /compact 동작 검증

### 결과: 지원됨 (interactive TUI). 비대화식 `codex exec` 에서는 **지원되지 않음 (literal text 로 처리)**.

### 검증한 방법과 근거

1. **공식 문서 (developers.openai.com/codex/cli/slash-commands)**
   - `/compact` 가 정식 슬래시 커맨드로 존재.
   - 동작: *"Codex replaces earlier turns with a concise summary, freeing context while keeping critical details."*
   - UX: *"Confirm when Codex offers to summarize the conversation so far."* — **사용자 confirmation 필요**.
2. **바이너리 정적 검증**
   - 네이티브 binary `strings` 결과에 `core/src/compact.rs`, `core/src/tasks/compact.rs`, `core/src/compact_remote.rs`, `codex-api/src/endpoint/compact.rs` 모두 컴파일됨 — 기능 실재.
   - JSON-RPC 메서드 `thread/compact/start`, `thread/compacted` 알림, `ContextCompactedNotification`, `ThreadCompactStartParams`/`Response`, `subAgentCompact` enum 변형 모두 존재.
   - config 키: `model_auto_compact_token_limit`, `compact_prompt`, `experimental_compact_prompt_file` — 자동 compact 임계치까지 제공.
   - subagent 변종 `subAgentCompact` 존재 — 대규모 history 일 때 compact 작업이 sub-agent 로 비동기 실행됨을 시사.
3. **`codex exec` 로 `/compact` literal 입력 테스트** (`echo "/compact" | codex exec --skip-git-repo-check --sandbox read-only`)
   - exec 는 `/compact` 를 **그냥 user prompt 로 받아 모델에게 전달**. 슬래시 커맨드 dispatch 가 일어나지 않음. exec 는 슬래시 커맨드 미지원.
   - 즉, `/compact` 는 interactive TUI (`codex` 단독 실행) 의 입력 dispatcher 가 가로채는 명령. **cmux pane 에 텍스트로 send 하면 동작**.
4. **`codex help compact` 시도 → 실패** (`error: unrecognized subcommand 'compact'`). 슬래시 커맨드는 CLI 서브커맨드가 아니라 TUI 입력이라는 점 재확인.

### 미확인 / 위험 항목 (verified=PARTIAL)

- **confirmation prompt 의 정확한 형태와 키 입력**. 문서는 "confirm" 만 명시. cmux pane 에 `/compact\n` 보낸 뒤 어떤 prompt 가 뜨고 어떤 키 (`y` / Enter / 화살표+Enter) 로 확정되는지는 실제 TTY 세션에서 확인 필요. 자동화 시 prompt 인식 로직이 필요할 수도.
- compact 진행 중 `thread/compacted` 알림이 onset 인지 완료인지 — binary strings 만으로는 단정 어려움. binary 에 `RawTraceEventPayload::CompactionInstalled` 라는 trace 이벤트 variant 가 컴파일되어 있으나, 이는 내부 trace 심볼이지 사용자에게 보이는 TUI 출력 문자열이라는 보장은 없음. **verified=NO — pane 출력에서 polling 할 실제 완료 신호 문자열은 `<TBD: actual completion string captured during Task 10 live TUI verification>` 로 두고, Task 10 라이브 TUI 검증에서 실제 문자열을 캡처해 확정해야 함**.

## design 영향

### 1. `codex-launch.sh` (Task 13) — 명령 라인 전면 수정 필요

기존 디자인:
```bash
codex --model gpt-5.5-codex --no-mcp --auto-approve --reasoning high
```
실제 사용 가능 형태:
```bash
codex \
  -m "${CODEX_MODEL:-gpt-5.5-codex}" \
  -C "${WORKDIR}" \
  -s workspace-write \
  -a never \
  --no-alt-screen \
  -c model_reasoning_effort="high" \
  -c mcp_servers={}
```
- `--no-mcp` → `-c mcp_servers={}` (또는 사용자 안내 + default config 사용)
- `--auto-approve` → `-a never` (sandbox 와 결합해야 안전; **`--dangerously-bypass-approvals-and-sandbox` 사용 금지**)
- `--reasoning high` → `-c model_reasoning_effort="high"`
- 추가: `-s workspace-write` (R5 위험 완화), `--no-alt-screen` (cmux 환경)
- 추가: `-C "${WORKDIR}"` 명시 (디자인엔 `--cd` 표기됐으나 long-form 동일)

### 2. `pane-compact.sh` (Task 10) — 시나리오 단순화

`/compact` 가 TUI 슬래시 커맨드로 존재함이 확인되었으므로 디자인의 핵심 가정은 살아있음. 그러나 자동화 관점에서:
- pane 에 `/compact\n` 텍스트를 입력 → **추가로 confirmation 키 입력 필요** (Enter 또는 y 추정). pane-compact.sh 는 두 단계로 입력해야 한다.
- compact 완료 신호: pane 출력에서 `<TBD: actual completion string captured during Task 10 live TUI verification>` 를 polling. 타임아웃 (15-30s) + fallback 필요. **verified=NO — Task 10 must capture from real TUI**: 현 시점에서는 binary strings 의 `RawTraceEventPayload::CompactionInstalled` 가 trace 이벤트 이름으로만 확인됐을 뿐, 사용자에게 표출되는 TUI 문자열이 무엇인지는 미확인. Task 10 라이브 TUI 검증에서 실제 완료 메시지를 캡처해 정규식으로 고정해야 함.
- **fallback (compact 실패 시)**: 디자인이 우려한 "fresh codex 인스턴스 per phase" 보다, `model_auto_compact_token_limit` config 로 codex 가 알아서 compact 하도록 하는 것이 가장 견고. 자동 compact 가 default 동작 — 우리는 **명시적 `/compact` 를 phase 경계에서 trigger 만 하면 됨**.

### 3. design 문서 §7.2 / line 297-301 의 코드 블록 수정 필요

design.md 의 codex 실행 라인을 위 권장 라인으로 교체. R8 (MCP 충돌) 도 `--no-mcp` 가 아니라 `-c mcp_servers={}` 로 표기 변경.

### 4. 새로 발견한 위험

- **`-c key=value` 의 TOML 파싱**: `-c mcp_servers={}` 이 zsh 에서 `{}` 글로빙 또는 toml 파싱과 충돌할 수 있음. quote 필수: `-c 'mcp_servers={}'`. Task 13 스크립트는 단일 인용으로 감싸야 함.
- **`-a never` + `-s workspace-write` 조합**: 워크스페이스 외부 (예: `~/.config`, 시스템 경로) 에 쓰기를 시도하면 sandbox 가 차단 → 모델이 escalation 못 시키므로 *작업이 실패*. cmux-pipeline phase 들이 워크스페이스 외부에 손대지 않게 contract 단계에서 제약 명시 필요.
- **interactive 모드 + `--add-dir`**: phase 간 공유하는 `docs/`, `harness/` 등 외부 디렉토리에 쓰기 필요 시 `--add-dir` 로 명시.

## 권장 codex 실행 라인 (확정)

TOML parse 확인됨 (`codex -c 'mcp_servers={}' --help` → exit 0). `codex exec -c 'model_reasoning_effort="xhigh"' ...` 도 정상 부팅되어 `reasoning effort: xhigh` 배너 표기됨.

```bash
codex -m "${CODEX_MODEL:-gpt-5.5-codex}" -C "${WORKDIR}" -s workspace-write -a never --no-alt-screen -c 'model_reasoning_effort="high"' -c 'mcp_servers={}'
```

옵션 분해 (가독용):
```bash
codex \
  -m "${CODEX_MODEL:-gpt-5.5-codex}" \
  -C "${WORKDIR}" \
  -s workspace-write \
  -a never \
  --no-alt-screen \
  -c 'model_reasoning_effort="high"' \
  -c 'mcp_servers={}'
```

phase 간 추가 쓰기 디렉토리가 필요하면 `--add-dir <PATH>` 를 반복 추가.

## 참고 링크

- 슬래시 커맨드 공식 문서: https://developers.openai.com/codex/cli/slash-commands
- CLI reference: https://developers.openai.com/codex/cli/reference
- 로컬 캡처본: `/tmp/codex-help.txt`, `/tmp/codex-exec-help.txt`
