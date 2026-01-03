---
description: Browse and search your Claude Code activity logs
allowed-tools: Read, Bash(bun:*), Bash(cat:*), Bash(jq:*)
argument-hint: [--session=ID] [--last=N] [--tool=NAME] [--json]
---

# Browse Usage Logs

Browse your Claude Code activity logs to understand your workflow patterns.

## Options:
- `--session=ID` - View a specific session by ID
- `--last=N` - Show the last N sessions (default: 5)
- `--tool=NAME` - Filter events by tool name
- `--json` - Output in JSON format

## What's logged:
- Session start/end times
- Tool usage with timing information
- User prompts (length only, not content for privacy)
- Subagent activity
- Error occurrences

## Log file location:
`~/.claude/.plugin-history/usage-log.json`

## Quick commands:

### View the raw log file:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '.'
```

### View last 5 sessions:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '.sessions[-5:]'
```

### Count events by type:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '[.sessions[].events[].event_type] | group_by(.) | map({type: .[0], count: length})'
```

### Find slowest tool calls:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '[.sessions[].events[] | select(.duration_ms != null)] | sort_by(-.duration_ms) | .[0:10] | .[] | {tool: .tool_name, duration_ms: .duration_ms, timestamp: .timestamp}'
```

After browsing the logs, I can help you identify patterns or troubleshoot issues.
