# My Workflow Plugin

> Your personal digital assistant and executive secretary for Claude Code

**Version:** 1.0.0
**Author:** Marcelo Guerra

## Overview

My Workflow is a comprehensive personal workflow management system that transforms Claude Code into your intelligent assistant, secretary, and executive support system. It automatically captures every decision, commitment, and idea from your work sessions, maintains context across projects, and provides intelligent briefings to keep you focused and productive.

### Key Features

- **Automatic Context Capture** - Decisions, commitments, ideas, and commits are extracted automatically
- **Intelligent Briefings** - Start each session with a personalized briefing of what matters now
- **Obsidian Integration** - All data synced to your vault as beautiful markdown notes
- **GitHub Integration** - See your issues, PRs, and review requests in briefings
- **Daily Planning** - Automatic daily notes with todo lists and work summaries
- **Progress Tracking** - Goals, commitments, and productivity patterns at a glance
- **Multi-language Support** - Detects decisions/commitments in English, Portuguese, and Spanish

## Quick Start

### Installation

1. Copy the `my-workflow` folder to your Claude Code plugins directory:
   ```bash
   cp -r my-workflow ~/.claude/plugins/
   ```

2. Initialize the database:
   ```bash
   /workflow:init
   ```

3. (Optional) Configure Obsidian vault:
   ```bash
   /workflow:init --vault-path /path/to/your/vault
   ```

### Basic Usage

- Start any Claude Code session and receive an automatic briefing
- Work normally - decisions, ideas, and commitments are captured automatically
- Use `/workflow:status` to see your dashboard
- Use `/workflow:track` to manage commitments
- End session to generate summary and sync to vault

## Commands

| Command | Description |
|---------|-------------|
| `/workflow:status` | Display comprehensive workflow dashboard |
| `/workflow:briefing` | Generate intelligent session briefing |
| `/workflow:track` | Manage commitments (add, complete, defer, edit, delete) |
| `/workflow:review` | Generate weekly/monthly productivity reviews |
| `/workflow:goals` | Manage goals and milestones |
| `/workflow:patterns` | View detected behavior patterns |
| `/workflow:sync` | Sync with external changes and Obsidian |
| `/workflow:init` | Initialize database and configuration |

## How It Works

### Session Lifecycle

```
┌─────────────────┐
│  Session Start  │ ──► Briefing with pending work, GitHub items, daily planner
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Your Work     │ ──► Automatic capture of decisions, ideas, commitments, commits
│  (Conversation) │     using AI + pattern matching
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Session End    │ ──► AI-generated summary, vault sync, daily note update
└─────────────────┘
```

### What Gets Captured

| Type | Detection | Examples |
|------|-----------|----------|
| **Decisions** | "decided to", "we'll go with", "the approach is" | Architecture choices, technology selections |
| **Commitments** | "I need to", "TODO:", "don't forget" | Action items, promises, tasks |
| **Ideas** | "what if", "we could", "might be worth" | Suggestions, explorations, improvements |
| **Commits** | Git commit detection | All commits with context |

### Obsidian Vault Structure

```
your-vault/
└── workflow/
    ├── daily/          # Daily notes (YYYY-MM-DD.md)
    ├── sessions/       # Session summaries
    ├── commits/        # Commit logs with context
    ├── decisions/      # Decision records with rationale
    ├── commitments/    # Commitment tracking
    ├── goals/          # Goal progress notes
    ├── ideas/          # Idea exploration
    ├── reviews/        # Weekly/monthly reviews
    └── patterns/       # Pattern observations
```

## Configuration

Configuration file: `~/.claude/my-workflow.json`

```json
{
  "github": {
    "username": "your-username",
    "trackIssues": true,
    "trackPRs": true,
    "trackReviews": true,
    "cacheMinutes": 15
  },
  "briefing": {
    "showOnStart": true,
    "includeGitHub": true,
    "includePendingCommitments": true,
    "includeRecentDecisions": true,
    "includeGoalProgress": true,
    "daysBack": 7
  },
  "logging": {
    "captureCommits": true,
    "captureDecisions": true,
    "captureCommitments": true,
    "captureIdeas": true
  },
  "vault": {
    "enabled": true,
    "syncOnSessionEnd": true,
    "workflowFolder": "workflow",
    "smartFilenames": true
  },
  "ai": {
    "enabled": true,
    "model": "haiku",
    "maxBudget": "0.50"
  }
}
```

## Database

SQLite database at `~/.claude/my-workflow/workflow.db` with tables:

- `sessions` - Claude Code session records
- `commitments` - Promises and action items
- `decisions` - Architectural/process decisions
- `goals` - Objectives, milestones, habits
- `ideas` - Ideas and suggestions
- `daily_notes` - Daily summaries and planning
- `activity_timeline` - Unified activity log
- `patterns` - Detected behavior patterns
- `knowledge_nodes` / `knowledge_edges` - Knowledge graph
- `github_cache` - Cached GitHub data
- `external_changes` - Changes detected outside Claude
- `personal_notes` - Free-form notes
- `state` - Plugin state

## Hooks

The plugin uses Claude Code hooks to capture events:

| Event | Script | Purpose |
|-------|--------|---------|
| SessionStart | `session-briefing.sh` | Generate briefing, create session |
| UserPromptSubmit | `capture-user-input.sh` | Analyze user input for items |
| PostToolUse (Bash) | Multiple scripts | Capture commits, decisions, ideas |
| PostToolUse (Edit/Write) | Multiple scripts | Extract items from changes |
| SubagentStop | `capture-agent-result.sh` | Capture agent results |
| Stop | `capture-session-summary.sh` | Generate session summary |

## Agents

| Agent | Role |
|-------|------|
| `workflow-assistant` | Context-aware intelligent assistant |
| `workflow-secretary` | Administrative and scheduling support |
| `workflow-executive` | Strategic analysis and recommendations |

## Tips for Best Results

1. **Be explicit about decisions** - Saying "I decided to use X because Y" captures better than implicit choices
2. **Use conventional commits** - `feat:`, `fix:`, etc. are parsed for better commit categorization
3. **Check your briefing** - The morning briefing surfaces what needs attention
4. **Review weekly** - Use `/workflow:review weekly` to see patterns and progress
5. **Keep commitments small** - Smaller, specific commitments are easier to track

## Troubleshooting

### Database not initialized
Run `/workflow:init` to create the database.

### Vault not syncing
Check that `vault.enabled` is `true` and the path in `~/.claude/obsidian-vault.json` is correct.

### GitHub items not showing
Ensure `gh` CLI is installed and authenticated, and `github.username` is set.

### Items not being captured
Check `~/.claude/my-workflow/debug.log` for errors. Ensure AI extraction is enabled.

## Architecture

```
my-workflow/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── hooks/
│   ├── hooks.json           # Hook event mappings
│   └── scripts/             # Hook handler scripts
│       ├── hook-utils.sh    # Shared utilities
│       ├── db-helper.sh     # Database abstraction
│       ├── ai-extractor.sh  # AI-powered extraction
│       └── capture-*.sh     # Event handlers
├── commands/                # Slash commands
├── agents/                  # Agent definitions
├── skills/                  # Reusable skills
├── schemas/
│   ├── schema.sql           # Database schema
│   ├── config.schema.json   # Config validation
│   └── migrations/          # Schema migrations
├── config/
│   └── my-workflow.example.json
└── docs/
    └── plans/               # Design documents
```

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions welcome! Please read the design documents in `docs/plans/` before making significant changes.
