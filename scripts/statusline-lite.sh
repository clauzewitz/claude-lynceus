#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# claude-lynceus v3.4 LITE — no jq required (uses Python 3), up to 4 lines
#
# Line 1: 👤 User · 📌 Session | 🤖 Model 🚀 | ⚡ Effort | 💰 Cost
# Line 2: 🌿 Branch 🌲 | +added -removed | 🔀 PR | 📦 used / total (%)
# Line 3: ⏱️ 5h bar % reset | 7d bar % reset
# Line 4: 📁 owner/repo | ⏳ elapsed | 📥 cache · new | ♻️ prompt cache | 💭 thinking
# With COLUMNS set, lines that are too wide drop optional segments to fit.
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
    ws = obj(d.get('workspace'))
    repo = obj(ws.get('repo'))
    print(f'REPO_OWNER={q(s(repo.get(\"owner\")))}')
    print(f'REPO_NAME={q(s(repo.get(\"name\")))}')
    # linked git worktree, else the name of the --worktree session
    wt = ws.get('git_worktree')
    if wt in (None, False):
        wt = obj(d.get('worktree')).get('name')
    print(f'WORKTREE={q(\"\" if wt in (None, False) else s(wt))}')
    print(f'DURATION_S={int(num(c.get(\"total_duration_ms\")) // 1000)}')
    cu = obj(cw.get('current_usage'))
    print(f'CACHE_READ={int(num(cu.get(\"cache_read_input_tokens\")))}')
    print(f'NEW_INPUT={int(num(cu.get(\"input_tokens\"))) + int(num(cu.get(\"cache_creation_input_tokens\")))}')
    print(f'THINKING={\"true\" if obj(d.get(\"thinking\")).get(\"enabled\") is True else \"false\"}')
    pc = obj(d.get('prompt_cache'))
    print(f'PC_ON={\"true\" if pc.get(\"caching_observed\") is True else \"false\"}')
    print(f'PC_WARM={\"true\" if pc.get(\"warm\") is True else \"false\"}')
    print(f'PC_EXPIRES={int(num(pc.get(\"expires_at\")))}')
    hr = pc.get('hit_ratio')
    print(f'PC_HIT={int(num(hr) * 100 + 0.5) if num(hr) == hr else -1}')
    print(f'PC_MISSES={int(num(pc.get(\"misses\")))}')
except Exception:
    print('MODEL=\"—\"; PCT=0; TOTAL=0; USED=0; COST=0; LINES_ADD=0; LINES_DEL=0')
    print('CWD=\"\"; SESSION_ID=\"\"; SESSION_NAME=\"\"; EFFORT=\"\"; FAST_MODE=\"false\"')
    print('RL_5H_PCT=0; RL_5H_RESET_STR=\"\"; RL_7D_PCT=0; RL_7D_RESET_STR=\"\"')
    print('PR_NUM=\"\"; PR_URL=\"\"; PR_STATE=\"\"; PR_KIND=\"\"')
    print('REPO_OWNER=\"\"; REPO_NAME=\"\"; WORKTREE=\"\"; DURATION_S=0; CACHE_READ=0; NEW_INPUT=0; THINKING=\"false\"')
    print('PC_ON=\"false\"; PC_WARM=\"false\"; PC_EXPIRES=0; PC_HIT=-1; PC_MISSES=0')
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
  LINES_STR="${GRN}+${LINES_ADD}${RST} ${RED}-${LINES_DEL}${RST}"
fi

# ── Session name segment ─────────────────────────────────────────────
SESSION_STR=""
if [ -n "$SESSION_NAME" ]; then
  SESSION_STR="${BLD}📌${RST} ${BLU}${SESSION_NAME}${RST}"
fi

# ── Fast mode badge ──────────────────────────────────────────────────
FAST_STR=""
[ "$FAST_MODE" = "true" ] && FAST_STR="🚀"

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
