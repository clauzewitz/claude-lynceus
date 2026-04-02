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

- 👤 **User**: The git username or system username
- 🌿 **Branch**: Current git branch (or "git 미연결" if not in a repo)
- 📦 **Context**: Token usage / total with percentage and progress bar

## Installation Steps

1. Copy the statusline script to `~/.claude/`:

```bash
# Find the plugin's script location and copy it
PLUGIN_DIR=$(find ~/.claude/plugins -name "claude-lynceus" -type d 2>/dev/null | head -1)
if [ -n "$PLUGIN_DIR" ]; then
  cp "$PLUGIN_DIR/scripts/statusline.sh" ~/.claude/claude-lynceusline.sh
else
  echo "Plugin directory not found. Please provide the plugin path."
fi
chmod +x ~/.claude/claude-lynceusline.sh
```

2. Add the statusline configuration to `~/.claude/settings.json`:

Use `jq` to merge safely:
```bash
SETTINGS_FILE=~/.claude/settings.json
if [ -f "$SETTINGS_FILE" ]; then
  jq '. + {"statusLine": {"type": "command", "command": "~/.claude/claude-lynceusline.sh", "padding": 1}}' \
    "$SETTINGS_FILE" > /tmp/claude-settings-tmp.json && \
    mv /tmp/claude-settings-tmp.json "$SETTINGS_FILE"
else
  echo '{"statusLine": {"type": "command", "command": "~/.claude/claude-lynceusline.sh", "padding": 1}}' \
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
