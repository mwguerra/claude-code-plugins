# My Workflow Plugin - Technical Documentation

> Complete technical reference for the my-workflow plugin

**Version:** 1.0.0
**Author:** Marcelo Guerra
**Last Updated:** 2026-01-29

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Hook System](#hook-system)
4. [Scripts Reference](#scripts-reference)
5. [AI Integration](#ai-integration)
6. [File Operations & Retry Logic](#file-operations--retry-logic)
7. [Database Schema](#database-schema)
8. [Vault Synchronization](#vault-synchronization)
9. [Configuration Reference](#configuration-reference)
10. [Testing Guide](#testing-guide)

---

## Overview

My Workflow is a comprehensive personal workflow management system that transforms Claude Code into an intelligent digital assistant, secretary, and executive support system. It automatically captures decisions, commitments, ideas, and work context from every Claude Code session.

### Core Principles

1. **Non-blocking**: All hooks are designed to never block the Claude Code workflow
2. **Graceful degradation**: If AI fails, fall back to pattern matching; if pattern matching fails, log and continue
3. **Concurrent-safe**: File operations use retry logic to handle multiple Claude instances
4. **Privacy-first**: All data stays local (database + vault), with optional GitHub backup

### What Gets Captured

| Item Type | Detection Method | Storage |
|-----------|-----------------|---------|
| **Decisions** | AI extraction + pattern matching | SQLite + Vault |
| **Commitments** | AI extraction + pattern matching | SQLite + Vault |
| **Ideas** | AI extraction + pattern matching | SQLite + Vault |
| **Git Commits** | Bash command analysis | SQLite + Vault |
| **Session Summaries** | AI-generated on session end | SQLite + Vault |
| **Claude Responses** | Haiku classification | Session notes |

---

## Architecture

```
my-workflow/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata (version, author, keywords)
│
├── hooks/
│   ├── hooks.json               # Hook event → script mappings
│   └── scripts/                 # Shell scripts (6,000+ lines total)
│       ├── hook-utils.sh        # Core utilities (1,500+ lines)
│       ├── db-helper.sh         # Database abstraction layer
│       ├── ai-extractor.sh      # AI-powered extraction
│       ├── ai-analyzer.sh       # AI analysis utilities
│       ├── session-briefing.sh  # Session start handler
│       ├── capture-user-input.sh
│       ├── capture-commit.sh
│       ├── capture-decision.sh
│       ├── capture-idea.sh
│       ├── capture-commitment.sh
│       ├── capture-agent-result.sh
│       ├── capture-claude-response.sh
│       ├── capture-session-summary.sh
│       ├── vault-git-sync.sh
│       ├── detect-external-changes.sh
│       └── diagnostic-hook.sh
│
├── commands/                    # Slash commands (8 commands)
│   ├── briefing.md
│   ├── goals.md
│   ├── init.md
│   ├── patterns.md
│   ├── review.md
│   ├── status.md
│   ├── sync.md
│   └── track.md
│
├── agents/                      # Agent definitions
│   ├── workflow-assistant.md
│   ├── workflow-secretary.md
│   └── workflow-executive.md
│
├── skills/                      # Reusable skills
│   ├── knowledge-graph/SKILL.md
│   ├── workflow-assistant/SKILL.md
│   ├── workflow-executive/SKILL.md
│   └── workflow-secretary/SKILL.md
│
├── schemas/
│   ├── schema.sql               # Main SQLite schema
│   ├── config.schema.json       # Configuration validation
│   ├── default-config.json      # Default values
│   └── migrations/              # Schema migrations
│
├── config/
│   └── my-workflow.example.json # Example configuration
│
└── docs/
    ├── TECHNICAL_DOCUMENTATION.md  # This file
    └── plans/                      # Design documents
```

---

## Hook System

### Event Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           SESSION LIFECYCLE                               │
└──────────────────────────────────────────────────────────────────────────┘

  SessionStart
       │
       ├─► vault-git-sync.sh (60s) ─── Pull latest vault changes
       │
       └─► session-briefing.sh (30s) ─── Create session, show briefing
                │
                ├── Cleanup orphaned sessions
                ├── Create session record
                ├── Query pending commitments
                ├── Query recent decisions
                ├── Query active goals
                ├── Fetch GitHub items (cached)
                ├── Create/update daily vault note
                └── Output formatted briefing

  UserPromptSubmit
       │
       └─► capture-user-input.sh (30s) ─── Analyze user message
                │
                ├── Pattern-based detection (fast path)
                │   ├── Decision patterns (EN/PT-BR/ES)
                │   ├── Idea patterns (EN/PT-BR/ES)
                │   └── Commitment patterns (EN/PT-BR/ES)
                │
                └── AI fallback (if no pattern match)
                    └── Haiku analysis for classification

  PostToolUse (Bash)
       │
       ├─► capture-commit.sh (15s) ─── Detect git commits
       ├─► capture-commitment.sh (10s)
       ├─► capture-decision.sh (10s)
       └─► capture-idea.sh (10s)

  PostToolUse (Edit/Write)
       │
       ├─► capture-commitment.sh (10s)
       ├─► capture-decision.sh (10s)
       └─► capture-idea.sh (10s)

  PostToolUse (Task)
       │
       ├─► capture-decision.sh (10s)
       └─► capture-idea.sh (10s)

  SubagentStop
       │
       ├─► capture-agent-result.sh (15s) ─── Extract agent outcomes
       ├─► capture-commitment.sh (10s)
       ├─► capture-decision.sh (10s)
       └─► capture-idea.sh (10s)

  Stop / SessionEnd
       │
       ├─► capture-claude-response.sh (20s) ─── Classify & save summaries
       │        │
       │        └── Uses Haiku to determine if response is worth saving
       │
       ├─► capture-session-summary.sh (60s) ─── Generate session summary
       │        │
       │        ├── Calculate duration
       │        ├── Gather commits made during session
       │        ├── Get captured Claude summaries
       │        ├── Generate AI summary (Sonnet)
       │        ├── Create session vault note
       │        └── Update daily note with session link
       │
       └─► vault-git-sync.sh (60s) ─── Commit and push vault changes
```

### Hook Configuration (hooks.json)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/vault-git-sync.sh session_start", "timeout": 60},
          {"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/session-briefing.sh", "timeout": 30}
        ]
      }
    ],
    "UserPromptSubmit": [...],
    "PostToolUse": [
      {"matcher": "Bash", "hooks": [...]},
      {"matcher": "Edit", "hooks": [...]},
      {"matcher": "Write", "hooks": [...]},
      {"matcher": "Task", "hooks": [...]}
    ],
    "SubagentStop": [...],
    "Stop": [...],
    "SessionEnd": [...]
  }
}
```

---

## Scripts Reference

### Core Infrastructure

#### `hook-utils.sh` (1,535 lines)

The foundation of all hook scripts. Provides:

| Category | Functions |
|----------|-----------|
| **Platform** | `detect_os()`, `OS_TYPE` variable |
| **Config** | `get_config()`, `is_enabled()` |
| **Database** | `ensure_db()`, `db_query()`, `db_exec()`, `get_next_id()` |
| **Sessions** | `generate_session_id()`, `get_current_session_id()`, `set_current_session()` |
| **Vault** | `get_vault_path()`, `check_vault()`, `get_workflow_folder()` |
| **Frontmatter** | `create_vault_frontmatter()`, `wiki_link()`, `sanitize_tag()` |
| **Related Notes** | `find_related_notes()`, `get_todays_session_links()`, `get_recent_commit_links()` |
| **Git** | `get_project_name()`, `get_git_branch()`, `get_latest_commit()` |
| **Date/Time** | `get_date()`, `get_datetime()`, `get_iso_timestamp()`, `date_to_epoch()`, `days_ago_date()` |
| **Strings** | `slugify()`, `sql_escape()`, `json_escape()` |
| **Env** | `get_tool_input()`, `get_tool_output()`, `get_stop_summary()`, `get_user_prompt()` |
| **Logging** | `debug_log()`, `activity_log()` |
| **Daily Notes** | `ensure_daily_note()`, `update_daily_note_*()`, `get_previous_day_summary()`, `get_today_planner()` |
| **Vault Sync** | `vault_log_activity()`, `create_daily_vault_template()`, `append_to_section()` |
| **Cleanup** | `is_claude_running_for_directory()`, `cleanup_orphaned_sessions()` |
| **File Retry** | `safe_write_file()`, `safe_append_file()`, `safe_read_file()`, `create_vault_note_safe()`, `safe_db_exec()` |
| **Session Notes** | `get_session_note_path()`, `append_to_session_note()`, `update_daily_session_link()` |

#### `db-helper.sh` (488 lines)

Database abstraction layer with typed functions:

| Category | Functions |
|----------|-----------|
| **Core** | `db_exec()`, `db_query_json()`, `db_query_plain()`, `db_escape()`, `db_get_next_id()` |
| **Sessions** | `db_create_session()`, `db_close_session()`, `db_get_current_session_id()`, `db_get_session()`, `db_get_active_sessions()` |
| **Decisions** | `db_insert_decision()`, `db_get_decision()`, `db_update_decision_vault_path()`, `db_get_today_decisions()` |
| **Ideas** | `db_insert_idea()`, `db_get_idea()`, `db_update_idea_vault_path()`, `db_get_today_ideas()` |
| **Commitments** | `db_insert_commitment()`, `db_get_commitment()`, `db_update_commitment_vault_path()`, `db_get_pending_commitments()` |
| **Duplicates** | `db_check_duplicate()` |
| **Activity** | `db_log_activity()` |
| **Daily Notes** | `db_ensure_daily_note()`, `db_add_daily_decision()`, `db_add_daily_idea()`, `db_update_daily_session()` |
| **State** | `db_get_state()`, `db_set_state()` |

#### `ai-extractor.sh` (755 lines)

AI-powered extraction and filename generation:

| Function | Purpose | Model |
|----------|---------|-------|
| `extractor_ai_enabled()` | Check if AI is available | - |
| `extractor_get_method()` | Get AI method (cli/api/none) | - |
| `ai_extract_all_items()` | Extract decisions/ideas/commitments | Haiku |
| `pattern_extract_all_items()` | Fallback pattern matching | - |
| `smart_extract_all_items()` | AI with pattern fallback | Haiku |
| `ai_generate_filename()` | Generate descriptive filename | Haiku |
| `smart_filename()` | Filename with optional AI | Haiku |
| `get_commit_link()` | Generate GitHub commit link | - |
| `ai_classify_response()` | Classify if response worth saving | Haiku |
| `ai_generate_session_summary()` | Generate session summary | Sonnet |

### Capture Scripts

#### `capture-decision.sh` (211 lines)

Extracts architectural and process decisions from tool output.

**Flow:**
1. Check if decisions enabled
2. Get tool output from `CLAUDE_TOOL_OUTPUT`
3. Call `smart_extract_all_items()` for AI/pattern extraction
4. For each decision:
   - Validate title length (>15 chars)
   - Check for duplicates (1-hour window)
   - Validate category (architecture/technology/process/design/general)
   - Insert into database
   - Log activity
   - Update daily note
   - Create vault note (with retry logic)

#### `capture-idea.sh` (190 lines)

Extracts ideas, suggestions, and explorations.

**Flow:**
1. Check if ideas enabled
2. Get tool output
3. Call `smart_extract_all_items()`
4. For each idea:
   - Validate title length (>15 chars)
   - Check for duplicates (30-minute window)
   - Validate type (feature/improvement/exploration/refactor/question)
   - Insert into database
   - Log activity
   - Update daily note
   - Create vault note

#### `capture-commitment.sh` (210 lines)

Extracts action items, promises, and tasks.

**Flow:**
1. Check if commitments enabled
2. Get tool output
3. Call `smart_extract_all_items()`
4. For each commitment:
   - Validate title length (>10 chars)
   - Check for duplicates (1-hour window)
   - Validate priority (high/medium/low)
   - Validate due_type (immediate/soon/later/unspecified)
   - Insert into database
   - Log activity
   - Create vault note

#### `capture-commit.sh` (181 lines)

Detects and logs git commits.

**Triggers:** Only when `git commit` command detected in tool input.

**Captured data:**
- Commit hash (full and short)
- Commit message and body
- Author and date
- Files changed
- Conventional commit type (feat/fix/docs/etc.)

#### `capture-user-input.sh` (468 lines)

Analyzes user prompts for extractable items.

**Multi-language patterns:**
```bash
# English
"let's use", "I decided", "we should use", "I need to", "what if"

# Portuguese BR
"vamos usar", "decidi", "escolhi", "preciso", "e se"

# Spanish
"vamos a usar", "decidí", "elegí", "necesito", "qué tal si"
```

**Flow:**
1. Pattern-based detection (fast path)
2. If no pattern match, use AI analysis (Haiku)
3. Create appropriate record type

#### `capture-session-summary.sh` (336 lines)

Generates comprehensive session summary on Stop/SessionEnd.

**Uses Sonnet** for generating session summaries with:
- Key accomplishments
- Technical decisions
- Problems solved
- Next steps

#### `capture-claude-response.sh` (149 lines)

Classifies Claude responses and saves worthy summaries.

**Classification criteria (via Haiku):**
- Reports completed work ✓
- Explains technical decisions ✓
- Provides analysis ✓
- Lists outcomes/results ✓
- Simple acknowledgments ✗
- Questions back to user ✗

#### `capture-agent-result.sh` (179 lines)

Captures decisions and ideas from subagent work.

---

## AI Integration

### Model Selection

| Task | Model | Budget | Timeout |
|------|-------|--------|---------|
| Item extraction | Haiku | $0.50 | 20s |
| Response classification | Haiku | $0.10 | 15s |
| Filename generation | Haiku | $0.10 | 30s |
| Session summary | Sonnet | $0.50 | 45s |

### Authentication Priority

1. **Claude CLI** (preferred) - Uses logged-in account
2. **ANTHROPIC_API_KEY** - Fallback for API calls

### Multi-language Detection

The AI prompt explicitly handles:
- **English**: "decided to", "we'll go with", "I need to"
- **Portuguese BR**: "decidi", "vamos usar", "preciso"
- **Spanish**: "decidí", "vamos a usar", "necesito"

### Fallback Chain

```
AI Extraction
     │
     ▼ (if fails)
Pattern Matching
     │
     ▼ (if no match)
Silent Skip (never blocks)
```

---

## File Operations & Retry Logic

### The Problem

Multiple Claude instances may write to the same files simultaneously, especially:
- Daily notes in vault
- Session notes
- Database files

### Solution: Retry with Random Delay

All file operations use these safe functions from `hook-utils.sh`:

#### `safe_write_file(filepath, content, max_retries=2)`

```bash
safe_write_file() {
    local filepath="$1"
    local content="$2"
    local max_retries="${3:-2}"
    local attempt=0

    while [[ $attempt -le $max_retries ]]; do
        if echo "$content" > "$filepath" 2>/dev/null; then
            return 0
        fi
        attempt=$((attempt + 1))
        if [[ $attempt -le $max_retries ]]; then
            debug_log "File write failed, attempt $attempt, waiting..."
            random_delay 3 8  # Wait 3-8 seconds randomly
        fi
    done
    debug_log "ERROR: Failed to write after $((max_retries + 1)) attempts"
    return 1
}
```

#### `safe_append_file(filepath, content, max_retries=2)`

Same logic but appends instead of overwrites.

#### `safe_read_file(filepath, max_retries=2)`

Retries file reads with random delay.

#### `create_vault_note_safe(filepath)`

Reads content from stdin and writes with retry logic:

```bash
create_vault_note_safe() {
    local filepath="$1"
    local content
    content=$(cat)  # Read from stdin
    local max_retries=2
    local attempt=0

    mkdir -p "$(dirname "$filepath")" 2>/dev/null

    while [[ $attempt -le $max_retries ]]; do
        if echo "$content" > "$filepath" 2>/dev/null; then
            return 0
        fi
        attempt=$((attempt + 1))
        if [[ $attempt -le $max_retries ]]; then
            random_delay 3 8
        fi
    done
    return 1
}
```

#### `safe_db_exec(sql, max_retries=2)`

Retries database operations.

### Random Delay Function

```bash
random_delay() {
    local min="${1:-3}"
    local max="${2:-8}"
    local range=$((max - min + 1))
    local delay=$((RANDOM % range + min))
    sleep "$delay"
}
```

### Usage in Capture Scripts

All vault note creation uses the pipe pattern:

```bash
{
    create_vault_frontmatter "Title" "Description" "tags" "related" "extra"
    echo ""
    echo "# Title"
    echo ""
    echo "Content..."
} | create_vault_note_safe "$FILE_PATH"
```

---

## Database Schema

### Location

`~/.claude/my-workflow/workflow.db` (SQLite)

### Tables Overview

| Table | Records | Purpose |
|-------|---------|---------|
| `sessions` | Claude Code sessions | Session tracking with duration, commits, summary |
| `commitments` | C-XXXX | Action items with priority, due dates, status |
| `decisions` | D-XXXX | Architectural choices with rationale |
| `goals` | G-XXXX | Objectives, milestones, habits with progress |
| `ideas` | I-XXXX | Suggestions and explorations |
| `patterns` | P-XXXX | Detected behavioral patterns |
| `knowledge_nodes` | N-XXXX | Knowledge graph entities |
| `knowledge_edges` | E-XXXX | Entity relationships |
| `daily_notes` | date | Daily summaries and planning |
| `personal_notes` | PN-XXXX | Free-form notes |
| `activity_timeline` | auto | Unified activity log |
| `external_changes` | X-XXXX | Changes outside Claude |
| `github_cache` | type | Cached GitHub data |
| `state` | singleton | Plugin state |
| `schema_version` | version | Schema tracking |
| `knowledge_nodes_fts` | virtual | Full-text search |

### Key Relationships

```
sessions ─────┬──► commitments (source_session_id)
              ├──► decisions (source_session_id)
              ├──► ideas (source_session_id)
              └──► activity_timeline (session_id)

goals ────────┬──► goals (parent_goal_id) [hierarchical]
              └──► knowledge_edges (via entity relationships)

daily_notes ──┬──► new_decisions (JSON array of D-XXXX)
              ├──► new_ideas (JSON array of I-XXXX)
              ├──► completed_commitments (JSON array of C-XXXX)
              └──► projects_worked (JSON object)

knowledge_nodes ◄─── knowledge_edges ───► knowledge_nodes
```

---

## Vault Synchronization

### Obsidian Vault Structure

```
vault/
└── workflow/
    ├── daily/
    │   └── 2026-01-29.md           # Daily note
    ├── sessions/
    │   └── 2026-01-29-1430-project-name.md
    ├── commits/
    │   └── 2026-01-29-add-feature.md
    ├── decisions/
    │   └── 2026-01-29-use-sonnet-for-summaries.md
    ├── commitments/
    │   └── C-0001.md
    ├── ideas/
    │   └── I-0001-explore-caching.md
    ├── goals/
    │   └── G-0001-ship-v1.md
    ├── reviews/
    │   └── 2026-W04-weekly-review.md
    └── patterns/
        └── P-0001-late-night-coding.md
```

### Frontmatter Format

All vault notes use consistent frontmatter:

```yaml
---
title: "Decision: Use Sonnet for Session Summaries"
description: "AI model selection for session analysis"
tags:
  - "decision"
  - "my-workflow"
  - "technology"
related:
  - "[[workflow/sessions/2026-01-29-session]]"
created: 2026-01-29
updated: 2026-01-29
decision_id: "D-0042"
category: "technology"
project: "my-workflow"
status: active
---
```

### Git Sync

The `vault-git-sync.sh` script:

1. **On SessionStart:**
   - Initialize git repo if needed
   - Create `.gitignore` for Obsidian
   - Create private GitHub repo if not exists
   - Pull latest changes

2. **On SessionEnd:**
   - Stage all changes
   - Commit with message "Session end: {project} at {timestamp}"
   - Push to GitHub

---

## Configuration Reference

### File Location

`~/.claude/my-workflow.json`

### Full Schema

```json
{
  "github": {
    "username": "your-github-username",
    "trackRepos": ["*"],
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
    "includePatterns": false,
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
    "maxTokens": 500,
    "timeout": 15,
    "maxBudgetUsd": 0.01,
    "fallbackOnly": false
  },
  "patterns": {
    "enabled": true,
    "minConfidence": 0.6,
    "minEvidence": 3
  }
}
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `CLAUDE_PLUGIN_ROOT` | Plugin installation path |
| `CLAUDE_TOOL_INPUT` | Input to the current tool |
| `CLAUDE_TOOL_OUTPUT` | Output from the current tool |
| `CLAUDE_STOP_SUMMARY` | Claude's final response |
| `CLAUDE_USER_PROMPT` | User's message (UserPromptSubmit) |
| `ANTHROPIC_API_KEY` | API key for direct API calls |
| `WORKFLOW_DEBUG` | Set to "true" for debug logging |
| `WORKFLOW_AI_MODEL` | Override AI model (haiku/sonnet) |

---

## Testing Guide

### Manual Testing

#### Test Session Briefing

```bash
# Enable debug logging
export WORKFLOW_DEBUG=true

# Run briefing script directly
bash ~/.claude/plugins/my-workflow/hooks/scripts/session-briefing.sh
```

#### Test Item Extraction

```bash
# Test decision extraction
export CLAUDE_TOOL_OUTPUT="I decided to use Sonnet for session summaries because it provides better analysis than Haiku."
bash ~/.claude/plugins/my-workflow/hooks/scripts/capture-decision.sh

# Check the database
sqlite3 ~/.claude/my-workflow/workflow.db "SELECT * FROM decisions ORDER BY created_at DESC LIMIT 5"
```

#### Test Complex Multi-item Extraction

```bash
export CLAUDE_TOOL_OUTPUT="
After careful analysis, I decided to use TypeScript for the frontend because it provides better type safety.
We should also consider implementing a caching layer - what if we used Redis?
I need to remember to update the documentation before the release.
Another idea: we could add real-time notifications using WebSockets.
TODO: Fix the login bug that was reported yesterday.
"
bash ~/.claude/plugins/my-workflow/hooks/scripts/capture-decision.sh
bash ~/.claude/plugins/my-workflow/hooks/scripts/capture-idea.sh
bash ~/.claude/plugins/my-workflow/hooks/scripts/capture-commitment.sh
```

#### Test Portuguese/Spanish Detection

```bash
export CLAUDE_TOOL_OUTPUT="
Decidi usar o React para o frontend porque é mais popular.
Preciso lembrar de atualizar os testes.
E se usássemos GraphQL em vez de REST?
"
bash ~/.claude/plugins/my-workflow/hooks/scripts/capture-user-input.sh
```

#### Test Vault Note Creation (with retry)

```bash
# Simulate concurrent writes
for i in {1..5}; do
    (
        export CLAUDE_TOOL_OUTPUT="Decision $i: Use approach $i for testing concurrent writes"
        bash ~/.claude/plugins/my-workflow/hooks/scripts/capture-decision.sh
    ) &
done
wait
```

#### Test Session Summary (Sonnet)

```bash
export CLAUDE_STOP_SUMMARY="
## Summary

Today I completed the following:

- Implemented the user authentication system using JWT tokens
- Fixed the bug in the login flow that was causing timeout errors
- Refactored the database queries for better performance
- Added comprehensive tests for the auth module

### Technical Decisions
- Chose JWT over session-based auth for scalability
- Implemented refresh token rotation for security

### Next Steps
- Need to add rate limiting to the auth endpoints
- Should implement password reset functionality
"
bash ~/.claude/plugins/my-workflow/hooks/scripts/capture-session-summary.sh
```

### Checking Logs

```bash
# View debug log
tail -f ~/.claude/my-workflow/debug.log

# View recent activities
sqlite3 ~/.claude/my-workflow/workflow.db "
SELECT timestamp, activity_type, title
FROM activity_timeline
ORDER BY timestamp DESC
LIMIT 20
"
```

### Database Verification

```bash
# Count all items
sqlite3 ~/.claude/my-workflow/workflow.db "
SELECT
    (SELECT COUNT(*) FROM sessions) as sessions,
    (SELECT COUNT(*) FROM decisions) as decisions,
    (SELECT COUNT(*) FROM ideas) as ideas,
    (SELECT COUNT(*) FROM commitments) as commitments,
    (SELECT COUNT(*) FROM daily_notes) as daily_notes
"

# Check today's items
sqlite3 ~/.claude/my-workflow/workflow.db "
SELECT 'Decisions:', COUNT(*) FROM decisions WHERE date(created_at) = date('now')
UNION ALL
SELECT 'Ideas:', COUNT(*) FROM ideas WHERE date(created_at) = date('now')
UNION ALL
SELECT 'Commitments:', COUNT(*) FROM commitments WHERE date(created_at) = date('now')
"
```

### Vault Verification

```bash
# Check vault structure
ls -la ~/path/to/vault/workflow/

# Check recent vault notes
find ~/path/to/vault/workflow -name "*.md" -mtime -1 | head -20

# Verify frontmatter format
head -20 ~/path/to/vault/workflow/decisions/*.md | head -50
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Database not initialized" | Run `/workflow:init` |
| AI extraction not working | Check `gh auth status` or set `ANTHROPIC_API_KEY` |
| Vault not syncing | Verify `~/.claude/obsidian-vault.json` has correct `vaultPath` |
| Duplicate items | Normal - deduplication checks last 30-60 minutes |
| Hooks timing out | Reduce `ai.timeout` in config or disable AI |

### Debug Mode

```bash
export WORKFLOW_DEBUG=true
```

This enables detailed logging to `~/.claude/my-workflow/debug.log`.

---

## Version History

### 1.0.0 (2026-01-29)

- Initial stable release
- Comprehensive hook system
- AI-powered extraction with Haiku
- Session summaries with Sonnet
- File retry logic for concurrent access
- Multi-language support (EN/PT-BR/ES)
- Obsidian vault integration
- GitHub vault backup
- Daily planning and briefings
