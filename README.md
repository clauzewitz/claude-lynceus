# 📊 Claude Lynceus v3.0

Claude Code 터미널 하단에 **항상 표시되는 2줄 상태 바**를 추가하는 플러그인입니다.

## 미리보기

```
👤 주인 | 🤖 Opus 4.6 | ⚡ high | 🧠 64% | 💰 $13.86 | ⏱️ 5h ████░░░░░░ 45%
🌿 feature/DPDD-2206 +1932 -73 | 📦 96,737 / 200,000 (64%)
```

---

## 표시 속성

### Line 1 — 세션 메타데이터

| 아이콘 | 속성 | 데이터 소스 | 비고 |
|--------|------|-------------|------|
| 👤 | 사용자 이름 | `CLAUDE_USER_NICK` → `git config user.name` → `whoami` | 하이브리드 우선순위 |
| 🤖 | 모델명 | `model.display_name` | |
| ⚡ | Effort 레벨 | `effort.level` → `$CLAUDE_EFFORT` | v2.1.131+, 색상 변동, 없으면 숨김 |
| 🧠 | 컨텍스트 사용률 | `context_window.used_percentage` | 색상 변동 |
| 💰 | 세션 비용 | `cost.total_cost_usd` | USD 표시 |
| ⏱️ | 5시간 Rate Limit | `rate_limits.five_hour.utilization` | 프로그레스 바 + 리셋 시각 |

### Line 2 — git 컨텍스트

| 아이콘 | 속성 | 데이터 소스 | 비고 |
|--------|------|-------------|------|
| 🌿 | git 브랜치 | `git branch --show-current` | 미연결 시 — 표시 |
| +/- | 코드 변경량 | `cost.total_lines_added/removed` | 0이면 자동 숨김 |
| 📦 | 토큰 사용량 | `total_input_tokens + total_output_tokens` | 쉼표 포맷 |
| | 전체 토큰 / 백분율 | `context_window_size`, `used_percentage` | 색상 변동 |

### 색상 변동 기준

🧠 컨텍스트, ⏱️ Rate Limit, 📦 토큰 사용량에 공통 적용됩니다.

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
| xhigh | 마젠타 | Opus 4.7 전용, high~max 사이 |
| max | 레드 | 최대 사고, 최대 토큰 소모 |

### 자동 숨김 규칙

데이터가 없는 세션 초반에는 불필요한 항목이 자동으로 숨겨집니다.

- ⚡ Effort: JSON에 effort 필드가 없으면 숨김 (v2.1.131 미만 호환)
- ⏱️ Rate Limit: 사용량이 0%이고 리셋 시각이 없으면 숨김
- +/- 코드 변경량: 추가/삭제 모두 0이면 숨김

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

- **Claude Code** v1.2.80 이상 (Rate Limit 데이터 지원)
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
    "padding": 0
  }
}
```

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
│   └── setup-statusline/
│       └── SKILL.md                 # 설치/설정 도우미
├── commands/
│   ├── install.md                   # /claude-lynceus:install
│   └── uninstall.md                 # /claude-lynceus:uninstall
├── CHANGELOG.md                     # 버전별 변경 이력
├── .gitignore
└── README.md
```

---

## 버저닝

[Semantic Versioning](https://semver.org/)을 따릅니다. 변경 이력은 `CHANGELOG.md`에 기록됩니다.

### 릴리즈 방법

```bash
# 패치 릴리즈 (버그 수정): 3.3.0 → 3.3.1
bash scripts/release.sh patch

# 마이너 릴리즈 (기능 추가): 3.3.0 → 3.4.0
bash scripts/release.sh minor

# 메이저 릴리즈 (브레이킹 체인지): 3.3.0 → 4.0.0
bash scripts/release.sh major

# 직접 버전 지정
bash scripts/release.sh 3.4.0
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
| Rate Limit이 안 보임 | Claude Code v1.2.80 이상 필요. 세션 초반엔 자동 숨김 |
| 비용이 $0.00 | 첫 API 응답 전까지 비용 데이터 없음 |
| 한글 닉네임 깨짐 | 터미널 인코딩을 UTF-8로 설정 |

## 라이선스

MIT
