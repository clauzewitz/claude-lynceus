#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# claude-lynceus v3.4 — Dan Does Code style statusline (up to 4 lines)
#
# Line 1: 👤 User · 📌 Session | 🤖 Model 🚀 | ⚡ Effort | 💰 Cost
# Line 2: 🌿 Branch 🌲 | +added -removed | 🔀 PR | 📦 used / total (%)
# Line 3: ⏱️ 5h bar % reset | 7d bar % reset
# Line 4: 📁 owner/repo | ⏳ elapsed | 📥 cache · new | ♻️ prompt cache | 💭 thinking
# With COLUMNS set, lines that are too wide drop optional segments to fit.
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
#   prompt_cache: v2.1.251+, absent until the first API response
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
  @sh "THINKING=\(.thinking | obj | .enabled == true)",
  @sh "PC_ON=\(.prompt_cache | obj | .caching_observed == true)",
  @sh "PC_WARM=\(.prompt_cache | obj | .warm == true)",
  @sh "PC_EXPIRES=\(.prompt_cache | obj | .expires_at | int)",
  @sh "PC_HIT=\(.prompt_cache | obj | .hit_ratio | if type == "number" then . * 100 + 0.5 | floor else -1 end)",
  @sh "PC_MISSES=\(.prompt_cache | obj | .misses | int)"
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
  LINES_STR="${GRN}+${LINES_ADD}${RST} ${RED}-${LINES_DEL}${RST}"
fi

# ── Build session name segment ───────────────────────────────────────
SESSION_STR=""
if [ -n "$SESSION_NAME" ]; then
  SESSION_STR="${BLD}📌${RST} ${BLU}${SESSION_NAME}${RST}"
fi

# ── Build fast mode badge ────────────────────────────────────────────
FAST_STR=""
[ "$FAST_MODE" = "true" ] && FAST_STR="🚀"

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
  EFFORT_STR="${BLD}⚡${RST} ${EFF_CLR}${EFFORT}${RST}"
fi

# ── Session detail helpers ───────────────────────────────────────────
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

REPO_STR=""
if [ -n "$REPO_NAME" ]; then
  REPO_STR="$REPO_NAME"
  [ -n "$REPO_OWNER" ] && REPO_STR="${REPO_OWNER}/${REPO_NAME}"
fi

DUR_STR=""
[ "$DURATION_S" -gt 0 ] 2>/dev/null && DUR_STR="$(fmt_dur "$DURATION_S")"

CTX_DETAIL_STR=""
if [ "$CACHE_READ" -gt 0 ] 2>/dev/null || [ "$NEW_INPUT" -gt 0 ] 2>/dev/null; then
  CTX_DETAIL_STR="${GRY}cache${RST} $(fmt_k "$CACHE_READ") ${DIM}·${RST} ${GRY}new${RST} $(fmt_k "$NEW_INPUT")"
fi

# ── Prompt cache segment ─────────────────────────────────────────────
# warm: time left before the cached prefix expires (expires_at - now);
# cold: expired or no cache tokens in the last response. Hidden when
# prompt_cache is absent or no response this session reported cache tokens.
PC_STR=""
if [ "$PC_ON" = "true" ]; then
  PC_LEFT=$(( PC_EXPIRES - $(date +%s) ))
  if [ "$PC_WARM" = "true" ] && [ "$PC_LEFT" -gt 0 ]; then
    PC_STR="${GRN}warm${RST} $(fmt_dur "$PC_LEFT")"
  else
    PC_STR="${YLW}cold${RST}"
  fi
  [ "$PC_HIT" -ge 0 ] 2>/dev/null && PC_STR+=" ${DIM}·${RST} ${GRY}hit${RST} ${PC_HIT}%"
  [ "$PC_MISSES" -gt 0 ] 2>/dev/null && PC_STR+=" ${DIM}·${RST} ${GRY}miss${RST} ${PC_MISSES}"
fi

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
  PR_STR="${BLD}🔀${RST} ${CYN}${PR_LABEL}${RST}${PR_MARK}"
fi

# ══════════════════════════════════════════════════════════════════════
# LAYOUT: fit each line to the terminal width
# ══════════════════════════════════════════════════════════════════════
# Claude Code passes the terminal width in COLUMNS (v2.1.153+). Without it
# every segment is shown as is. With it, a line that is too wide drops its
# optional segments, highest drop rank first, and is cut with "…" if it
# still does not fit. Two columns are left for the status line padding.

# Widths are measured by walking the UTF-8 bytes, so index bytes, not chars
LC_ALL=C

BUDGET=""
case "$COLUMNS" in
  ''|*[!0-9]*) ;;
  *) BUDGET=$(( COLUMNS - 2 )); (( BUDGET < 1 )) && BUDGET=1 ;;
esac

