#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# claude-lynceus v3 — Dan Does Code style 2-line statusline
#
# Line 1: 👤 User | 🤖 Model | 🧠 Context | 💰 Cost | ⏱️ 5h Rate Limit
# Line 2: 🌿 Branch | +added -removed | 📦 used / total (%)
# ══════════════════════════════════════════════════════════════════════

input=$(cat)

# ── Colors ────────────────────────────────────────────────────────────
RST=$'\033[0m'
BLD=$'\033[1m'
DIM=$'\033[2m'
RED=$'\033[91m'
GRN=$'\033[38;5;108m'
YLW=$'\033[33m'
BLU=$'\033[34m'
CYN=$'\033[36m'
MAG=$'\033[35m'
GRY=$'\033[90m'

# ── Parse JSON ────────────────────────────────────────────────────────
MODEL=$(echo "$input" | jq -r '.model.display_name // "—"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
TOTAL=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
INPUT_TOK=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
OUTPUT_TOK=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
LINES_ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // ""')

# Rate limits (available since Claude Code v1.2.80)
RL_5H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.utilization // .rate_limits.five_hour.used_percentage // 0' 2>/dev/null | cut -d. -f1)
RL_5H_RESETS=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // ""' 2>/dev/null)

USED=$((INPUT_TOK + OUTPUT_TOK))

# ── Format cost ───────────────────────────────────────────────────────
COST_FMT=$(printf '%.2f' "$COST" 2>/dev/null || echo "0.00")

# ── Format numbers with commas ────────────────────────────────────────
fmt() { echo "$1" | rev | sed 's/[0-9]\{3\}/&,/g' | rev | sed 's/^,//'; }
USED_FMT=$(fmt "$USED")
TOTAL_FMT=$(fmt "$TOTAL")

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

# ── User name (hybrid: env → git → system) ────────────────────────────
if [ -n "$CLAUDE_USER_NICK" ]; then
  USER_NAME="$CLAUDE_USER_NICK"
  USER_SRC="env"
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
  if [ "$USER_SRC" = "git" ]; then
    USER_NAME=$(sed -n '1p' "$CACHE_FILE")
  fi
  BRANCH=$(sed -n '2p' "$CACHE_FILE")
fi

# ── Context color ─────────────────────────────────────────────────────
if [ "$PCT" -lt 50 ]; then
  CTX_CLR="$GRN"
elif [ "$PCT" -lt 80 ]; then
  CTX_CLR="$YLW"
else
  CTX_CLR="$RED"
fi

# ── 5h rate limit bar ────────────────────────────────────────────────
make_bar() {
  local pct=$1 width=${2:-10}
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  echo "$bar"
}

RL_BAR=$(make_bar "$RL_5H_PCT" 10)

if [ "$RL_5H_PCT" -lt 50 ] 2>/dev/null; then
  RL_CLR="$GRN"
elif [ "$RL_5H_PCT" -lt 80 ] 2>/dev/null; then
  RL_CLR="$YLW"
else
  RL_CLR="$RED"
fi

# Format reset time
RL_RESET_STR=""
if [ -n "$RL_5H_RESETS" ] && [ "$RL_5H_RESETS" != "null" ] && [ "$RL_5H_RESETS" != "" ]; then
  # Try parsing ISO format first, then unix timestamp
  if echo "$RL_5H_RESETS" | grep -qE '^[0-9]+$'; then
    # Unix timestamp
    if [[ "$OSTYPE" == "darwin"* ]]; then
      RL_RESET_STR=$(date -r "$RL_5H_RESETS" '+%H:%M' 2>/dev/null)
    else
      RL_RESET_STR=$(date -d "@$RL_5H_RESETS" '+%H:%M' 2>/dev/null)
    fi
  else
    # ISO format
    if [[ "$OSTYPE" == "darwin"* ]]; then
      RL_RESET_STR=$(date -jf '%Y-%m-%dT%H:%M:%S' "${RL_5H_RESETS%%.*}" '+%H:%M' 2>/dev/null)
    else
      RL_RESET_STR=$(date -d "$RL_5H_RESETS" '+%H:%M' 2>/dev/null)
    fi
  fi
fi

# ── Lines changed string ─────────────────────────────────────────────
LINES_STR=""
if [ "$LINES_ADD" -gt 0 ] 2>/dev/null || [ "$LINES_DEL" -gt 0 ] 2>/dev/null; then
  LINES_STR=" ${GRN}+${LINES_ADD}${RST} ${RED}-${LINES_DEL}${RST}"
fi

# ── Build rate limit segment ─────────────────────────────────────────
RL_STR=""
if [ "$RL_5H_PCT" -gt 0 ] 2>/dev/null || [ -n "$RL_RESET_STR" ]; then
  RL_STR=" ${DIM}|${RST} ${BLD}⏱️${RST} ${GRY}5h${RST} ${RL_CLR}${RL_BAR} ${RL_5H_PCT}%${RST}"
  if [ -n "$RL_RESET_STR" ]; then
    RL_STR+=" ${GRY}reset ${RL_RESET_STR}${RST}"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# OUTPUT: 2-line statusline
# ══════════════════════════════════════════════════════════════════════

# Line 1: 👤 User | 🤖 Model | 🧠 Context% | 💰 Cost | ⏱️ Rate Limit
LINE1="${BLD}${CYN}👤 ${USER_NAME}${RST} ${DIM}|${RST} ${BLD}🤖${RST} ${MODEL} ${DIM}|${RST} ${BLD}🧠${RST} ${CTX_CLR}${PCT}%${RST} ${DIM}|${RST} ${BLD}💰${RST} ${MAG}\$${COST_FMT}${RST}${RL_STR}"

# Line 2: 🌿 Branch +added -removed | 📦 used / total (%)
LINE2="${BLD}${GRN}🌿 ${BRANCH}${RST}${LINES_STR} ${DIM}|${RST} ${CTX_CLR}📦 ${USED_FMT} / ${TOTAL_FMT} (${PCT}%)${RST}"

echo "${LINE1}"
echo -n "${LINE2}"
