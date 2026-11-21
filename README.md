# 📊 Claude Lynceus v3.5

Claude Code 터미널 하단에 **항상 표시되는 상태 바(최대 4줄)**를 추가하는 플러그인입니다.

## 미리보기

넓은 터미널(`COLUMNS` 120)에서의 출력입니다. 좁은 터미널에서는 [터미널 폭 맞춤](#터미널-폭-맞춤)을 참고하세요.

```
👤 주인 · 📌 statusline-v34 | 🤖 Opus 5.5 🚀 | ⚡ high | 🎭 security-reviewer | 💰 $13.86
🌿 feature/DPDD-2206 🌲 feature-xyz +1932 -73 | 🔀 #1234 ✓ | 📦 128,000 / 200,000 (64%)
⏱️ 5h ████░░░░░░ 45% reset 16:06 | 7d ████░░░░░░ 41% reset 8/14 09:00
📁 clauzewitz/claude-lynceus | ⏳ 1h23m | 📥 cache 112k · new 16k | ♻️ warm 42m · hit 91% | 💭 thinking
```

---

## 표시 속성

### Line 1 — 세션 메타데이터

| 아이콘 | 속성 | 데이터 소스 | 비고 |
|--------|------|-------------|------|
| 👤 | 사용자 이름 | `CLAUDE_USER_NICK` → `git config user.name` → `whoami` | 하이브리드 우선순위 |
| 📌 | 세션명 | `session_name` | `--name` / `/rename` 또는 AI 생성 제목, 없으면 숨김 |
| 🤖 | 모델명 | `model.display_name` | |
| 🚀 | Fast mode | `fast_mode` | 켜져 있을 때만 표시 |
| ⚡ | Effort 레벨 | `effort.level` | v2.1.119+, 색상 변동, 없으면 숨김 |
| 🎭 | Agent | `agent.name` | `--agent` 플래그나 agent 설정으로 실행했을 때만 표시 |
| 💰 | 세션 비용 | `cost.total_cost_usd` | USD 표시 |

### Line 2 — git 컨텍스트

| 아이콘 | 속성 | 데이터 소스 | 비고 |
|--------|------|-------------|------|
| 🌿 | git 브랜치 | `git branch --show-current` | 미연결 시 — 표시 |
| 🌲 | worktree | `workspace.git_worktree` → `worktree.name` | 링크된 git worktree(v2.1.97+) 또는 `--worktree` 세션(v2.1.69+)일 때만 표시. worktree 이름이 브랜치명과 다르면 🌲 뒤에 회색으로 함께 표시 |
| +/- | 코드 변경량 | `cost.total_lines_added/removed` | 0이면 자동 숨김 |
| 🔀 | 열린 PR | `pr.number`, `pr.url`, `pr.review_state`, `pr.kind` | OSC 8 클릭 링크, GitLab MR은 `!번호`, 없으면 숨김 |
| 📦 | 토큰 사용량 | `total_input_tokens` | 쉼표 포맷. `used_percentage`와 같은 입력 토큰 기준 (출력 토큰 제외) |
| | 전체 토큰 / 백분율 | `context_window_size`, `used_percentage` | 색상 변동 |

### Line 3 — Rate Limit

| 항목 | 데이터 소스 | 비고 |
|------|-------------|------|
| 5h | `rate_limits.five_hour.used_percentage`, `resets_at` | 프로그레스 바 + 리셋 시각 |
| 7d | `rate_limits.seven_day.used_percentage`, `resets_at` | 프로그레스 바 + 리셋 날짜·시각 |

두 값 모두 없으면 **줄 전체가 숨겨집니다**.

### Line 4 — 세션 세부

| 아이콘 | 속성 | 데이터 소스 | 비고 |
|--------|------|-------------|------|
| 📁 | 저장소 | `workspace.repo.owner`, `workspace.repo.name` | `origin` 리모트 기준 `owner/repo`, 없으면 숨김 |
| ⏳ | 세션 경과 시간 | `cost.total_duration_ms` | `45s` / `12m` / `1h23m`. resume을 넘어 누적되며 세션이 실행 중이지 않은 시간은 제외 |
| 📥 | 컨텍스트 세부 | `context_window.current_usage` | `cache` = 캐시 읽기(`cache_read_input_tokens`), `new` = 새 입력(`input_tokens` + `cache_creation_input_tokens`). `8.5k` / `82k` / `1.2M` 형식(버림). v2.0.70+ |
| ♻️ | 프롬프트 캐시 | `prompt_cache.warm`, `expires_at`, `hit_ratio`, `misses`, `caching_observed` | `warm 42m`(만료까지 남은 시간) 또는 `cold`, `hit` = 캐시 적중률(반올림), `miss` = 캐시 미스 횟수(0이면 숨김). v2.1.251+ |
| 💭 | Extended thinking | `thinking.enabled` | 켜져 있을 때만 표시. v2.1.119+ |

표시할 값이 하나도 없으면 **줄 전체가 숨겨집니다**. Line 3(Rate Limit)이 없으면 이 줄이 3번째 줄에 표시됩니다.

### 🔀 PR 리뷰 상태 아이콘

| 상태 | 아이콘 | 색상 |
|------|--------|------|
| `approved` | ✓ | 세이지 그린 |
| `changes_requested` | ✗ | 레드 |
| `pending` | ⋯ | 옐로 |
| `draft` | ○ | 그레이 |

### 색상 변동 기준

⏱️ Rate Limit, 📦 토큰 사용량에 공통 적용됩니다.

| 구간 | 색상 | ANSI 코드 |
|------|------|-----------|
| 50% 미만 | 세이지 그린 | `38;5;108` |
| 50% ~ 79% | 옐로 | `33` |
| 80% 이상 | 레드 | `91` |

### ⚡ Effort 레벨 색상

| 레벨 | 색상 | 의미 |
|------|------|------|
| low | 그레이 | 최소 사고, 빠른 응답 |
| medium | 세이지 그린 | 기본값 |
| high | 옐로 | 깊은 사고 |
| xhigh | 마젠타 | high~max 사이. `--effort ultracode`로 시작한 세션도 `xhigh`로 보고됨 (ultracode 자체는 표시되지 않음) |
| max | 레드 | 최대 사고, 최대 토큰 소모 |

effort를 지원하지 않는 모델에서는 필드 자체가 오지 않아 세그먼트가 숨겨집니다.

### 자동 숨김 규칙

데이터가 없는 세션 초반에는 불필요한 항목이 자동으로 숨겨집니다.

- 📌 세션명: `--name` / `/rename` 미사용이고 AI 제목도 없으면 숨김
- 🎭 Agent: `--agent` 플래그나 agent 설정 없이 실행하면 숨김
- 🚀 Fast mode: 꺼져 있으면 숨김
- ⚡ Effort: JSON에 effort 필드가 없으면 숨김 (v2.1.119 미만, effort 미지원 모델)
- 🔀 PR: 현재 브랜치에 열린 PR이 없으면 숨김
- +/- 코드 변경량: 추가/삭제 모두 0이면 숨김
- ⏱️ Rate Limit: 5h·7d 모두 사용량 0%이고 리셋 시각이 없으면 **Line 3 전체 숨김**
- 🌲 worktree: 링크된 worktree나 `--worktree` 세션이 아니면 숨김. worktree 이름은 브랜치명과 같으면 생략
- 📁 저장소: git 저장소가 아니거나 `origin` 리모트가 없으면 숨김
- ⏳ 경과 시간: 값이 없거나 1초 미만이면 숨김
- 📥 컨텍스트 세부: 첫 API 응답 전, `/compact` 직후(`current_usage`가 `null`이거나 0)에는 숨김
- 💭 thinking: 꺼져 있거나 필드가 없으면 숨김
- ♻️ 프롬프트 캐시: 첫 API 응답 전(`prompt_cache` 없음), `null`, 또는 이번 세션에 캐시 토큰이 한 번도 보고되지 않았으면(`caching_observed: false`) 숨김
- Line 4: 위 다섯 항목이 모두 숨겨지면 **줄 전체 숨김**

### 터미널 폭 맞춤

Claude Code는 터미널 폭을 `COLUMNS` 환경변수로 넘겨줍니다(v2.1.153+). 줄이 `COLUMNS - 2`열보다 넓으면
(2열은 `padding` 여유) 아래 순서대로 세그먼트를 숨기고, 그래도 넘치면 줄 끝을 잘라 `…`를 붙입니다.
규칙은 "설정·식별 정보를 먼저, 계속 바뀌는 수치는 나중에" 숨기는 것입니다. `COLUMNS`가 없으면 모든 세그먼트를 그대로 표시합니다.

| 줄 | 항상 표시 | 숨기는 순서 (앞쪽부터 먼저) |
|----|-----------|-----------------------------|
| Line 1 | 👤 사용자, 🤖 모델, 💰 비용 | 🎭 Agent → 📌 세션명 → ⚡ Effort → 🚀 Fast mode |
| Line 2 | 🌿 브랜치, 📦 토큰 | worktree 이름 → 🌲 worktree → 🔀 PR → +/- 변경량 |
| Line 3 | 5h 사용률 (5h가 없으면 7d) | 7d 리셋 시각 → 5h 리셋 시각 → 7d 사용률 |
| Line 4 | 없음 (모두 숨겨지면 줄 숨김) | 💭 thinking → 📁 저장소 → ⏳ 경과 시간 → 📥 컨텍스트 세부 → ♻️ 프롬프트 캐시 |

`COLUMNS` 80:

```
👤 주인 · 📌 statusline-v34 | 🤖 Opus 5.5 🚀 | ⚡ high | 💰 $13.86
🌿 feature/DPDD-2206 🌲 +1932 -73 | 🔀 #1234 ✓ | 📦 128,000 / 200,000 (64%)
⏱️ 5h ████░░░░░░ 45% reset 16:06 | 7d ████░░░░░░ 41% reset 8/14 09:00
⏳ 1h23m | 📥 cache 112k · new 16k | ♻️ warm 42m · hit 91%
```

`COLUMNS` 60:

```
👤 주인 | 🤖 Opus 5.5 🚀 | ⚡ high | 💰 $13.86
🌿 feature/DPDD-2206 | 📦 128,000 / 200,000 (64%)
⏱️ 5h ████░░░░░░ 45% reset 16:06 | 7d ████░░░░░░ 41%
⏳ 1h23m | 📥 cache 112k · new 16k | ♻️ warm 42m · hit 91%
```

표시 폭은 이모지와 한글 등 동아시아 전각 문자를 2열, 나머지를 1열로 계산합니다. 터미널이 모호한 폭의
문자(`█`, `░`, `·` 등)를 2열로 그리도록 설정되어 있으면 실제 폭이 더 넓을 수 있습니다.

---

## 사용자 이름 설정 (하이브리드)

사용자 이름은 아래 우선순위로 결정됩니다.

1. `CLAUDE_USER_NICK` 환경변수 (Claude 닉네임)
2. `git config user.name` (git 사용자명)
3. `whoami` (시스템 사용자명)

Claude 닉네임을 사용하려면 `~/.claude/settings.json`에 추가하세요:

```json
{
  "env": {
    "CLAUDE_USER_NICK": "원하는닉네임"
  }
}
```

설치 스크립트(`bash scripts/install.sh`)에서도 닉네임을 입력할 수 있습니다.

---

## 사전 요구사항

- **Claude Code** v2.1.145 이상 권장
  - v2.1.80+ : Rate Limit 데이터 (claude.ai Pro / Max / Ultra 구독)
  - v2.1.119+ : ⚡ Effort 레벨
  - v2.1.145+ : 🔀 PR 정보 (GitLab MR은 v2.1.234+)
  - v2.1.153+ : 터미널 폭 맞춤 (`COLUMNS`)
  - v2.1.251+ : ♻️ 프롬프트 캐시
  - 그 이하 버전에서도 동작하며, 지원하지 않는 세그먼트만 자동으로 숨겨집니다
- **jq** (권장) 또는 **Python 3** (jq 없으면 자동 경량 모드)

```bash
brew install jq          # macOS
sudo apt-get install jq  # Ubuntu / Debian
sudo pacman -S jq        # Arch Linux
```

---

## 설치 방법

### 방법 1: 자동 설치 (권장)

```bash
cd claude-lynceus
bash scripts/install.sh
```

자동으로 수행하는 작업:
1. jq / Python 확인 (없으면 경량 모드 적용)
2. Claude 닉네임 입력 (선택)
3. 스크립트를 `~/.claude/`에 복사
4. `~/.claude/settings.json`에 설정 추가 (기존 설정 백업)

### 방법 2: 수동 설치

```bash
# jq 있는 경우
cp scripts/statusline.sh ~/.claude/lynceus-statusline.sh

# jq 없는 경우 (Python 경량 버전)
cp scripts/statusline-lite.sh ~/.claude/lynceus-statusline.sh

chmod +x ~/.claude/lynceus-statusline.sh
```

`~/.claude/settings.json`에 추가:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/lynceus-statusline.sh",
    "padding": 1,
    "refreshInterval": 10
  }
}
```

`refreshInterval`은 이벤트 갱신에 더해 N초마다 스크립트를 다시 실행합니다.
Rate Limit과 PR 상태는 어시스턴트 메시지 없이도 변하므로, 세션이 유휴 상태일 때
값이 멈추지 않게 하려면 설정하는 편이 좋습니다. 생략하면 이벤트 발생 시에만 갱신됩니다.
♻️ 프롬프트 캐시의 남은 시간도 이 주기로 줄어듭니다. 만료 시각(`expires_at`)이 되면 Claude Code가
스크립트를 다시 실행하므로 `cold` 전환은 주기와 상관없이 바로 반영됩니다.

Claude Code를 재시작하면 상태 바가 표시됩니다.

---

## 제거 방법

```bash
bash scripts/uninstall.sh
```

---

## 커스터마이징

`~/.claude/lynceus-statusline.sh`를 편집하면 됩니다.

### 캐시 간격

```bash
CACHE_MAX_AGE=10  # 기본 5초 → 10초로
```

### 색상 변경

스크립트 상단의 색상 변수를 수정합니다.

```bash
GRN=$'\033[38;5;108m'   # 현재: 세이지 그린
GRN=$'\033[38;5;114m'   # 소프트 그린
GRN=$'\033[32m'          # 표준 초록
```

### 색상 임계값

```bash
# 기본: 50/80 기준
if [ "$PCT" -lt 60 ]; then    # 60% 미만 초록
  CTX_CLR="$GRN"
