#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# claude-lynceus v3.4 LITE — no jq required (uses Python 3)
#
# Line 1: 👤 User · 📌 Session | 🤖 Model 🚀 | ⚡ Effort | 🧠 Context | 💰 Cost
# Line 2: 🌿 Branch | +added -removed | 🔀 PR | 📦 used / total (%)
# Line 3: ⏱️ 5h bar % reset | 7d bar % reset
# ══════════════════════════════════════════════════════════════════════

input=$(cat)

# ── Colors ────────────────────────────────────────────────────────────
RST=$'\033[0m'; BLD=$'\033[1m'; DIM=$'\033[2m'
RED=$'\033[91m'; GRN=$'\033[38;5;108m'; YLW=$'\033[33m'
BLU=$'\033[34m'; CYN=$'\033[36m'; MAG=$'\033[35m'; GRY=$'\033[90m'

# ── Parse JSON with Python ────────────────────────────────────────────
# Values are shell-quoted so free-form fields (session name, PR url) can't
# break out of the eval below. Displayed strings have control characters
# stripped so they can't inject terminal escape sequences. Fields that are
# null or absent (used_percentage early in a session, for example) fall back
# one by one instead of failing the whole parse.
eval "$(python3 -c "
import json, sys, shlex, re
from datetime import datetime

CTRL = re.compile(r'[\x00-\x1f\x7f-\x9f]')

def q(v):
    return shlex.quote(str(v))

def s(v):
    return '' if v is None else CTRL.sub('', str(v))

def num(v):
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return v
    return 0

def obj(v):
    return v if isinstance(v, dict) else {}

def reset_str(ts, with_date):
    if ts in (None, '', 'null'):
        return ''
    try:
        dt = datetime.fromtimestamp(int(ts))
    except (TypeError, ValueError):
        try:
            dt = datetime.fromisoformat(str(ts).replace('Z', '+00:00'))
        except ValueError:
            return ''
    if with_date:
        return f'{dt.month}/{dt.day} {dt:%H:%M}'
    return f'{dt:%H:%M}'

try:
    d = json.loads(sys.stdin.read())
    cw = obj(d.get('context_window'))
    c = obj(d.get('cost'))
    rl = obj(d.get('rate_limits'))
    rl5 = obj(rl.get('five_hour'))
    rl7 = obj(rl.get('seven_day'))
    pr = obj(d.get('pr'))
    model = obj(d.get('model')).get('display_name')
    print(f'MODEL={q(\"—\" if model is None else s(model))}')
    print(f'PCT={int(num(cw.get(\"used_percentage\")))}')
    print(f'TOTAL={int(num(cw.get(\"context_window_size\")))}')
    # used_percentage counts input tokens only, so the count matches it
    print(f'USED={int(num(cw.get(\"total_input_tokens\")))}')
    print(f'COST={num(c.get(\"total_cost_usd\"))}')
    print(f'LINES_ADD={int(num(c.get(\"total_lines_added\")))}')
    print(f'LINES_DEL={int(num(c.get(\"total_lines_removed\")))}')
    print(f'CWD={q(obj(d.get(\"workspace\")).get(\"current_dir\") or \"\")}')
    print(f'SESSION_ID={q(s(d.get(\"session_id\")))}')
    print(f'SESSION_NAME={q(s(d.get(\"session_name\")))}')
    print(f'RL_5H_PCT={int(num(rl5.get(\"used_percentage\")))}')
    print(f'RL_5H_RESET_STR={q(reset_str(rl5.get(\"resets_at\"), False))}')
    print(f'RL_7D_PCT={int(num(rl7.get(\"used_percentage\")))}')
    print(f'RL_7D_RESET_STR={q(reset_str(rl7.get(\"resets_at\"), True))}')
    print(f'EFFORT={q(s(obj(d.get(\"effort\")).get(\"level\")))}')
    print(f'FAST_MODE={\"true\" if d.get(\"fast_mode\") is True else \"false\"}')
    print(f'PR_NUM={q(s(pr.get(\"number\")))}')
    print(f'PR_URL={q(s(pr.get(\"url\")))}')
    print(f'PR_STATE={q(s(pr.get(\"review_state\")))}')
    print(f'PR_KIND={q(s(pr.get(\"kind\")))}')
except Exception:
    print('MODEL=\"—\"; PCT=0; TOTAL=0; USED=0; COST=0; LINES_ADD=0; LINES_DEL=0')
    print('CWD=\"\"; SESSION_ID=\"\"; SESSION_NAME=\"\"; EFFORT=\"\"; FAST_MODE=\"false\"')
    print('RL_5H_PCT=0; RL_5H_RESET_STR=\"\"; RL_7D_PCT=0; RL_7D_RESET_STR=\"\"')
    print('PR_NUM=\"\"; PR_URL=\"\"; PR_STATE=\"\"; PR_KIND=\"\"')
