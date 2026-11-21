#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# claude-lynceus — installer
# Copies the statusline script and configures ~/.claude/settings.json
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${CYAN}ℹ${RESET}  %b\n" "$1"; }
ok()    { printf "${GREEN}✔${RESET}  %b\n" "$1"; }
warn()  { printf "${YELLOW}⚠${RESET}  %b\n" "$1"; }
fail()  { printf "${RED}✖${RESET}  %b\n" "$1"; exit 1; }

# ── Resolve paths ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
SOURCE_SCRIPT="$PLUGIN_ROOT/scripts/statusline.sh"

CLAUDE_DIR="$HOME/.claude"
DEST_SCRIPT="$CLAUDE_DIR/lynceus-statusline.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Script names used by older releases, cleaned up on install
LEGACY_SCRIPTS=(
  "$CLAUDE_DIR/session-statusline.sh"
  "$CLAUDE_DIR/claude-lynceusline.sh"
)

echo ""
printf "${BOLD}📊 Claude Lynceus — Installer${RESET}\n"
echo "────────────────────────────────────────────"
echo ""

# ── Step 1: Check dependencies ────────────────────────────────────────
info "의존성을 확인하고 있습니다..."

HAS_JQ=false
if command -v jq &>/dev/null; then
  ok "jq 설치 확인됨"
  HAS_JQ=true
else
  warn "jq가 설치되어 있지 않습니다"
  echo ""
  echo "   jq 없이도 동작하는 경량 모드로 설치합니다."
  echo "   (숫자 포맷팅 등 일부 기능이 제한됩니다)"
  echo ""
  echo "   jq 설치 방법:"
  echo "     macOS  : brew install jq"
  echo "     Ubuntu : sudo apt-get install jq"
  echo "     Arch   : sudo pacman -S jq"
  echo ""
fi

# ── Step 2: Ensure ~/.claude exists ───────────────────────────────────
if [ ! -d "$CLAUDE_DIR" ]; then
  mkdir -p "$CLAUDE_DIR"
  ok "~/.claude 디렉토리 생성됨"
else
  ok "~/.claude 디렉토리 확인됨"
fi

# ── Step 3: Copy statusline script ────────────────────────────────────
info "스테이터스라인 스크립트를 복사합니다..."

if [ ! -f "$SOURCE_SCRIPT" ]; then
  fail "statusline.sh를 찾을 수 없습니다: $SOURCE_SCRIPT"
fi

if [ "$HAS_JQ" = true ]; then
  cp "$SOURCE_SCRIPT" "$DEST_SCRIPT"
else
  cp "$PLUGIN_ROOT/scripts/statusline-lite.sh" "$DEST_SCRIPT"
fi

chmod +x "$DEST_SCRIPT"
ok "스크립트 복사 완료 → $DEST_SCRIPT"

# Remove scripts left behind by older releases
for legacy in "${LEGACY_SCRIPTS[@]}"; do
  if [ -f "$legacy" ]; then
    rm -f "$legacy"
    ok "이전 버전 스크립트 정리: $legacy"
  fi
done

# ── Step 4: Ask for Claude nickname (optional) ────────────────────────
echo ""
info "Claude 계정 닉네임을 설정하시겠습니까?"
echo "   (설정하면 git 이름 대신 닉네임이 표시됩니다)"
echo "   (건너뛰려면 Enter를 누르세요)"
echo ""
printf "   닉네임: "
read -r NICK_INPUT

NICK_INPUT=$(echo "$NICK_INPUT" | xargs)  # trim whitespace

if [ -n "$NICK_INPUT" ]; then
  ok "닉네임 설정: $NICK_INPUT"
else
  info "닉네임 미설정 → git 이름 또는 시스템 이름이 표시됩니다"
fi

# ── Step 5: Update settings.json ──────────────────────────────────────
info "settings.json을 업데이트합니다..."

# refreshInterval keeps the rate-limit and PR segments current while the
# session sits idle, since those change without an assistant message.
STATUSLINE_CONFIG='{
  "type": "command",
  "command": "~/.claude/lynceus-statusline.sh",
  "padding": 1,
  "refreshInterval": 10
}'