elif [ "$PCT" -lt 90 ]; then  # 90% 미만 노랑
  CTX_CLR="$YLW"
else
  CTX_CLR="$RED"
fi
```

---

## 플러그인 구조

```
claude-lynceus/
├── .claude-plugin/
│   └── plugin.json                  # 플러그인 메타데이터 + 버전
├── scripts/
│   ├── statusline.sh                # 메인 스크립트 (jq 필요)
│   ├── statusline-lite.sh           # 경량 스크립트 (Python 사용)
│   ├── install.sh                   # 자동 설치
│   ├── uninstall.sh                 # 자동 제거
│   └── release.sh                   # 릴리즈 자동화
├── skills/
│   ├── setup-statusline/
│   │   └── SKILL.md                 # 설치/설정 도우미
│   ├── install/
│   │   └── SKILL.md                 # /claude-lynceus:install
│   └── uninstall/
│       └── SKILL.md                 # /claude-lynceus:uninstall
├── CHANGELOG.md                     # 버전별 변경 이력
├── .gitignore
└── README.md
```

---

## 버저닝

[Semantic Versioning](https://semver.org/)을 따릅니다. 변경 이력은 `CHANGELOG.md`에 기록됩니다.

### 릴리즈 방법

```bash
# 패치 릴리즈 (버그 수정): 3.4.0 → 3.4.1
bash scripts/release.sh patch

