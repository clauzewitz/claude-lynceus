#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# claude-lynceus v3 LITE — no jq required (uses Python 3)
#
# Line 1: 👤 User | 🤖 Model | 🧠 Context | 💰 Cost | ⏱️ 5h Rate Limit
# Line 2: 🌿 Branch | +added -removed | 📦 used / total (%)
# ══════════════════════════════════════════════════════════════════════

input=$(cat)

# ── Colors ────────────────────────────────────────────────────────────
RST=$'\033[0m'; BLD=$'\033[1m'; DIM=$'\033[2m'
RED=$'\033[91m'; GRN=$'\033[38;5;108m'; YLW=$'\033[33m'
CYN=$'\033[36m'; MAG=$'\033[35m'; GRY=$'\033[90m'

# ── Parse JSON with Python ────────────────────────────────────────────
eval $(python3 -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
    cw = d.get('context_window', {})
    c = d.get('cost', {})
    rl = d.get('rate_limits', {}).get('five_hour', {})
    print(f'MODEL=\"{d.get(\"model\",{}).get(\"display_name\",\"—\")}\"')
    print(f'PCT={int(float(cw.get(\"used_percentage\",0)))}')
    print(f'TOTAL={int(cw.get(\"context_window_size\",0))}')
    print(f'USED={int(cw.get(\"total_input_tokens\",0))+int(cw.get(\"total_output_tokens\",0))}')
    print(f'COST={c.get(\"total_cost_usd\",0)}')
    print(f'LINES_ADD={int(c.get(\"total_lines_added\",0))}')
    print(f'LINES_DEL={int(c.get(\"total_lines_removed\",0))}')
    print(f'CWD=\"{d.get(\"workspace\",{}).get(\"current_dir\",\"\")}\"')
    print(f'RL_5H_PCT={int(float(rl.get(\"utilization\",rl.get(\"used_percentage\",0))))}')
    print(f'RL_5H_RESETS=\"{rl.get(\"resets_at\",\"\")}\"')
except:
    print('MODEL=\"—\"; PCT=0; TOTAL=0; USED=0; COST=0; LINES_ADD=0; LINES_DEL=0; CWD=\"\"; RL_5H_PCT=0; RL_5H_RESETS=\"\"')
" <<< "$input")

COST_FMT=$(printf '%.2f' "$COST" 2>/dev/null || echo "0.00")

# ── Format numbers ────────────────────────────────────────────────────
fmt() { echo "$1" | rev | sed 's/[0-9]\{3\}/&,/g' | rev | sed 's/^,//'; }
USED_FMT=$(fmt "$USED"); TOTAL_FMT=$(fmt "$TOTAL")

# ── Cache for git info ────────────────────────────────────────────────
CACHE_FILE="/tmp/lynceus-cache"
CACHE_MAX_AGE=5

cache_is_stale() {
  [ ! -f "$CACHE_FILE" ] && return 0
  if [[ "$OSTYPE" == "darwin"* ]]; then
    local mod=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  else
    local mod=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  fi
  local now=$(date +%s)
  (( now - mod >= CACHE_MAX_AGE ))
}

# ── User name (hybrid) ───────────────────────────────────────────────
if [ -n "$CLAUDE_USER_NICK" ]; then
  USER_NAME="$CLAUDE_USER_NICK"; USER_SRC="env"
else
  USER_SRC="git"
fi

if cache_is_stale; then
  if [ "$USER_SRC" = "git" ]; then
    USER_NAME=$(git -C "$CWD" config user.name 2>/dev/null)
    [ -z "$USER_NAME" ] && USER_NAME=$(whoami 2>/dev/null || echo "unknown")
  fi
  if git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
    [ -z "$BRANCH" ] && BRANCH="(detached)"
  else
    BRANCH="—"
  fi
  printf '%s\n%s' "$USER_NAME" "$BRANCH" > "$CACHE_FILE"
else
  [ "$USER_SRC" = "git" ] && USER_NAME=$(sed -n '1p' "$CACHE_FILE")
  BRANCH=$(sed -n '2p' "$CACHE_FILE")
fi

# ── Colors by percentage ──────────────────────────────────────────────
ctx_color() { [ "$1" -lt 50 ] && echo "$GRN" || { [ "$1" -lt 80 ] && echo "$YLW" || echo "$RED"; }; }
CTX_CLR=$(ctx_color "$PCT")
RL_CLR=$(ctx_color "$RL_5H_PCT")

# ── Rate limit bar ────────────────────────────────────────────────────
BAR=""; F=$((RL_5H_PCT * 10 / 100)); E=$((10 - F))
for ((i=0;i<F;i++)); do BAR+="█"; done
for ((i=0;i<E;i++)); do BAR+="░"; done

RL_STR=""
if [ "$RL_5H_PCT" -gt 0 ] 2>/dev/null; then
  RL_STR=" ${DIM}|${RST} ${BLD}⏱️${RST} ${GRY}5h${RST} ${RL_CLR}${BAR} ${RL_5H_PCT}%${RST}"
fi

# ── Lines changed ─────────────────────────────────────────────────────
LINES_STR=""
if [ "$LINES_ADD" -gt 0 ] 2>/dev/null || [ "$LINES_DEL" -gt 0 ] 2>/dev/null; then
  LINES_STR=" ${GRN}+${LINES_ADD}${RST} ${RED}-${LINES_DEL}${RST}"
fi

# ── Output ────────────────────────────────────────────────────────────
LINE1="${BLD}${CYN}👤 ${USER_NAME}${RST} ${DIM}|${RST} ${BLD}🤖${RST} ${MODEL} ${DIM}|${RST} ${BLD}🧠${RST} ${CTX_CLR}${PCT}%${RST} ${DIM}|${RST} ${BLD}💰${RST} ${MAG}\$${COST_FMT}${RST}${RL_STR}"
LINE2="${BLD}${GRN}🌿 ${BRANCH}${RST}${LINES_STR} ${DIM}|${RST} ${CTX_CLR}📦 ${USED_FMT} / ${TOTAL_FMT} (${PCT}%)${RST}"

echo "${LINE1}"
echo -n "${LINE2}"
