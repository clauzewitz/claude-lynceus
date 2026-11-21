---
name: setup-statusline
description: >
  Helps set up the always-visible session status bar. Use when the user wants
  to install, configure, or troubleshoot the claude-lynceus statusline.
disable-model-invocation: true
---

# Setup Session Status Statusline

This skill installs the claude-lynceus statusline so it always appears at the
bottom of the Claude Code terminal.

## What it displays

Up to four lines. Segments without data are hidden, and a line with nothing
to show is hidden entirely.

- **Line 1**: 👤 user (`CLAUDE_USER_NICK` → git user.name → whoami),
  📌 session name, 🤖 model with 🚀 fast mode, ⚡ effort level,
  🎭 agent name (with `--agent`), 💰 session cost
- **Line 2**: 🌿 git branch with 🌲 worktree marker and name, +/- lines changed,
  🔀 open PR / GitLab MR with review state, 📦 context tokens used / window (%)
- **Line 3**: ⏱️ 5-hour and 7-day rate limits with reset times
- **Line 4**: 📁 owner/repo, ⏳ session elapsed time,
  📥 context breakdown (cache reads · new input),
  ♻️ prompt cache (warm time left or cold, hit ratio, misses), 💭 extended thinking

On narrow terminals (Claude Code passes the width in `COLUMNS`), each line
hides its optional segments, settings and identifiers first, so it fits.

## Installation Steps

1. Copy the statusline script to `~/.claude/`:

```bash
# Find the plugin's script location and copy it
PLUGIN_DIR=$(find ~/.claude/plugins -name "claude-lynceus" -type d 2>/dev/null | head -1)
if [ -n "$PLUGIN_DIR" ]; then
  cp "$PLUGIN_DIR/scripts/statusline.sh" ~/.claude/lynceus-statusline.sh
else
  echo "Plugin directory not found. Please provide the plugin path."
fi
chmod +x ~/.claude/lynceus-statusline.sh
```

2. Add the statusline configuration to `~/.claude/settings.json`:

Use `jq` to merge safely:
```bash
SETTINGS_FILE=~/.claude/settings.json
if [ -f "$SETTINGS_FILE" ]; then
  jq '. + {"statusLine": {"type": "command", "command": "~/.claude/lynceus-statusline.sh", "padding": 1, "refreshInterval": 10}}' \
    "$SETTINGS_FILE" > /tmp/claude-settings-tmp.json && \
    mv /tmp/claude-settings-tmp.json "$SETTINGS_FILE"
else
  echo '{"statusLine": {"type": "command", "command": "~/.claude/lynceus-statusline.sh", "padding": 1, "refreshInterval": 10}}' \
    > "$SETTINGS_FILE"
fi
```

3. Verify `jq` is installed (required dependency).

4. Restart Claude Code to apply changes.

## Troubleshooting

- **Statusline not showing**: Check that `~/.claude/settings.json` has the
  `statusLine` field and restart Claude Code.
- **Blank output**: Ensure `jq` is installed (`which jq`).
- **Stale git info**: The script caches git data for 5 seconds. Wait a moment
  after switching branches.
- **To remove**: Delete the `statusLine` field from `~/.claude/settings.json`
  and restart Claude Code.