# 마이너 릴리즈 (기능 추가): 3.4.0 → 3.5.0
bash scripts/release.sh minor

# 메이저 릴리즈 (브레이킹 체인지): 3.4.0 → 4.0.0
bash scripts/release.sh major

# 직접 버전 지정
bash scripts/release.sh 3.5.0
```

릴리즈 스크립트가 자동으로 수행하는 작업:
1. `plugin.json`의 version 필드 업데이트
2. `CHANGELOG.md`의 [Unreleased]를 새 버전으로 이동
3. `git commit -m "release: v{version}"`
4. `git tag -a v{version}`
5. push 여부 확인 후 실행

## 트러블슈팅

| 증상 | 해결 방법 |
|------|-----------|
| 상태 바가 안 보임 | `settings.json`에 `statusLine` 설정 확인 후 재시작 |
| 빈 줄만 표시됨 | `jq` 또는 `python3` 설치 확인 |
| 브랜치가 안 바뀜 | 캐시(5초) 때문. 잠시 기다리면 갱신 |
| Rate Limit이 안 보임 | Claude Code v2.1.80 이상, claude.ai Pro / Max / Ultra 구독 필요. 세션 초반엔 자동 숨김 |
| Rate Limit이 멈춰 있음 | `refreshInterval`을 설정. 없으면 이벤트 발생 시에만 갱신됨 |
| 비용이 $0.00 | 첫 API 응답 전까지 비용 데이터 없음 |
| PR 번호가 클릭 안 됨 | OSC 8 지원 터미널 필요 (iTerm2, Kitty, WezTerm 등) |
| 한글 닉네임 깨짐 | 터미널 인코딩을 UTF-8로 설정 |
| 일부 항목이 안 보이거나 줄 끝이 `…`로 잘림 | 터미널 폭이 좁아 [터미널 폭 맞춤](#터미널-폭-맞춤) 규칙대로 숨긴 것. 창을 넓히면 다시 표시됨 |

## 라이선스

MIT
