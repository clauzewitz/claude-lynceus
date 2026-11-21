#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# claude-lynceus — uninstaller
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${CYAN}ℹ${RESET}  %b\n" "$1"; }
ok()    { printf "${GREEN}✔${RESET}  %b\n" "$1"; }

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Current name first, then names used by older releases
TARGET_SCRIPTS=(
  "$CLAUDE_DIR/lynceus-statusline.sh"
  "$CLAUDE_DIR/session-statusline.sh"
  "$CLAUDE_DIR/claude-lynceusline.sh"
)

echo ""
printf "${BOLD}📊 Claude Lynceus — Uninstaller${RESET}\n"
echo "────────────────────────────────────────────"
echo ""

# ── Remove script ─────────────────────────────────────────────────────
REMOVED=false
for target in "${TARGET_SCRIPTS[@]}"; do
  if [ -f "$target" ]; then
    rm "$target"
    ok "스크립트 삭제 완료: $target"
    REMOVED=true
  fi
done
if [ "$REMOVED" = false ]; then
  info "스크립트가 이미 없습니다"
fi

# ── Remove statusLine from settings.json ──────────────────────────────
if [ -f "$SETTINGS_FILE" ]; then
  if command -v jq &>/dev/null; then
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    jq 'del(.statusLine)' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && \
      mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    ok "settings.json에서 statusLine 설정 제거 완료"
  else
    info "jq가 없어 settings.json을 자동으로 수정할 수 없습니다"
    echo "   ~/.claude/settings.json에서 \"statusLine\" 블록을 수동 삭제해 주세요"
  fi
fi

# ── Clean up cache ────────────────────────────────────────────────────
# v3.4+ caches per session; older versions used a single shared file
rm -f /tmp/lynceus-cache /tmp/lynceus-cache-*
ok "캐시 파일 정리 완료"

echo ""
ok "${BOLD}제거가 완료되었습니다!${RESET}"
echo ""
echo "   Claude Code를 재시작하면 상태 바가 사라집니다."
echo ""
