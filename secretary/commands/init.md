---
description: Initialize the secretary plugin - create databases, config, vault structure, encryption key, and optionally migrate from my-workflow
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# Secretary Init Command

Initialize the secretary plugin for first-time setup. Creates databases, configuration, vault structure, and encryption key. Detects and offers migration from the predecessor `my-workflow` plugin.

## Usage

```
/secretary:init                    # Interactive setup
/secretary:init --defaults         # Use default configuration
/secretary:init --reset            # Reset databases (creates backup first)
/secretary:init --migrate          # Force migration from my-workflow
```

## Paths

```bash
SECRETARY_DB_DIR="$HOME/.claude/secretary"
SECRETARY_DB_PATH="$SECRETARY_DB_DIR/secretary.db"
SECRETARY_MEMORY_DB_PATH="$SECRETARY_DB_DIR/memory.db"
SECRETARY_AUTH_FILE="$SECRETARY_DB_DIR/auth.json"
SECRETARY_CONFIG_FILE="$HOME/.claude/secretary.json"
SECRETARY_WORKER_LOG="$SECRETARY_DB_DIR/worker.log"
SECRETARY_DEBUG_LOG="$SECRETARY_DB_DIR/debug.log"
SCHEMA_FILE="${CLAUDE_PLUGIN_ROOT}/schemas/secretary.sql"
MEMORY_SCHEMA_FILE="${CLAUDE_PLUGIN_ROOT}/schemas/memory.sql"
LEGACY_DB="$HOME/.claude/my-workflow/workflow.db"
```

## Setup Steps

### 1. Check Dependencies

Check that required tools are installed. If any are missing, show install instructions per platform and stop.

```bash
MISSING=()

if ! command -v sqlite3 &>/dev/null; then
    MISSING+=("sqlite3")
fi

if ! command -v jq &>/dev/null; then
    MISSING+=("jq")
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Missing required dependencies: ${MISSING[*]}"
    echo ""
    echo "Install them with:"
    case "$(uname -s)" in
        Linux*)
            echo "  Ubuntu/Debian: sudo apt-get install ${MISSING[*]}"
            echo "  Fedora/RHEL:   sudo dnf install ${MISSING[*]}"
            echo "  Arch:          sudo pacman -S ${MISSING[*]}"
            ;;
        Darwin*)
            echo "  brew install ${MISSING[*]}"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "  choco install ${MISSING[*]}"
            ;;
    esac
    # Stop here — do not proceed without dependencies
fi
```

Also check optional dependencies and report their status:

| Dependency | Required | Purpose |
|------------|----------|---------|
| sqlite3 | Yes | Core database engine |
| jq | Yes | JSON processing |
| sqlcipher | No | AES-256 encryption for memory DB |
| gh | No | GitHub CLI integration |
| flock | No | Worker lock (prevents overlapping cron runs) |
| openssl | No | Encryption key generation |

### 2. Detect Legacy my-workflow Installation

```bash
if [[ -f "$HOME/.claude/my-workflow/workflow.db" ]]; then
    echo "Detected existing my-workflow database at ~/.claude/my-workflow/workflow.db"
    echo "Would you like to migrate your data to Secretary?"
    # Use AskUserQuestion to confirm migration
fi
```

If migration is accepted (or `--migrate` flag used):
1. Read all data from `workflow.db` tables: sessions, commitments, decisions, ideas, goals, patterns, activity_timeline, daily_notes, knowledge_nodes, knowledge_edges, github_cache, external_changes
2. Insert into the new `secretary.db` using the same schema (they are compatible)
3. Report counts of migrated items per table
4. Do NOT delete the old database — leave it as a backup

### 3. Create Directory Structure

```bash
mkdir -p "$HOME/.claude/secretary"
```

### 4. Initialize Secretary Database

```bash
if [[ ! -f "$SECRETARY_DB_PATH" ]]; then
    sqlite3 "$SECRETARY_DB_PATH" < "$SCHEMA_FILE"
    sqlite3 "$SECRETARY_DB_PATH" "PRAGMA journal_mode=WAL;"
    echo "Secretary database created at $SECRETARY_DB_PATH"
else
    echo "Secretary database already exists at $SECRETARY_DB_PATH"
fi
```

### 5. Initialize Memory Database

```bash
if [[ ! -f "$SECRETARY_MEMORY_DB_PATH" ]]; then
    sqlite3 "$SECRETARY_MEMORY_DB_PATH" < "$MEMORY_SCHEMA_FILE"
    echo "Memory database created at $SECRETARY_MEMORY_DB_PATH"
fi
```

### 6. Generate Encryption Key

Create `auth.json` with a new encryption key if it does not exist:

