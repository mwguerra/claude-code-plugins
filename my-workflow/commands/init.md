---
name: init
description: Initialize the my-workflow plugin - create database, configure settings
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Workflow Init Command

Initialize the my-workflow plugin for first-time setup.

## Usage

```
/workflow:init                    # Interactive setup
/workflow:init --defaults         # Use default configuration
/workflow:init --reset            # Reset database (caution!)
```

## Setup Steps

### 1. Create Directory Structure

```bash
mkdir -p ~/.claude/my-workflow
```

### 2. Initialize Database

Read the schema file and create the SQLite database:

```bash
SCHEMA_FILE="${CLAUDE_PLUGIN_ROOT}/schemas/schema.sql"
DB_PATH="$HOME/.claude/my-workflow/workflow.db"

if [[ ! -f "$DB_PATH" ]]; then
    sqlite3 "$DB_PATH" < "$SCHEMA_FILE"
    echo "Database created at $DB_PATH"
fi
```

### 3. Create Configuration File

If interactive, use AskUserQuestion to gather:

1. **GitHub Integration**
   - GitHub username
   - Track all repos or specific list?
   - Track issues? PRs? Reviews?

2. **Briefing Preferences**
   - Show briefing on session start?
   - Include GitHub items?
   - Include commitments? Decisions? Goals?

3. **Logging Preferences**
   - Capture commits automatically?
   - Extract decisions from conversation?
   - Extract commitments from conversation?

4. **Vault Integration**
   - Enable vault sync?
   - Sync on session end?

### 4. Write Configuration

Location: `~/.claude/my-workflow.json`

```json
{
  "github": {
    "username": "mwguerra",
    "trackRepos": ["*"],
    "excludeRepos": [],
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
    "captureToolCalls": false
  },
  "vault": {
    "enabled": true,
    "syncOnSessionEnd": true,
    "workflowFolder": "workflow"
  },
  "patterns": {
    "enabled": true,
    "minConfidence": 0.6,
    "minEvidence": 3
  }
}
```

### 5. Verify Obsidian Vault Integration

Check if obsidian-vault plugin is configured:

```bash
VAULT_CONFIG="$HOME/.claude/obsidian-vault.json"
if [[ -f "$VAULT_CONFIG" ]]; then
    VAULT_PATH=$(jq -r '.vaultPath' "$VAULT_CONFIG")
    if [[ -d "$VAULT_PATH" ]]; then
        # Create workflow folders in vault
        mkdir -p "$VAULT_PATH/workflow"/{sessions,decisions,commitments,reviews,goals,patterns}
        echo "Vault integration ready at $VAULT_PATH/workflow/"
    fi
fi
```

### 6. Verify GitHub CLI

```bash
if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null; then
        echo "GitHub CLI authenticated and ready"
    else
        echo "GitHub CLI found but not authenticated. Run: gh auth login"
    fi
else
    echo "GitHub CLI not found. Install with: brew install gh"
fi
```

## Output Format

### Interactive Setup
```markdown
# My Workflow Setup

## Database
Database created at: ~/.claude/my-workflow/workflow.db

## Configuration

### GitHub Integration
- **Username:** mwguerra
- **Track Repos:** All (*)
- **Track Issues:** Yes
- **Track PRs:** Yes
- **Track Reviews:** Yes

### Session Briefings
- **Show on Start:** Yes
- **Include GitHub:** Yes
- **Include Commitments:** Yes
- **Include Decisions:** Yes
- **Include Goals:** Yes

### Activity Logging
- **Capture Commits:** Yes
- **Extract Decisions:** Yes
- **Extract Commitments:** Yes

### Vault Integration
- **Enabled:** Yes
- **Vault Path:** ~/guerra_vault
- **Workflow Folder:** workflow/

## Vault Folders Created

- ~/guerra_vault/workflow/sessions/
- ~/guerra_vault/workflow/decisions/
- ~/guerra_vault/workflow/commitments/
- ~/guerra_vault/workflow/reviews/
- ~/guerra_vault/workflow/goals/
- ~/guerra_vault/workflow/patterns/

## Dependencies

| Dependency | Status |
|------------|--------|
| SQLite | Ready |
| jq | Ready |
| GitHub CLI | Authenticated |
| Obsidian Vault | Configured |

---
Setup complete! Use `/workflow:briefing` to see your first briefing.
```

### Default Setup
```markdown
# My Workflow Quick Setup

Using default configuration...

- Database: ~/.claude/my-workflow/workflow.db
- Config: ~/.claude/my-workflow.json
- Vault sync: Enabled (if obsidian-vault configured)
- GitHub: Will use authenticated user

Run `/workflow:init` again for custom configuration.
```

## Reset Option

With `--reset`:
1. Prompt for confirmation
2. Backup existing database
3. Delete and recreate database
4. Keep configuration file

```bash
if [[ -f "$DB_PATH" ]]; then
    BACKUP="$DB_PATH.backup.$(date +%Y%m%d%H%M%S)"
    cp "$DB_PATH" "$BACKUP"
    rm "$DB_PATH"
    sqlite3 "$DB_PATH" < "$SCHEMA_FILE"
    echo "Database reset. Backup at: $BACKUP"
fi
```