if [ -f "$SETTINGS_FILE" ]; then
  # Backup existing settings
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup.$(date +%Y%m%d%H%M%S)"
  ok "기존 설정 백업 완료"

  if [ "$HAS_JQ" = true ]; then
    # Merge statusLine config
    jq --argjson sl "$STATUSLINE_CONFIG" '. + {statusLine: $sl}' \
      "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && \
      mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"

    # Add nickname to env if provided
    if [ -n "$NICK_INPUT" ]; then
      jq --arg nick "$NICK_INPUT" '.env = (.env // {}) + {CLAUDE_USER_NICK: $nick}' \
        "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && \
        mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    fi
  else
    # Simple check-and-append without jq
    if grep -q '"statusLine"' "$SETTINGS_FILE"; then
      warn "settings.json에 이미 statusLine 설정이 있습니다."
      echo "   수동으로 업데이트해 주세요:"
      echo ""
      echo '   "statusLine": {'
      echo '     "type": "command",'
      echo '     "command": "~/.claude/lynceus-statusline.sh",'
      echo '     "padding": 1,'
      echo '     "refreshInterval": 10'
      echo '   }'
      echo ""
    else
      # Insert before the last closing brace
      sed -i.bak 's/}$/,\n  "statusLine": {\n    "type": "command",\n    "command": "~\/.claude\/lynceus-statusline.sh",\n    "padding": 1,\n    "refreshInterval": 10\n  }\n}/' "$SETTINGS_FILE"
      rm -f "${SETTINGS_FILE}.bak"
    fi
  fi
else
  # Create new settings file
  if [ -n "$NICK_INPUT" ]; then
    cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "CLAUDE_USER_NICK": "$NICK_INPUT"
  },
  "statusLine": {
    "type": "command",
    "command": "~/.claude/lynceus-statusline.sh",
    "padding": 1,
    "refreshInterval": 10
  }
}
EOF
  else
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/lynceus-statusline.sh",
    "padding": 1,
    "refreshInterval": 10
  }
}
EOF
  fi
fi

ok "settings.json 업데이트 완료"

# ── Step 6: Verify ────────────────────────────────────────────────────
echo ""
printf "${BOLD}────────────────────────────────────────────${RESET}\n"
echo ""

if [ -f "$DEST_SCRIPT" ] && [ -x "$DEST_SCRIPT" ]; then
  ok "${BOLD}설치가 완료되었습니다!${RESET}"
  echo ""
  echo "   다음 단계:"
  echo "   1. Claude Code를 재시작하세요"
  echo "   2. 터미널 하단에 상태 바가 표시됩니다"
  echo ""
  if [ -n "$NICK_INPUT" ]; then
    echo "   표시 예시:"
    echo "   👤 $NICK_INPUT | 🤖 Opus 5.5 | ⚡ high | 💰 \$0.12"
    echo "   🌿 main | 📦 12,400 / 200,000 (6%)"
    echo "   ⏱️ 5h ██░░░░░░░░ 21% reset 16:06 | 7d ████░░░░░░ 41% reset 8/14 09:00"
    echo ""
    echo "   닉네임 변경: ~/.claude/settings.json 의 CLAUDE_USER_NICK 수정"
  else
    echo "   표시 예시:"
    echo "   👤 git-username | 🤖 Opus 5.5 | ⚡ high | 💰 \$0.12"
    echo "   🌿 main | 📦 12,400 / 200,000 (6%)"
    echo "   ⏱️ 5h ██░░░░░░░░ 21% reset 16:06 | 7d ████░░░░░░ 41% reset 8/14 09:00"
    echo ""
    echo "   닉네임 추가: ~/.claude/settings.json 에 아래 내용 추가"
    echo '   "env": { "CLAUDE_USER_NICK": "내닉네임" }'
  fi
  echo ""
  echo "   제거하려면: bash $PLUGIN_ROOT/scripts/uninstall.sh"
else
  fail "설치에 실패했습니다. 스크립트를 확인해 주세요."
fi