```bash
if [[ ! -f "$SECRETARY_AUTH_FILE" ]]; then
    KEY=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p | tr -d '\n')
    SQLCIPHER_AVAILABLE=false
    command -v sqlcipher &>/dev/null && SQLCIPHER_AVAILABLE=true

    cat > "$SECRETARY_AUTH_FILE" << EOF
{
  "encryption_key": "$KEY",
  "key_created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "sqlcipher_available": $SQLCIPHER_AVAILABLE
}
EOF
    chmod 600 "$SECRETARY_AUTH_FILE" 2>/dev/null || true
    echo "Encryption key generated at $SECRETARY_AUTH_FILE"
fi
```

### 7. Create Configuration File

If interactive (no `--defaults`), use AskUserQuestion to gather preferences:

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
   - Extract ideas from conversation?

4. **AI Extraction**
   - Enable AI extraction (requires Claude API)?

5. **Vault Integration**
   - Enable vault sync?
   - Sync on session end?

6. **Worker / Cron**
   - Enable cron worker?

Write to `~/.claude/secretary.json`:

```json
{
  "github": {
    "username": "",
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
    "captureIdeas": true,
    "captureToolCalls": false
  },
  "ai": {
    "enabled": true
  },
  "memory": {
    "enabled": true
  },
  "vault": {
    "enabled": true,
    "syncOnSessionEnd": true,
    "secretaryFolder": "secretary"
  },
  "worker": {
    "cronEnabled": true
  },
  "patterns": {
    "enabled": true,
    "minConfidence": 0.6,
    "minEvidence": 3
  }
}
```

### 8. Setup Vault Structure

If vault integration is enabled and the obsidian-vault plugin is configured:

```bash
VAULT_CONFIG="$HOME/.claude/obsidian-vault.json"
if [[ -f "$VAULT_CONFIG" ]]; then
    VAULT_PATH=$(jq -r '.vaultPath' "$VAULT_CONFIG")
    if [[ -d "$VAULT_PATH" ]]; then
        SECRETARY_FOLDER="$VAULT_PATH/secretary"
        mkdir -p "$SECRETARY_FOLDER"/{daily,sessions,decisions,commitments,ideas,goals,reviews,patterns}
        echo "Vault integration ready at $SECRETARY_FOLDER/"
    fi
fi
```

### 9. Verify GitHub CLI

```bash
if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null; then
        echo "GitHub CLI: authenticated and ready"
    else
        echo "GitHub CLI: found but not authenticated. Run: gh auth login"
    fi
else
    echo "GitHub CLI: not installed (optional — needed for GitHub integration)"
fi
```

## Reset Option

With `--reset`:
1. Prompt for confirmation via AskUserQuestion
2. Backup existing databases with timestamp
3. Delete and recreate databases
4. Keep configuration file and auth.json

```bash
if [[ -f "$SECRETARY_DB_PATH" ]]; then
    BACKUP_DIR="$SECRETARY_DB_DIR/backups"
    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    cp "$SECRETARY_DB_PATH" "$BACKUP_DIR/secretary.db.backup.$TIMESTAMP"
    cp "$SECRETARY_MEMORY_DB_PATH" "$BACKUP_DIR/memory.db.backup.$TIMESTAMP" 2>/dev/null || true
    rm "$SECRETARY_DB_PATH"
    rm "$SECRETARY_MEMORY_DB_PATH" 2>/dev/null || true
    sqlite3 "$SECRETARY_DB_PATH" < "$SCHEMA_FILE"
    sqlite3 "$SECRETARY_DB_PATH" "PRAGMA journal_mode=WAL;"
    sqlite3 "$SECRETARY_MEMORY_DB_PATH" < "$MEMORY_SCHEMA_FILE"
    echo "Databases reset. Backups at: $BACKUP_DIR/"
fi
```

## Output Format

```markdown
# Secretary Setup

## Dependencies

| Dependency | Status |
|------------|--------|
| sqlite3 | Installed |
| jq | Installed |
| sqlcipher | Not installed (memory will be unencrypted) |
| GitHub CLI | Authenticated |

## Databases

- Secretary DB: ~/.claude/secretary/secretary.db (created)
- Memory DB: ~/.claude/secretary/memory.db (created)
- Encryption key: ~/.claude/secretary/auth.json (generated)

## Configuration

- Config file: ~/.claude/secretary.json (created)

### GitHub Integration
- **Username:** mwguerra
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
- **Extract Ideas:** Yes

### Vault Integration
- **Enabled:** Yes
- **Vault Path:** ~/guerra_vault/secretary/
- **Folders Created:** daily, sessions, decisions, commitments, ideas, goals, reviews, patterns

## Migration

- Legacy my-workflow database: Not found (clean install)

---
Setup complete! Use `/secretary:briefing` to see your first briefing.
Use `/secretary:cron setup` to install the background worker.
```

## Idempotent

Running init multiple times is safe:
- Existing databases are preserved (unless `--reset`)
- Existing config file is preserved
- Existing auth.json is preserved
- Only missing resources are created
