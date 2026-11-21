# Changelog

이 프로젝트의 모든 주요 변경사항을 기록합니다.
[Semantic Versioning](https://semver.org/) 규칙을 따릅니다.

## [Unreleased]

## [3.5.0] - 2026-11-21

### Added
- 터미널 폭 맞춤 — Claude Code가 넘겨주는 `COLUMNS`(v2.1.153+)에 맞춰, 줄이 `COLUMNS - 2`열보다 넓으면
  설정·식별 정보(📌 세션명, ⚡ Effort, 🌲 worktree, 🔀 PR, 리셋 시각, 💭 thinking, 📁 저장소 등)부터
  줄마다 정해진 순서로 숨기고, 그래도 넘치면 줄 끝을 `…`로 자름. `COLUMNS`가 없으면 이전과 같은 출력
- ♻️ 프롬프트 캐시 (Line 4, `prompt_cache`, v2.1.251+) — `warm 42m`(만료까지 남은 시간) 또는 `cold`,
  적중률(`hit_ratio`), 미스 횟수(`misses`, 0이면 숨김). `prompt_cache`가 없거나 `null`이거나
  `caching_observed`가 `false`면 숨김

### Fixed
- `release.sh`가 SSH 호스트 별칭을 쓰는 origin(`git@<별칭>:owner/repo`)을 https 주소로 바꾸지 못해
  CHANGELOG 비교 링크에 SSH 주소가 들어가던 문제 — 모든 `git@<host>:` 형식을 `https://github.com/`으로
  바꾸고, https origin에 들어 있는 사용자명·토큰은 링크에서 제거

## [3.4.2] - 2026-11-21

### Added
- Line 4 — 세션 세부 줄. 표시할 값이 없으면 줄 전체가 숨겨지고, Rate Limit 줄이 없으면 3번째 줄에 표시됨
  - 📁 저장소 `owner/repo` (`workspace.repo`)
  - ⏳ 세션 경과 시간 (`cost.total_duration_ms`, `45s` / `12m` / `1h23m`)
  - 📥 컨텍스트 세부 — 캐시 읽기와 새 입력을 구분 (`context_window.current_usage`,
    `cache` = `cache_read_input_tokens`, `new` = `input_tokens` + `cache_creation_input_tokens`)
  - 💭 Extended thinking 켜짐 표시 (`thinking.enabled`)
- 🌲 worktree 표시 — 링크된 git worktree(`workspace.git_worktree`) 또는 `--worktree` 세션(`worktree.name`)일 때
  브랜치 옆에 표시
- 새 세그먼트는 모두 필드가 없거나 `null`이면 숨겨지고, 문자열은 기존과 같이 제어문자를 제거함

### Removed
- Line 1의 🧠 컨텍스트 사용률 세그먼트 — Line 2 📦 괄호 안 %와 같은 값(`context_window.used_percentage`)을
  두 번 표시하던 중복. %·색상·토큰 수는 📦에 그대로 남고, Line 1 폭이 9열가량 줄어 세션명과 Fast mode가
  함께 있을 때 80열을 넘던 문제도 해소

## [3.4.1] - 2026-11-21

### Fixed
- **v3.4.0 구현이 릴리스에서 빠져 있던 문제** — v3.4.0 태그 커밋에는 `CHANGELOG.md`와
  `plugin.json`만 들어 있었고, 3줄 레이아웃·세션명·PR·7d·Fast mode·세션별 캐시 등 실제 구현은
  그 뒤 커밋(74e4746)에 들어갔음. 3.4.1이 이 구현을 포함하는 첫 릴리스
- lite 버전이 세션 초반(`context_window.used_percentage`가 `null`)에 모델명·브랜치·세션 ID까지
  대체값으로 표시하던 문제 — 필드마다 null을 따로 처리
- 📦 토큰 수와 백분율의 기준이 달랐던 문제 — 이제 `used_percentage`와 같은 입력 토큰 기준
  (`total_input_tokens` = 입력 + 캐시 쓰기 + 캐시 읽기)으로 표시. **출력 토큰이 빠지므로 수치가
  이전보다 작게 보일 수 있음**
- 세션명·PR URL 등 외부 문자열에 든 터미널 제어문자(ESC, BEL 등)를 제거 — 터미널 제목 변경이나
  링크 변조 방지
- `/claude-lynceus:install`과 `setup-statusline` 스킬이 `~/.claude/claude-lynceusline.sh`에
  설치해 `uninstall.sh`로 지워지지 않던 문제 — 경로를 `lynceus-statusline.sh`로 통일하고,
  설치·제거 스크립트의 옛 파일 정리 대상에 `claude-lynceusline.sh` 추가
- README의 최소 버전 표기(Rate Limit v2.1.80+, Effort v2.1.119+), ultracode 설명, 미리보기 모델명

### Added
- GitLab merge request는 `!번호`로 표시 (`pr.kind: "mr"`, Claude Code v2.1.234+)
- 24시간 동안 갱신되지 않은 세션별 캐시 파일(`/tmp/lynceus-cache-*`) 자동 정리

### Changed
- jq 버전이 stdin JSON을 jq 한 번으로 파싱 (기존 20회 호출)
- `/claude-lynceus:install`, `/claude-lynceus:uninstall`을 `commands/`에서 `skills/`로 이관
  (호출 이름은 그대로)
- 스킬 설치 안내의 statusLine 설정에 `refreshInterval: 10` 추가 (`install.sh`와 동일)

### Removed
- ⚡ Effort의 `$CLAUDE_EFFORT` 환경변수 대체값 — statusline 입력 JSON의 `effort.level`만 사용.
  effort를 지원하지 않는 모델에서는 세그먼트가 숨겨짐 (README 설명과 일치)

## [3.4.0] - 2026-08-12

### Added
- 📅 7일 Rate Limit 표시 (`rate_limits.seven_day.used_percentage`, `resets_at`)
- 📌 세션명 표시 (`session_name` — `--name` / `/rename` 또는 AI 생성 제목, 없으면 숨김)
- 🔀 현재 브랜치의 열린 PR 표시 (`pr.number`, `pr.url`, `pr.review_state`)
  - OSC 8 하이퍼링크로 PR 번호 클릭 가능 (iTerm2, Kitty, WezTerm 등)
  - 리뷰 상태 아이콘: approved(✓), changes_requested(✗), pending(⋯), draft(○)
- 🚀 Fast mode 배지 (`fast_mode`)
- `refreshInterval: 10` 설정 — 세션 유휴 중에도 Rate Limit / PR 세그먼트 갱신
- 설치 시 이전 버전 스크립트(`session-statusline.sh`) 자동 정리

### Changed
- 2줄 → 3줄 레이아웃. Line 3은 Rate Limit 전용이며, 데이터가 없으면 줄 전체가 숨겨져 기존 2줄로 표시됨
- `statusline-lite.sh`가 `statusline.sh`와 완전한 기능 패리티 확보

### Fixed
- **캐시 파일이 모든 세션에서 공유되던 문제** — `/tmp/lynceus-cache` 고정 경로를
  `/tmp/lynceus-cache-{session_id}`로 변경. 여러 프로젝트를 동시에 열었을 때 다른
  프로젝트의 브랜치명이 표시되던 증상 해결
- lite 버전에 5시간 Rate Limit 리셋 시각이 표시되지 않던 문제 (jq 버전과 불일치)
- `uninstall.sh`가 이전 버전 파일명(`session-statusline.sh`)을 삭제하지 못하던 문제
- lite 버전의 `eval` 셸 인젝션 가능성 — `session_name` 등 자유 문자열 필드를
  `shlex.quote()`로 이스케이프
- 공식 스키마에 없는 `rate_limits.five_hour.utilization` 참조 제거 (정식 필드는 `used_percentage`)
- `install.sh` / `uninstall.sh`의 완료 메시지에 ANSI 이스케이프가 그대로 출력되던 문제
  (`\033[1m설치가 완료되었습니다!\033[0m`) — 헬퍼 함수의 `printf` 포맷을 `%s` → `%b`로 변경.
  `printf`는 포맷 문자열의 이스케이프만 해석하므로 인자로 넘긴 색상 코드는 처리되지 않았음

## [3.3.0] - 2026-05-20

### Added
- ⚡ Effort 레벨 표시 (`effort.level` JSON 필드, `$CLAUDE_EFFORT` 환경변수)
- 레벨별 색상 분류: low(그레이), medium(세이지 그린), high(옐로), xhigh(마젠타), max(레드)
- Effort 미설정 시 자동 숨김 (v2.1.131 미만 하위 호환)

## [3.2.1] - 2026-04-02

### Fixed
- macOS BSD sed에서 쉼표 포맷팅이 동작하지 않던 문제 수정 (`rev | sed | rev` 방식으로 변경)
- `96737 / 200000` → `96,737 / 200,000` 정상 출력 확인

## [3.2.0] - 2026-04-02

### Changed
- 초록색을 세이지 그린(256-color #108)으로 변경하여 시인성 개선

## [3.1.0] - 2026-04-02

### Added
- 하이브리드 닉네임: `CLAUDE_USER_NICK` 환경변수 → `git config user.name` → `whoami` 우선순위
- 설치 스크립트에 닉네임 입력 단계 추가

## [3.0.0] - 2026-04-02

### Added
- 2줄 레이아웃 (Dan Does Code 스타일)
- Line 1: 모델명, 컨텍스트 사용률, 세션 비용, 5시간 Rate Limit (프로그레스 바 + 리셋 시각)
- Line 2: 코드 추가/삭제 줄 수
- 색상 변동 기준: 50% 미만(초록), 50~79%(노랑), 80% 이상(빨강)
- 데이터 없을 때 자동 숨김 (Rate Limit, 코드 변경량)

### Changed
- 1줄 레이아웃 → 2줄 레이아웃으로 전면 변경

## [2.0.0] - 2026-04-02

### Added
- 스테이터스라인(항상 표시) 방식으로 전환
- `scripts/statusline.sh` (jq 기반)
- `scripts/statusline-lite.sh` (Python 기반, jq 없이 동작)
- `scripts/install.sh` 자동 설치 스크립트
- `scripts/uninstall.sh` 자동 제거 스크립트
- `/claude-lynceus:install`, `/claude-lynceus:uninstall` 슬래시 명령어

### Changed
- 슬래시 명령어 방식 → 스테이터스라인 방식으로 변경

## [1.0.0] - 2026-04-02

### Added
- 최초 릴리즈
- 사용자 이름, git 브랜치, 컨텍스트 사용량 표시
- `/session-status:status` 슬래시 명령어
- `skills/session-status/SKILL.md` 스킬 정의

[Unreleased]: https://github.com/clauzewitz/claude-lynceus/compare/v3.5.0...HEAD
[3.5.0]: https://github.com/clauzewitz/claude-lynceus/compare/v3.4.2...v3.5.0
[3.4.2]: https://github.com/clauzewitz/claude-lynceus/compare/v3.4.1...v3.4.2
[3.4.1]: https://github.com/clauzewitz/claude-lynceus/compare/v3.4.0...v3.4.1
[3.4.0]: https://github.com/clauzewitz/claude-lynceus/compare/v3.3.0...v3.4.0
[3.3.0]: https://github.com/clauzewitz/claude-lynceus/compare/v3.2.1...v3.3.0
[3.2.1]: https://github.com/clauzewitz/claude-lynceus/compare/v3.2.0...v3.2.1
[3.2.0]: https://github.com/clauzewitz/claude-lynceus/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/clauzewitz/claude-lynceus/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/clauzewitz/claude-lynceus/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/clauzewitz/claude-lynceus/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/clauzewitz/claude-lynceus/releases/tag/v1.0.0
