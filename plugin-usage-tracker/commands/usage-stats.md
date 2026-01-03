---
description: View usage statistics and analytics for your Claude Code workflow
allowed-tools: Bash(bun:*)
argument-hint: [--json] [--days=N]
---

# Usage Statistics

View comprehensive statistics about your Claude Code usage, including:
- Total sessions, events, and tool calls
- Top tools by usage count and time spent
- Project-level usage breakdown
- Daily activity trends

## Options:
- `--json` - Output in JSON format for programmatic use
- `--days=N` - Analyze the last N days (default: 30)

## Examples:
- `/usage-stats` - Show statistics for the last 30 days
- `/usage-stats --days=7` - Show statistics for the last week
- `/usage-stats --json` - Get raw JSON data for analysis

Please run the statistics script:

```bash
bun run ${CLAUDE_PLUGIN_ROOT}/scripts/show-stats.ts $ARGUMENTS
```

After viewing the statistics, I can help you analyze patterns or identify areas for optimization.
