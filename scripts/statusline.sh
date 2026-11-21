#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# claude-lynceus v3.4 — Dan Does Code style statusline (up to 4 lines)
#
# Line 1: 👤 User · 📌 Session | 🤖 Model 🚀 | ⚡ Effort | 🧠 Context | 💰 Cost
# Line 2: 🌿 Branch 🌲 | +added -removed | 🔀 PR | 📦 used / total (%)
# Line 3: ⏱️ 5h bar % reset | 7d bar % reset
# Line 4: 📁 owner/repo | ⏳ elapsed | 📥 cache · new | 💭 thinking
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

# ── Parse JSON (one jq call) ──────────────────────────────────────────
# @sh quotes every value for the eval. Displayed strings have control
# characters stripped so a session name or PR URL can't inject terminal
# escape sequences.
#   session_name: custom (--name / /rename) or AI-generated title, absent for defaults
#   rate_limits:  Claude Code v2.1.80+
#   effort.level: Claude Code v2.1.119+, absent when the model has no effort parameter
#   pr:           open PR for the current branch; pr.kind is "mr" for GitLab (v2.1.234+)
#   worktree:     workspace.git_worktree (linked git worktree) or worktree.name (--worktree session)
#   current_usage: null before the first API call and after /compact; cache reads vs new input
eval "$(echo "$input" | jq -r '
  def clean: tostring | gsub("[[:cntrl:]]"; "");
  def int: if type == "number" then floor else 0 end;
  def obj: if type == "object" then . else {} end;
  @sh "MODEL=\(.model.display_name // "—" | clean)",
  @sh "PCT=\(.context_window.used_percentage | int)",
  @sh "TOTAL=\(.context_window.context_window_size | int)",
  @sh "INPUT_TOK=\(.context_window.total_input_tokens | int)",
  @sh "COST=\(.cost.total_cost_usd | if type == "number" then . else 0 end)",
  @sh "LINES_ADD=\(.cost.total_lines_added | int)",
  @sh "LINES_DEL=\(.cost.total_lines_removed | int)",
  @sh "CWD=\(.workspace.current_dir // "")",
  @sh "SESSION_ID=\(.session_id // "" | clean)",
  @sh "SESSION_NAME=\(.session_name // "" | clean)",
  @sh "RL_5H_PCT=\(.rate_limits.five_hour.used_percentage | int)",
  @sh "RL_5H_RESETS=\(.rate_limits.five_hour.resets_at // "" | clean)",
  @sh "RL_7D_PCT=\(.rate_limits.seven_day.used_percentage | int)",
  @sh "RL_7D_RESETS=\(.rate_limits.seven_day.resets_at // "" | clean)",
  @sh "EFFORT=\(.effort.level // "" | clean)",
  @sh "FAST_MODE=\(.fast_mode // false)",
  @sh "PR_NUM=\(.pr.number // "" | clean)",
  @sh "PR_URL=\(.pr.url // "" | clean)",
  @sh "PR_STATE=\(.pr.review_state // "" | clean)",
  @sh "PR_KIND=\(.pr.kind // "" | clean)",
  @sh "REPO_OWNER=\(.workspace.repo | obj | .owner // "" | clean)",
  @sh "REPO_NAME=\(.workspace.repo | obj | .name // "" | clean)",
  @sh "WORKTREE=\(.workspace.git_worktree // (.worktree | obj | .name) // "" | clean)",
  @sh "DURATION_S=\(.cost.total_duration_ms | if type == "number" then . / 1000 | floor else 0 end)",
  @sh "CACHE_READ=\(.context_window.current_usage | obj | .cache_read_input_tokens | int)",
  @sh "NEW_INPUT=\(.context_window.current_usage | obj | (.input_tokens | int) + (.cache_creation_input_tokens | int))",
  @sh "THINKING=\(.thinking | obj | .enabled == true)"
')"

# used_percentage counts input tokens only (input + cache writes + cache
# reads, which total_input_tokens already sums), so the count matches it.
USED=$INPUT_TOK

# ── Format cost ───────────────────────────────────────────────────────
COST_FMT=$(printf '%.2f' "$COST" 2>/dev/null || echo "0.00")

# ── Format numbers with commas ────────────────────────────────────────
fmt() { echo "$1" | rev | sed 's/[0-9]\{3\}/&,/g' | rev | sed 's/^,//'; }
USED_FMT=$(fmt "$USED")
TOTAL_FMT=$(fmt "$TOTAL")

