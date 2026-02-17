---
name: memory
description: Manage encrypted memory entries - add, search, list, show, delete sensitive data with optional AES-256 encryption
allowed-tools: Read, Bash, Glob, Grep, AskUserQuestion
argument-hint: "<action> [args]"
---

# Secretary Memory Command

Manage encrypted memory entries for sensitive data (credentials, API keys, IP addresses, secrets, and personal notes). Delegates to `scripts/memory-manager.sh` which uses SQLCipher (AES-256) when available, falling back to plain sqlite3 with a warning.

## Usage

```
/secretary:memory add "title" "content"              # Add entry (prompts for details)
/secretary:memory search "query"                     # Full-text search
/secretary:memory list                               # List all entries
/secretary:memory list credential                    # List by category
/secretary:memory list credential my-project         # List by category and project
/secretary:memory show 5                             # Show full entry by ID
/secretary:memory delete 5                           # Delete entry by ID
/secretary:memory status                             # Show encryption status and stats
```

## Script Location

```bash
MEMORY_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/memory-manager.sh"
```

## Categories

| Category | Description |
|----------|-------------|
| credential | Usernames, passwords, login details |
| api_key | API keys, tokens, secrets |
| ip_address | Server IPs, network addresses |
| phone | Phone numbers |
| secret | Other sensitive information |
| note | Personal notes and reminders |
| general | Uncategorized entries |

## Add Action

Add a new memory entry. Use AskUserQuestion to gather details if not all provided as arguments.

Required:
- **Title**: Short identifier for the entry
- **Content**: The sensitive data itself

Optional (gather via AskUserQuestion):
- **Category**: One of the categories above (default: general)
- **Project**: Related project name (optional)
- **Tags**: Comma-separated tags for filtering (optional)

```bash
bash "$MEMORY_SCRIPT" add "title" "content" "category" "project" "tag1,tag2"
```

### Add Output

```markdown
Memory entry added: Production DB Password (credential)

**ID:** 12
**Title:** Production DB Password
**Category:** credential
**Project:** api-service
**Tags:** database, production
```

If SQLCipher is not installed, the script will also print:

```
WARNING: SQLCipher is not installed. Memory is stored WITHOUT encryption.
Install SQLCipher for AES-256 encryption at rest:
  Ubuntu/Debian: sudo apt-get install sqlcipher
  macOS: brew install sqlcipher
  Windows: choco install sqlcipher
```

## Search Action

Full-text search across title, content, and tags using FTS5:

```bash
bash "$MEMORY_SCRIPT" search "query"
```

Search supports FTS5 syntax:
- Simple word: `password` - matches any entry containing "password"
- Phrase: `"api key"` - matches exact phrase
- Prefix: `prod*` - matches production, prod, etc.
- AND/OR: `database AND production`

### Search Output

```markdown
# Memory Search Results: "database"

[3] Production DB Password (credential) - api-service [2024-02-10]
[7] Staging DB Connection (credential) - api-service [2024-02-12]
[11] Database Backup Script (note) - global [2024-02-15]

Found 3 results.
```

## List Action

List memory entries, optionally filtered by category and/or project:

```bash
bash "$MEMORY_SCRIPT" list                        # All entries
bash "$MEMORY_SCRIPT" list "credential"           # Filter by category
bash "$MEMORY_SCRIPT" list "credential" "project" # Filter by both
```

### List Output

```markdown
# Memory Entries

[1] GitHub Token (api_key) - global
[2] AWS Access Key (api_key) - cloud-infra
[3] Production DB Password (credential) - api-service
[4] Staging Server IP (ip_address) - api-service
[5] Personal Notes (note) - global

Total: 5 entries
```

## Show Action

Display full details of a specific memory entry, including the sensitive content:

```bash
bash "$MEMORY_SCRIPT" show 3
```

This action logs an access audit entry in `memory_access_log`.

### Show Output

```markdown
# Memory Entry #3

**Title:** Production DB Password
**Category:** credential
**Project:** api-service
**Tags:** ["database", "production"]
**Created:** 2024-02-10 14:30:00
**Updated:** 2024-02-10 14:30:00

**Content:**
postgres://admin:s3cretP@ss@db.example.com:5432/myapp
```

## Delete Action

Delete a memory entry by ID. Use AskUserQuestion to confirm before deleting.

```bash
bash "$MEMORY_SCRIPT" delete 3
```

This action logs a delete audit entry in `memory_access_log`.

### Delete Output

```markdown
Memory entry #3 deleted.
```

## Status Action

Show encryption status, database location, and entry statistics:

```bash
bash "$MEMORY_SCRIPT" status
```

### Status Output

```markdown
# Secretary Memory Status

**Encryption:** ACTIVE (SQLCipher AES-256)
**Database:** ~/.claude/secretary/memory.db
**Auth:** ~/.claude/secretary/auth.json

## Statistics

**Total entries:** 12

| Category | Count |
|----------|-------|
| credential | 4 |
| api_key | 3 |
| ip_address | 2 |
| note | 2 |
| secret | 1 |
```

If SQLCipher is not installed:

```markdown
# Secretary Memory Status

**Encryption:** DISABLED (plain sqlite3)
**Database:** ~/.claude/secretary/memory.db
**Auth:** ~/.claude/secretary/auth.json

To enable encryption, install SQLCipher:
  Ubuntu/Debian: sudo apt-get install sqlcipher
  macOS: brew install sqlcipher
  Windows: choco install sqlcipher
```

## Security Notes

- The memory database uses a separate file (`memory.db`) from the main secretary database
- Encryption key is stored in `~/.claude/secretary/auth.json` with `chmod 600` permissions
- All read/write/delete operations are logged in the `memory_access_log` audit table
- Search operations are also logged (query text, not results)
- If SQLCipher is available, the database is encrypted at rest with AES-256
- Without SQLCipher, data is stored in plain sqlite3 -- a warning is shown on every write

## Error Handling

- If missing title/content for add: Shows usage instructions
- If entry not found for show/delete: "Memory entry #N not found."
- If no results for search: "No results found for: query"
- If database not yet created: "Database not yet created. Add a memory entry to initialize."
