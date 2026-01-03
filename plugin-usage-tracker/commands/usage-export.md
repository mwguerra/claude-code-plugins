---
description: Export usage data for external analysis or backup
allowed-tools: Bash(bun:*), Bash(cp:*), Bash(jq:*)
argument-hint: [--format=FORMAT] [--output=PATH] [--days=N]
---

# Export Usage Data

Export your Claude Code usage data for external analysis, backup, or reporting.

## Options:
- `--format=FORMAT` - Output format: json (default), csv, markdown
- `--output=PATH` - Save to specific path (default: current directory)
- `--days=N` - Export only the last N days of data

## Examples:
- `/usage-export` - Export all data as JSON to current directory
- `/usage-export --format=csv --days=30` - Export last 30 days as CSV
- `/usage-export --output=~/reports/usage.json` - Export to specific location

## Export commands:

### Full JSON export:
```bash
cp ~/.claude/.plugin-history/usage-log.json ./claude-usage-export-$(date +%Y%m%d).json
```

### Pretty-printed JSON:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '.' > ./claude-usage-export-$(date +%Y%m%d).json
```

### Summary report (JSON):
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '{
  total_sessions: .aggregate_stats.total_sessions,
  total_tool_calls: .aggregate_stats.total_tool_calls,
  total_time_hours: (.aggregate_stats.total_time_tracked_ms / 3600000),
  top_tools: (.aggregate_stats.tool_usage_counts | to_entries | sort_by(-.value) | .[0:5] | from_entries)
}' > ./claude-usage-summary-$(date +%Y%m%d).json
```

### CSV export (tool usage):
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq -r '
  .aggregate_stats.tool_usage_counts | to_entries | 
  ["tool","count"], (.[] | [.key, .value]) | @csv
' > ./tool-usage-$(date +%Y%m%d).csv
```

After exporting, I can help you analyze the data or create visualizations.
