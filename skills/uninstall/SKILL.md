---
description: Remove the claude-lynceus statusline and clean up configuration
---

Run the uninstall script to remove the claude-lynceus statusline:

```bash
bash <plugin-path>/scripts/uninstall.sh
```

Replace `<plugin-path>` with the actual plugin directory path.

This will:
1. Delete `~/.claude/lynceus-statusline.sh` (and older names: `session-statusline.sh`, `claude-lynceusline.sh`)
2. Remove the `statusLine` entry from `~/.claude/settings.json`
3. Clean up any cache files

After running, restart Claude Code for changes to take effect.