# ── Cache for git info (per session, so parallel sessions don't collide) ──
CACHE_FILE="/tmp/lynceus-cache-${SESSION_ID:-default}"
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
  # Drop caches of sessions that haven't refreshed for a day (closed sessions)
  find /tmp/ -maxdepth 1 -name 'lynceus-cache-*' -mmin +1440 -delete 2>/dev/null

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

# ── Rate limit helpers ───────────────────────────────────────────────
make_bar() {
  local pct=$1 width=${2:-10}
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  echo "$bar"
}

pct_color() {
  if [ "$1" -lt 50 ] 2>/dev/null; then
    echo "$GRN"
  elif [ "$1" -lt 80 ] 2>/dev/null; then
    echo "$YLW"
  else
    echo "$RED"
  fi
}

# resets_at is unix epoch seconds; older builds sent ISO 8601, so handle both.
fmt_reset() {
  local ts="$1" out_fmt="$2"
  if [ -z "$ts" ] || [ "$ts" = "null" ]; then
    echo ""
    return
  fi
  if echo "$ts" | grep -qE '^[0-9]+$'; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      date -r "$ts" "$out_fmt" 2>/dev/null
    else
      date -d "@$ts" "$out_fmt" 2>/dev/null
    fi
  else
    if [[ "$OSTYPE" == "darwin"* ]]; then
      date -jf '%Y-%m-%dT%H:%M:%S' "${ts%%.*}" "$out_fmt" 2>/dev/null
    else
      date -d "$ts" "$out_fmt" 2>/dev/null
    fi
  fi
}

# Build one "5h ████░░░░░░ 45% reset 16:06" segment
rl_segment() {
  local label=$1 pct=$2 resets=$3 out_fmt=$4
  local reset_str=$(fmt_reset "$resets" "$out_fmt")
  if [ "$pct" -le 0 ] 2>/dev/null && [ -z "$reset_str" ]; then
    echo ""
    return
  fi
  local clr=$(pct_color "$pct")
  local seg="${GRY}${label}${RST} ${clr}$(make_bar "$pct" 10) ${pct}%${RST}"
  [ -n "$reset_str" ] && seg+=" ${GRY}reset ${reset_str}${RST}"
  echo "$seg"
}

RL_5H_SEG=$(rl_segment "5h" "$RL_5H_PCT" "$RL_5H_RESETS" '+%H:%M')
RL_7D_SEG=$(rl_segment "7d" "$RL_7D_PCT" "$RL_7D_RESETS" '+%-m/%-d %H:%M')

# ── Lines changed string ─────────────────────────────────────────────
LINES_STR=""
if [ "$LINES_ADD" -gt 0 ] 2>/dev/null || [ "$LINES_DEL" -gt 0 ] 2>/dev/null; then
  LINES_STR=" ${GRN}+${LINES_ADD}${RST} ${RED}-${LINES_DEL}${RST}"
fi

# ── Build session name segment ───────────────────────────────────────
SESSION_STR=""
if [ -n "$SESSION_NAME" ]; then
  SESSION_STR=" ${DIM}·${RST} ${BLD}📌${RST} ${BLU}${SESSION_NAME}${RST}"
fi

# ── Build fast mode badge ────────────────────────────────────────────
FAST_STR=""
[ "$FAST_MODE" = "true" ] && FAST_STR=" 🚀"

# ── Build effort segment ─────────────────────────────────────────────
EFFORT_STR=""
if [ -n "$EFFORT" ]; then
  case "$EFFORT" in
    low)    EFF_CLR="$GRY" ;;
    medium) EFF_CLR="$GRN" ;;
    high)   EFF_CLR="$YLW" ;;
    xhigh)  EFF_CLR="$MAG" ;;
    max)    EFF_CLR="$RED" ;;
    *)      EFF_CLR="$GRY" ;;
  esac
  EFFORT_STR=" ${DIM}|${RST} ${BLD}⚡${RST} ${EFF_CLR}${EFFORT}${RST}"
fi

# ── Session detail segments (Line 4) ─────────────────────────────────
# 1234 → 1234, 8512 → 8.5k, 82000 → 82k, 1234567 → 1.2M (truncated, not rounded)
fmt_k() {
  local n=$1
  if (( n < 1000 )); then echo "$n"
  elif (( n < 10000 )); then echo "$((n / 1000)).$(((n % 1000) / 100))k"
  elif (( n < 1000000 )); then echo "$((n / 1000))k"
  else echo "$((n / 1000000)).$(((n % 1000000) / 100000))M"
  fi
}

# 45 → 45s, 754 → 12m, 4980 → 1h23m
fmt_dur() {
  local s=$1
  if (( s < 60 )); then echo "${s}s"
  elif (( s < 3600 )); then echo "$((s / 60))m"
  else printf '%dh%02dm' $((s / 3600)) $(((s % 3600) / 60))
  fi
}

