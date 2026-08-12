# Changelog

이 프로젝트의 모든 주요 변경사항을 기록합니다.
[Semantic Versioning](https://semver.org/) 규칙을 따릅니다.

## [Unreleased]

## [3.4.0] - 2026-08-12

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

[Unreleased]: git@github-personal.com:clauzewitz/claude-lynceus/compare/v3.4.0...HEAD
[3.4.0]: git@github-personal.com:clauzewitz/claude-lynceus/compare/v3.4.0...v3.4.0
[3.4.0]: https://github.com/YOUR_USERNAME/claude-lynceus/compare/v3.3.0...v3.4.0
[3.3.0]: https://github.com/YOUR_USERNAME/claude-lynceus/compare/v3.2.1...v3.3.0
[3.2.1]: https://github.com/YOUR_USERNAME/claude-lynceus/compare/v3.2.0...v3.2.1
[3.2.0]: https://github.com/YOUR_USERNAME/claude-lynceus/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/YOUR_USERNAME/claude-lynceus/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/YOUR_USERNAME/claude-lynceus/compare/v2.0.0...v3.0.0
[2.0.0]: https://github.com/YOUR_USERNAME/claude-lynceus/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/YOUR_USERNAME/claude-lynceus/releases/tag/v1.0.0
