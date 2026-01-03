---
name: usage-analysis
description: Analyze Claude Code usage logs to identify patterns, bottlenecks, and optimization opportunities. Use when the user asks about their workflow efficiency, tool usage patterns, or wants to improve their Claude Code experience.
allowed-tools: Read, Bash, Grep
---

# Usage Analysis Skill

This skill enables analysis of Claude Code usage data to provide workflow insights.

## Data Location
Usage logs are stored at: `~/.claude/.plugin-history/usage-log.json`

## Log Structure

The log contains:
- **version**: Schema version (currently "1.0.0")
- **sessions**: Array of session objects
- **aggregate_stats**: Overall statistics

### Session Object
```json
{
  "session_id": "uuid",
  "project_dir": "/path/to/project",
  "started_at": "ISO timestamp",
  "ended_at": "ISO timestamp or null",
  "total_duration_ms": number,
  "events": [...],
  "session_stats": {...}
}
```

### Event Object
```json
{
  "event_id": "uuid",
  "event_type": "PreToolUse|PostToolUse|UserPromptSubmit|etc",
  "timestamp": "ISO timestamp",
  "tool_name": "string or null",
  "duration_ms": "number or null",
  "input_summary": {...},
  "output_summary": {...}
}
```

## Useful jq Queries

### Top tools by usage count:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '.aggregate_stats.tool_usage_counts | to_entries | sort_by(-.value) | .[0:10]'
```

### Top tools by time spent:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '.aggregate_stats.tool_time_spent | to_entries | sort_by(-.value) | .[0:10]'
```

### Average duration per tool:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '
  .aggregate_stats as $stats |
  $stats.tool_usage_counts | to_entries | map(
    .key as $tool |
    {tool: $tool, avg_ms: (($stats.tool_time_spent[$tool] // 0) / .value)}
  ) | sort_by(-.avg_ms)
'
```

### Sessions per project:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '.aggregate_stats.project_usage | to_entries | sort_by(-.value.sessions)'
```

### Daily activity trend:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '.aggregate_stats.daily_activity | to_entries | sort_by(.key) | .[-14:]'
```

### Error rate by tool:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '
  [.sessions[].events[] | select(.event_type == "PostToolUse")] |
  group_by(.tool_name) |
  map({
    tool: .[0].tool_name,
    total: length,
    errors: [.[] | select(.output_summary.success == false)] | length
  }) |
  map(. + {error_rate: (if .total > 0 then (.errors / .total * 100 | round) else 0 end)}) |
  sort_by(-.error_rate)
'
```

### Slowest individual tool calls:
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '
  [.sessions[].events[] | select(.duration_ms != null)] |
  sort_by(-.duration_ms) |
  .[0:10] |
  .[] | {tool: .tool_name, duration_ms: .duration_ms, timestamp: .timestamp}
'
```

## Analysis Guidelines

When analyzing usage:

1. **Identify Patterns**: Look for recurring tool usage patterns
2. **Find Bottlenecks**: Identify tools with high time consumption
3. **Detect Anomalies**: Look for unusual spikes or error rates
4. **Compare Across Projects**: See if certain projects require more effort
5. **Track Trends**: Analyze how usage changes over time

## Recommendations Framework

Based on analysis, provide recommendations in these categories:

1. **Efficiency**: Tools that could be combined or optimized
2. **Learning**: Areas where the user might benefit from new techniques
3. **Automation**: Repetitive patterns that could be automated
4. **Time Management**: Insights about productive hours and session lengths
