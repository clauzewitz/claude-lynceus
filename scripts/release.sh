#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# claude-lynceus — release automation
#
# Usage:
#   bash scripts/release.sh <version>
#   bash scripts/release.sh 3.4.0
#   bash scripts/release.sh patch     # 3.3.0 → 3.3.1
#   bash scripts/release.sh minor     # 3.3.0 → 3.4.0
#   bash scripts/release.sh major     # 3.3.0 → 4.0.0
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GRN=$'\033[0;32m'
YLW=$'\033[0;33m'
CYN=$'\033[0;36m'
BLD=$'\033[1m'
RST=$'\033[0m'

info()  { printf "${CYN}ℹ${RST}  %s\n" "$1"; }
ok()    { printf "${GRN}✔${RST}  %s\n" "$1"; }
warn()  { printf "${YLW}⚠${RST}  %s\n" "$1"; }
fail()  { printf "${RED}✖${RST}  %s\n" "$1"; exit 1; }

# ── Resolve paths ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
CHANGELOG="$PLUGIN_ROOT/CHANGELOG.md"

cd "$PLUGIN_ROOT"

# ── Check prerequisites ──────────────────────────────────────────────
command -v jq &>/dev/null || fail "jq가 필요합니다 (brew install jq)"
command -v git &>/dev/null || fail "git이 필요합니다"
git rev-parse --is-inside-work-tree &>/dev/null || fail "git 저장소가 아닙니다"

# ── Get current version ──────────────────────────────────────────────
CURRENT=$(jq -r '.version' "$PLUGIN_JSON")
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

echo ""
printf "${BLD}📊 Claude Lynceus — Release${RST}\n"
echo "────────────────────────────────────────────"
echo "   현재 버전: v${CURRENT}"
echo ""

# ── Determine new version ─────────────────────────────────────────────
if [ -z "${1:-}" ]; then
  fail "사용법: bash scripts/release.sh <version|patch|minor|major>"
fi

case "$1" in
  patch) NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
  minor) NEW_VERSION="${MAJOR}.$((MINOR + 1)).0" ;;
  major) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
  *)
    # Validate semver format
    if [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      fail "올바른 버전 형식이 아닙니다: $1 (예: 3.4.0 또는 patch/minor/major)"
    fi
    NEW_VERSION="$1"
    ;;
esac

info "새 버전: v${NEW_VERSION}"

# ── Check for uncommitted changes ─────────────────────────────────────
if [ -n "$(git status --porcelain)" ]; then
  warn "커밋되지 않은 변경사항이 있습니다"
  git status --short
  echo ""
  printf "   계속하시겠습니까? (y/N) "
  read -r CONFIRM
  [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ] || exit 0
fi

# ── Check CHANGELOG has [Unreleased] entries ──────────────────────────
if ! grep -q "## \[Unreleased\]" "$CHANGELOG"; then
  fail "CHANGELOG.md에 [Unreleased] 섹션이 없습니다"
fi

UNRELEASED_CONTENT=$(sed -n '/## \[Unreleased\]/,/## \[/p' "$CHANGELOG" | sed '1d;$d')

if [ -z "$(echo "$UNRELEASED_CONTENT" | grep -v '^$')" ]; then
  warn "CHANGELOG.md의 [Unreleased] 섹션이 비어 있습니다"
  printf "   그래도 계속하시겠습니까? (y/N) "
  read -r CONFIRM
  [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ] || exit 0
fi

# ── Check tag doesn't already exist ───────────────────────────────────
if git tag -l "v${NEW_VERSION}" | grep -q "v${NEW_VERSION}"; then
  fail "태그 v${NEW_VERSION}이 이미 존재합니다"
fi

# ── Step 1: Update plugin.json ────────────────────────────────────────
info "plugin.json 버전 업데이트..."
jq --arg v "$NEW_VERSION" '.version = $v' "$PLUGIN_JSON" > "${PLUGIN_JSON}.tmp" && \
  mv "${PLUGIN_JSON}.tmp" "$PLUGIN_JSON"
ok "plugin.json → v${NEW_VERSION}"

# ── Step 2: Update CHANGELOG.md ───────────────────────────────────────
info "CHANGELOG.md 업데이트..."
TODAY=$(date '+%Y-%m-%d')

# Replace [Unreleased] header with new version + add new [Unreleased]
sed -i.bak "s/## \[Unreleased\]/## [Unreleased]\n\n## [${NEW_VERSION}] - ${TODAY}/" "$CHANGELOG"
rm -f "${CHANGELOG}.bak"

# Update comparison links at bottom
# origin → https://github.com/<owner>/<repo>. SSH remotes may use a host alias
# from ~/.ssh/config (git@my-github-alias:owner/repo), so any git@<host>: form
# maps to github.com; credentials in an https remote are dropped.
to_https_url() {
  echo "$1" | sed -E \
    -e 's#\.git$##' \
    -e 's#^https://[^@/]*@#https://#' \
    -e 's#^git@[^:]+:#https://github.com/#'
}
REPO_URL=$(to_https_url "$(git remote get-url origin 2>/dev/null)")
if [ -n "$REPO_URL" ]; then
  # Update [Unreleased] link
  sed -i.bak "s|\[Unreleased\]:.*|[Unreleased]: ${REPO_URL}/compare/v${NEW_VERSION}...HEAD|" "$CHANGELOG"
  # Add new version link (before the first version link)
  sed -i.bak "/^\[Unreleased\]:/a\\
[${NEW_VERSION}]: ${REPO_URL}/compare/v${CURRENT}...v${NEW_VERSION}" "$CHANGELOG"
  rm -f "${CHANGELOG}.bak"
fi

ok "CHANGELOG.md → v${NEW_VERSION} (${TODAY})"

# ── Step 3: Git commit ────────────────────────────────────────────────
info "변경사항 커밋..."
git add "$PLUGIN_JSON" "$CHANGELOG"
git commit -m "release: v${NEW_VERSION}" --quiet
ok "커밋 완료: release: v${NEW_VERSION}"

# ── Step 4: Git tag ───────────────────────────────────────────────────
info "태그 생성..."
TAG_MSG="claude-lynceus v${NEW_VERSION}"
git tag -a "v${NEW_VERSION}" -m "$TAG_MSG"
ok "태그 완료: v${NEW_VERSION}"

# ── Step 5: Push ──────────────────────────────────────────────────────
echo ""
printf "   원격에 push하시겠습니까? (y/N) "
read -r PUSH_CONFIRM
if [ "$PUSH_CONFIRM" = "y" ] || [ "$PUSH_CONFIRM" = "Y" ]; then
  info "push 중..."
  git push && git push --tags
  ok "push 완료"
else
  info "push는 건너뜁니다. 나중에 직접 실행하세요:"
  echo "   git push && git push --tags"
fi

# ── Done ──────────────────────────────────────────────────────────────
echo ""
printf "${BLD}────────────────────────────────────────────${RST}\n"
ok "${BLD}v${NEW_VERSION} 릴리즈 완료!${RST}"
echo ""
echo "   릴리즈 요약:"
echo "   ├ plugin.json  → v${NEW_VERSION}"
echo "   ├ CHANGELOG.md → v${NEW_VERSION} (${TODAY})"
echo "   ├ git commit   → release: v${NEW_VERSION}"
echo "   └ git tag      → v${NEW_VERSION}"
echo ""
