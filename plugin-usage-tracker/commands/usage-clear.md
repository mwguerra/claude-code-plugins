---
description: Clear usage tracking history and optionally reset configuration
allowed-tools: Bash(bun:*), Bash(rm:*)
argument-hint: [--all] [--keep-config] [--before=DATE]
---

# Clear Usage History

Clear your Claude Code usage tracking history.

## Options:
- `--all` - Clear all data including configuration
- `--keep-config` - Clear logs but preserve configuration (default)
- `--before=DATE` - Clear sessions before a specific date (YYYY-MM-DD format)

## Warning:
This action is irreversible. Your usage history will be permanently deleted.

## Examples:
- `/usage-clear` - Clear all logs, keep configuration
- `/usage-clear --all` - Clear everything and reset to defaults
- `/usage-clear --before=2024-01-01` - Clear sessions before January 1, 2024

## To clear all tracking data:

Before proceeding, please confirm you want to clear your usage history by asking me to run the appropriate command.

### Reset the log file (keeps config):
```bash
echo '{"version":"1.0.0","created_at":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","updated_at":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","sessions":[],"aggregate_stats":{"total_sessions":0,"total_events":0,"total_tool_calls":0,"total_time_tracked_ms":0,"tool_usage_counts":{},"tool_time_spent":{},"project_usage":{},"daily_activity":{}}}' > ~/.claude/.plugin-history/usage-log.json
```

### Delete everything:
```bash
rm -rf ~/.claude/.plugin-history
```

After clearing, run `/usage-init` to reinitialize tracking.