" <<< "$input")"

COST_FMT=$(printf '%.2f' "$COST" 2>/dev/null || echo "0.00")

# ── Format numbers ────────────────────────────────────────────────────
fmt() { echo "$1" | rev | sed 's/[0-9]\{3\}/&,/g' | rev | sed 's/^,//'; }
USED_FMT=$(fmt "$USED"); TOTAL_FMT=$(fmt "$TOTAL")

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

# ── User name (hybrid) ───────────────────────────────────────────────
if [ -n "$CLAUDE_USER_NICK" ]; then
  USER_NAME="$CLAUDE_USER_NICK"; USER_SRC="env"
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
  [ "$USER_SRC" = "git" ] && USER_NAME=$(sed -n '1p' "$CACHE_FILE")
  BRANCH=$(sed -n '2p' "$CACHE_FILE")
fi

# ── Colors by percentage ──────────────────────────────────────────────
ctx_color() { [ "$1" -lt 50 ] && echo "$GRN" || { [ "$1" -lt 80 ] && echo "$YLW" || echo "$RED"; }; }
CTX_CLR=$(ctx_color "$PCT")

# ── Rate limit segments ───────────────────────────────────────────────
make_bar() {
  local pct=$1 bar="" f=$((pct * 10 / 100)) e
  e=$((10 - f))
  for ((i=0;i<f;i++)); do bar+="█"; done
  for ((i=0;i<e;i++)); do bar+="░"; done
  echo "$bar"
}

rl_segment() {
  local label=$1 pct=$2 reset_str=$3
  if [ "$pct" -le 0 ] 2>/dev/null && [ -z "$reset_str" ]; then
    echo ""
    return
  fi
  local clr=$(ctx_color "$pct")
  local seg="${GRY}${label}${RST} ${clr}$(make_bar "$pct") ${pct}%${RST}"
  [ -n "$reset_str" ] && seg+=" ${GRY}reset ${reset_str}${RST}"
  echo "$seg"
}

RL_5H_SEG=$(rl_segment "5h" "$RL_5H_PCT" "$RL_5H_RESET_STR")
RL_7D_SEG=$(rl_segment "7d" "$RL_7D_PCT" "$RL_7D_RESET_STR")

# ── Lines changed ─────────────────────────────────────────────────────
LINES_STR=""
if [ "$LINES_ADD" -gt 0 ] 2>/dev/null || [ "$LINES_DEL" -gt 0 ] 2>/dev/null; then
  LINES_STR=" ${GRN}+${LINES_ADD}${RST} ${RED}-${LINES_DEL}${RST}"
fi

# ── Session name segment ─────────────────────────────────────────────
SESSION_STR=""
if [ -n "$SESSION_NAME" ]; then
  SESSION_STR=" ${DIM}·${RST} ${BLD}📌${RST} ${BLU}${SESSION_NAME}${RST}"
fi

# ── Fast mode badge ──────────────────────────────────────────────────
FAST_STR=""
[ "$FAST_MODE" = "true" ] && FAST_STR=" 🚀"

# ── Effort segment ───────────────────────────────────────────────────
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

# ── PR segment (OSC 8 hyperlink when a URL is available) ─────────────
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

# ── Output ────────────────────────────────────────────────────────────
LINE1="${BLD}${CYN}👤 ${USER_NAME}${RST}${SESSION_STR} ${DIM}|${RST} ${BLD}🤖${RST} ${MODEL}${FAST_STR}${EFFORT_STR} ${DIM}|${RST} ${BLD}🧠${RST} ${CTX_CLR}${PCT}%${RST} ${DIM}|${RST} ${BLD}💰${RST} ${MAG}\$${COST_FMT}${RST}"
LINE2="${BLD}${GRN}🌿 ${BRANCH}${RST}${LINES_STR}${PR_STR} ${DIM}|${RST} ${CTX_CLR}📦 ${USED_FMT} / ${TOTAL_FMT} (${PCT}%)${RST}"

echo "${LINE1}"

if [ -n "$RL_5H_SEG" ] || [ -n "$RL_7D_SEG" ]; then
  echo "${LINE2}"
  LINE3="${BLD}⏱️${RST} "
  if [ -n "$RL_5H_SEG" ]; then
    LINE3+="$RL_5H_SEG"
    [ -n "$RL_7D_SEG" ] && LINE3+=" ${DIM}|${RST} $RL_7D_SEG"
  else
    LINE3+="$RL_7D_SEG"
  fi
  echo -n "${LINE3}"
else
  echo -n "${LINE2}"
fi
