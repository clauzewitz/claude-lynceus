---
description: Install the claude-lynceus statusline to always display at the bottom of your terminal
---

# Install Session Status Statusline

Follow these steps to install the claude-lynceus statusline:

## Step 1: Copy the statusline script

Copy the `statusline.sh` script from this plugin's `scripts/` directory to the
user's Claude config directory:

```bash
cp <plugin-path>/scripts/statusline.sh ~/.claude/lynceus-statusline.sh
chmod +x ~/.claude/lynceus-statusline.sh
```

Replace `<plugin-path>` with the actual path where this plugin is located.
If you're running via `--plugin-dir`, use that path.

## Step 2: Update settings.json

Read `~/.claude/settings.json`, add or update the `statusLine` field, and write
the file back. The configuration should look like:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/lynceus-statusline.sh",
    "padding": 1,
    "refreshInterval": 10
  }
}
```

Be careful to **merge** with existing settings — do not overwrite the entire file.

## Step 3: Verify jq is installed

The script requires `jq` for JSON parsing. Check if it's available:

```bash
which jq
```

If not installed, inform the user with the appropriate install command:
- macOS: `brew install jq`
- Ubuntu/Debian: `sudo apt-get install jq`
- Arch: `sudo pacman -S jq`

## Step 4: Confirm

Tell the user:
- The statusline has been installed.
- They need to **restart Claude Code** for changes to take effect.
- After restart, the status bar will appear at the bottom of the terminal.