# Display width of $1, skipping CSI (colors) and OSC (hyperlink) escapes.
# Sets DW, and CUT to the byte offset of the first character that would
# take the width past $2 (-1 if it never does).
# Wide (2): East Asian wide/fullwidth ranges and emoji; zero (0): control,
# combining and zero-width characters; U+FE0F widens the previous
# character to 2; everything else 1.
str_width() {
  local s=$1 max=${2:-0} n=${#1} i=0 w=0 b c cp len k cw last=0 lastpos=0
  CUT=-1
  while (( i < n )); do
    printf -v b '%d' "'${s:i:1}"; b=$(( b & 255 ))
    if (( b == 27 )); then
      printf -v c '%d' "'${s:i+1:1}"; c=$(( c & 255 )); i=$(( i + 2 ))
      if (( c == 91 )); then
        while (( i < n )); do
          printf -v c '%d' "'${s:i:1}"; c=$(( c & 255 )); i=$(( i + 1 ))
          (( c >= 64 && c <= 126 )) && break
        done
      elif (( c == 93 )); then
        while (( i < n )); do
          printf -v c '%d' "'${s:i:1}"; c=$(( c & 255 )); i=$(( i + 1 ))
          (( c == 7 )) && break
        done
      fi
      continue
    fi
    if (( b < 128 )); then cp=$b; len=1
    elif (( b >= 240 )); then cp=$(( b & 7 )); len=4
    elif (( b >= 224 )); then cp=$(( b & 15 )); len=3
    elif (( b >= 192 )); then cp=$(( b & 31 )); len=2
    else cp=65533; len=1
    fi
    for (( k = 1; k < len; k++ )); do
      printf -v c '%d' "'${s:i+k:1}"; cp=$(( (cp << 6) | (c & 63) ))
    done
    if (( cp == 0xFE0F )); then
      if (( last == 1 )); then
        (( max > 0 && CUT < 0 && w + 1 > max )) && CUT=$lastpos
        w=$(( w + 1 )); last=2
      fi
      i=$(( i + len )); continue
    fi
    if (( cp < 32 || (cp >= 0x7F && cp < 0xA0) || (cp >= 0x300 && cp <= 0x36F) ||
          (cp >= 0x200B && cp <= 0x200F) || (cp >= 0xFE00 && cp <= 0xFE0E) )); then
      cw=0
    elif (( (cp >= 0x1100 && cp <= 0x115F) || cp == 0x231A || cp == 0x231B ||
            (cp >= 0x23E9 && cp <= 0x23EC) || cp == 0x23F0 || cp == 0x23F3 ||
            (cp >= 0x25FD && cp <= 0x25FE) || (cp >= 0x2614 && cp <= 0x2615) ||
            (cp >= 0x2648 && cp <= 0x2653) || cp == 0x267F || cp == 0x2693 ||
            cp == 0x26A1 || (cp >= 0x26AA && cp <= 0x26AB) ||
            (cp >= 0x26BD && cp <= 0x26BE) || (cp >= 0x26C4 && cp <= 0x26C5) ||
            cp == 0x26CE || cp == 0x26D4 || cp == 0x26EA ||
            (cp >= 0x26F2 && cp <= 0x26F3) || cp == 0x26F5 || cp == 0x26FA ||
            cp == 0x26FD || cp == 0x2705 || (cp >= 0x270A && cp <= 0x270B) ||
            cp == 0x2728 || cp == 0x274C || cp == 0x274E ||
            (cp >= 0x2753 && cp <= 0x2755) || cp == 0x2757 ||
            (cp >= 0x2795 && cp <= 0x2797) || cp == 0x27B0 || cp == 0x27BF ||
            (cp >= 0x2B1B && cp <= 0x2B1C) || cp == 0x2B50 || cp == 0x2B55 ||
            (cp >= 0x2E80 && cp <= 0x303E) || (cp >= 0x3041 && cp <= 0xA4CF) ||
            (cp >= 0xA960 && cp <= 0xA97F) || (cp >= 0xAC00 && cp <= 0xD7A3) ||
            (cp >= 0xF900 && cp <= 0xFAFF) || (cp >= 0xFE10 && cp <= 0xFE19) ||
            (cp >= 0xFE30 && cp <= 0xFE6F) || (cp >= 0xFF00 && cp <= 0xFF60) ||
            (cp >= 0xFFE0 && cp <= 0xFFE6) || (cp >= 0x1F000 && cp <= 0x1FAFF) ||
            (cp >= 0x20000 && cp <= 0x3FFFD) )); then
      cw=2
    else
      cw=1
    fi
    (( max > 0 && CUT < 0 && w + cw > max )) && CUT=$i
    w=$(( w + cw )); last=$cw; lastpos=$i; i=$(( i + len ))
  done
  DW=$w
}

# Segments of the line being built: joiner (printed before the segment when
# a segment precedes it), body and drop rank (0 = always shown, otherwise
# the highest rank is dropped first). Empty bodies are skipped.
seg_reset() { SEG_J=(); SEG_B=(); SEG_R=(); }
seg_add() { [ -n "$3" ] && { SEG_J+=("$2"); SEG_B+=("$3"); SEG_R+=("$1"); }; return 0; }

# Joins the segments into LINE, fitting it into BUDGET when one is set
fit_line() {
  local n=${#SEG_B[@]} i top drop total=0 first
  local -a W JW
  LINE=""
  if [ -n "$BUDGET" ]; then
    for (( i = 0; i < n; i++ )); do
      str_width "${SEG_B[i]}"; W[i]=$DW
      str_width "${SEG_J[i]}"; JW[i]=$DW
    done
    while :; do
      total=0; first=1
      for (( i = 0; i < n; i++ )); do
        (( SEG_R[i] < 0 )) && continue
        (( first )) || total=$(( total + JW[i] ))
        total=$(( total + W[i] )); first=0
      done
      (( total <= BUDGET )) && break
      drop=-1; top=0
      for (( i = 0; i < n; i++ )); do
        (( SEG_R[i] > top )) && { top=${SEG_R[i]}; drop=$i; }
      done
      (( drop < 0 )) && break
      SEG_R[drop]=-1
    done
  fi
  first=1
  for (( i = 0; i < n; i++ )); do
    (( SEG_R[i] < 0 )) && continue
    (( first )) || LINE+="${SEG_J[i]}"
    LINE+="${SEG_B[i]}"; first=0
  done
  if [ -n "$BUDGET" ] && (( total > BUDGET )); then
    str_width "$LINE" $(( BUDGET - 1 ))
    if (( CUT >= 0 )); then
      LINE="${LINE:0:CUT}${RST}"
      [[ "$LINE" == *$'\033]8;;'* ]] && LINE+=$'\033]8;;\a'
      LINE+="…"
    fi
  fi
}

# Drop ranks, per line: settings and identifiers go before live numbers.
# Line 1: 👤 User · 📌 Session | 🤖 Model 🚀 | ⚡ Effort | 💰 Cost
seg_reset
seg_add 0 "" "${BLD}${CYN}👤 ${USER_NAME}${RST}"
seg_add 3 " ${DIM}·${RST} " "$SESSION_STR"
seg_add 0 " ${DIM}|${RST} " "${BLD}🤖${RST} ${MODEL}"
seg_add 1 " " "$FAST_STR"
seg_add 2 " ${DIM}|${RST} " "$EFFORT_STR"
seg_add 0 " ${DIM}|${RST} " "${BLD}💰${RST} ${MAG}\$${COST_FMT}${RST}"
fit_line; LINE1=$LINE

# Line 2: 🌿 Branch 🌲 +added -removed | 🔀 PR | 📦 used / total (%)
seg_reset
seg_add 0 "" "${BLD}${GRN}🌿 ${BRANCH}${RST}"
[ -n "$WORKTREE" ] && seg_add 3 " " "🌲"
seg_add 1 " " "$LINES_STR"
seg_add 2 " ${DIM}|${RST} " "$PR_STR"
seg_add 0 " ${DIM}|${RST} " "${CTX_CLR}📦 ${USED_FMT} / ${TOTAL_FMT} (${PCT}%)${RST}"
fit_line; LINE2=$LINE

# Line 3: ⏱️ 5h bar % reset | 7d bar % reset — hidden when no rate limit data
LINE3=""
if [ -n "$RL_5H_SEG" ] || [ -n "$RL_7D_SEG" ]; then
  RL_5H_CORE="${RL_5H_SEG%" ${GRY}reset "*}"
  RL_7D_CORE="${RL_7D_SEG%" ${GRY}reset "*}"
  seg_reset
  if [ -n "$RL_5H_SEG" ]; then
    seg_add 0 "" "${BLD}⏱️${RST} ${RL_5H_CORE}"
    seg_add 2 "" "${RL_5H_SEG#"$RL_5H_CORE"}"
    seg_add 1 " ${DIM}|${RST} " "$RL_7D_CORE"
  else
    seg_add 0 "" "${BLD}⏱️${RST} ${RL_7D_CORE}"
  fi
  seg_add 3 "" "${RL_7D_SEG#"$RL_7D_CORE"}"
  fit_line; LINE3=$LINE
fi

# Line 4: 📁 repo | ⏳ elapsed | 📥 cache · new | ♻️ prompt cache | 💭 thinking
# — hidden when empty
seg_reset
[ -n "$REPO_STR" ] && seg_add 4 "" "${BLD}📁${RST} ${CYN}${REPO_STR}${RST}"
[ -n "$DUR_STR" ] && seg_add 3 " ${DIM}|${RST} " "${BLD}⏳${RST} ${DUR_STR}"
[ -n "$CTX_DETAIL_STR" ] && seg_add 2 " ${DIM}|${RST} " "${BLD}📥${RST} ${CTX_DETAIL_STR}"
[ -n "$PC_STR" ] && seg_add 1 " ${DIM}|${RST} " "${BLD}♻️${RST} ${PC_STR}"
[ "$THINKING" = "true" ] && seg_add 5 " ${DIM}|${RST} " "${BLD}💭${RST} ${GRY}thinking${RST}"
fit_line; LINE4=$LINE

# ══════════════════════════════════════════════════════════════════════
# OUTPUT: up to 4 lines
# ══════════════════════════════════════════════════════════════════════
echo "${LINE1}"

OUT="${LINE2}"
[ -n "$LINE3" ] && OUT+=$'\n'"${LINE3}"
[ -n "$LINE4" ] && OUT+=$'\n'"${LINE4}"

echo -n "${OUT}"