WT_STR=""
[ -n "$WORKTREE" ] && WT_STR=" 🌲"

DETAIL_SEGS=()
if [ -n "$REPO_NAME" ]; then
  REPO_STR="$REPO_NAME"
  [ -n "$REPO_OWNER" ] && REPO_STR="${REPO_OWNER}/${REPO_NAME}"
  DETAIL_SEGS+=("${BLD}📁${RST} ${CYN}${REPO_STR}${RST}")
fi
if [ "$DURATION_S" -gt 0 ] 2>/dev/null; then
  DETAIL_SEGS+=("${BLD}⏳${RST} $(fmt_dur "$DURATION_S")")
fi
if [ "$CACHE_READ" -gt 0 ] 2>/dev/null || [ "$NEW_INPUT" -gt 0 ] 2>/dev/null; then
  DETAIL_SEGS+=("${BLD}📥${RST} ${GRY}cache${RST} $(fmt_k "$CACHE_READ") ${DIM}·${RST} ${GRY}new${RST} $(fmt_k "$NEW_INPUT")")
fi
[ "$THINKING" = "true" ] && DETAIL_SEGS+=("${BLD}💭${RST} ${GRY}thinking${RST}")

LINE4=""
for seg in "${DETAIL_SEGS[@]}"; do
  [ -n "$LINE4" ] && LINE4+=" ${DIM}|${RST} "
  LINE4+="$seg"
done

# ── Build PR segment (OSC 8 hyperlink when a URL is available) ───────
PR_STR=""
if [ -n "$PR_NUM" ]; then
  case "$PR_STATE" in
    approved)          PR_MARK=" ${GRN}✓${RST}" ;;
    changes_requested) PR_MARK=" ${RED}✗${RST}" ;;
    pending)           PR_MARK=" ${YLW}⋯${RST}" ;;
    draft)             PR_MARK=" ${GRY}○${RST}" ;;
    *)                 PR_MARK="" ;;
  esac
  PR_LABEL="#${PR_NUM}"
  [ "$PR_KIND" = "mr" ] && PR_LABEL="!${PR_NUM}"   # GitLab merge request
  if [ -n "$PR_URL" ]; then
    PR_LABEL=$'\033]8;;'"${PR_URL}"$'\a'"${PR_LABEL}"$'\033]8;;\a'
  fi
  PR_STR=" ${DIM}|${RST} ${BLD}🔀${RST} ${CYN}${PR_LABEL}${RST}${PR_MARK}"
fi

# ══════════════════════════════════════════════════════════════════════
# OUTPUT: up to 4 lines
# ══════════════════════════════════════════════════════════════════════

# Line 1: 👤 User · 📌 Session | 🤖 Model 🚀 | ⚡ Effort | 🧠 Context% | 💰 Cost
LINE1="${BLD}${CYN}👤 ${USER_NAME}${RST}${SESSION_STR} ${DIM}|${RST} ${BLD}🤖${RST} ${MODEL}${FAST_STR}${EFFORT_STR} ${DIM}|${RST} ${BLD}🧠${RST} ${CTX_CLR}${PCT}%${RST} ${DIM}|${RST} ${BLD}💰${RST} ${MAG}\$${COST_FMT}${RST}"

# Line 2: 🌿 Branch 🌲 +added -removed | 🔀 PR | 📦 used / total (%)
LINE2="${BLD}${GRN}🌿 ${BRANCH}${RST}${WT_STR}${LINES_STR}${PR_STR} ${DIM}|${RST} ${CTX_CLR}📦 ${USED_FMT} / ${TOTAL_FMT} (${PCT}%)${RST}"

echo "${LINE1}"

OUT="${LINE2}"

# Line 3: ⏱️ 5h bar % reset | 7d bar % reset — hidden when no rate limit data
if [ -n "$RL_5H_SEG" ] || [ -n "$RL_7D_SEG" ]; then
  LINE3="${BLD}⏱️${RST} "
  if [ -n "$RL_5H_SEG" ]; then
    LINE3+="$RL_5H_SEG"
    [ -n "$RL_7D_SEG" ] && LINE3+=" ${DIM}|${RST} $RL_7D_SEG"
  else
    LINE3+="$RL_7D_SEG"
  fi
  OUT+=$'\n'"${LINE3}"
fi

# Line 4: 📁 repo | ⏳ elapsed | 📥 cache · new | 💭 thinking — hidden when empty
[ -n "$LINE4" ] && OUT+=$'\n'"${LINE4}"

echo -n "${OUT}"
