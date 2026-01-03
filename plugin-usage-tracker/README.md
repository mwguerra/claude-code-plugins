# Plugin Usage Tracker

A comprehensive Claude Code plugin that logs and analyzes your workflow to help you understand and optimize your usage patterns.

## Features

- 📊 **Automatic Usage Tracking**: Logs all tool usage, sessions, and events
- ⏱️ **Performance Metrics**: Tracks processing time for each tool call
- 📈 **Statistics Dashboard**: View aggregated usage statistics
- 🔍 **Workflow Analysis**: Identify bottlenecks and optimization opportunities
- 📁 **Project Insights**: Compare usage across different projects
- 🤖 **AI-Powered Analysis**: Built-in agent for intelligent workflow recommendations

## Installation

### From a Marketplace

```bash
/plugin install plugin-usage-tracker@mwguerra-marketplace
```

### Manual Installation

1. Clone or download this plugin to your plugins directory
2. Add the marketplace containing this plugin:
   ```bash
   /plugin marketplace add /path/to/marketplace
   ```
3. Install the plugin:
   ```bash
   /plugin install plugin-usage-tracker
   ```

## Quick Start

1. **Initialize the tracker**:
   ```
   /usage-init
   ```

2. **View your statistics**:
   ```
   /usage-stats
   ```

3. **Get AI-powered insights**:
   ```
   Use the usage-analyzer agent to analyze my workflow
   ```

## Commands

| Command | Description |
|---------|-------------|
| `/usage-init` | Initialize the tracking system |
| `/usage-stats` | View usage statistics |
| `/usage-logs` | Browse activity logs |
| `/usage-clear` | Clear tracking history |
| `/usage-export` | Export data for external analysis |

## What Gets Tracked

### Session Information
- Session ID and timestamps
- Project directory
- Permission mode
- Total duration

### Tool Usage
- Tool name and type
- Input summary (sanitized)
- Output summary
- Duration in milliseconds
- Success/failure status

### Events
- PreToolUse / PostToolUse
- UserPromptSubmit
- SessionStart / SessionEnd
- Stop / SubagentStop

### Aggregate Statistics
- Total sessions, events, tool calls
- Tool usage counts and time spent
- Project-level usage breakdown
- Daily activity trends

## Data Storage

All data is stored locally at:
```
~/.claude/.plugin-history/
├── usage-log.json      # Main log file
├── pending-events.json # Temporary tracking file
├── config.json         # Configuration
└── usage-log-schema.json # JSON schema
```

## Privacy

- **User prompts are NOT logged** - only the length is recorded
- **File contents are NOT logged** - only file paths and content lengths
- **Commands are truncated** to 200 characters
- All data stays on your local machine

## Analysis Examples

### View top tools by usage
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '.aggregate_stats.tool_usage_counts | to_entries | sort_by(-.value) | .[0:10]'
```

### Find slowest operations
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '[.sessions[].events[] | select(.duration_ms != null)] | sort_by(-.duration_ms) | .[0:5]'
```

### Get daily summary
```bash
cat ~/.claude/.plugin-history/usage-log.json | jq '.aggregate_stats.daily_activity'
```

## Configuration

Edit `~/.claude/.plugin-history/config.json`:

```json
{
  "tracking_enabled": true,
  "log_user_prompts": true,
  "log_tool_inputs": true,
  "log_tool_outputs": true,
  "max_sessions_to_keep": 100,
  "auto_cleanup_enabled": true
}
```

## Schema

The usage log follows a strict JSON schema. See `schemas/usage-log-schema.json` for the complete specification.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - See LICENSE file for details.
