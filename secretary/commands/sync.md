---
description: Force vault sync and external change detection - sync database records to Obsidian vault notes and commit/push to git
allowed-tools: Read, Bash, Glob, Grep
argument-hint: "[vault|git|detect|acknowledge [id]|full]"
---

# Secretary Sync Command

Force synchronization of database records to Obsidian vault markdown notes, commit and push vault changes to git, and detect external changes made outside Claude Code.

## Usage

```
/secretary:sync                        # Full sync (vault + git + detect)
/secretary:sync full                   # Same as above
/secretary:sync vault                  # Only sync DB records to vault notes
/secretary:sync git                    # Only commit/push vault to git
/secretary:sync detect                 # Only detect external changes
/secretary:sync acknowledge            # Mark all external changes as seen
/secretary:sync acknowledge X-001      # Mark specific change as seen
```

## Script Locations

```bash
DB_PATH="$HOME/.claude/secretary/secretary.db"
VAULT_SYNC_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/vault-sync.sh"
GIT_SYNC_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/vault-git-sync.sh"

if [[ ! -f "$DB_PATH" ]]; then
    echo "Secretary database not initialized. Run /secretary:init first."
    exit 1
fi
```

## Full Sync (default)

Runs all three operations in sequence:
1. Vault sync (DB -> markdown notes)
2. Git sync (commit + push vault)
3. External change detection

## Vault Sync

Run `scripts/vault-sync.sh` to create/update Obsidian vault markdown notes from database records:

```bash
bash "$VAULT_SYNC_SCRIPT"
```

This script syncs the following entities where `vault_note_path IS NULL`:

### What Gets Synced

| Entity | Vault Path | Filename |
|--------|------------|----------|
| Decisions | `secretary/decisions/` | `D-0001.md` |
| Commitments | `secretary/commitments/` | `C-0001.md` |
| Ideas | `secretary/ideas/` | `I-0001.md` |
| Daily Notes | `secretary/daily/` | `YYYY-MM-DD.md` |
| Index | `secretary/` | `index.md` |

Each vault note includes:
- Obsidian-compatible YAML frontmatter (title, tags, metadata)
- Formatted markdown body with entity details
- Wikilinks to related entities

After syncing, the script updates `vault_note_path` on each record to prevent re-syncing.

### Vault Sync Output

```markdown
# Vault Sync Complete

## Synced Items

### Decisions (2)
- Created: secretary/decisions/D-0023.md
- Created: secretary/decisions/D-0024.md

### Commitments (3)
- Created: secretary/commitments/C-0030.md
- Created: secretary/commitments/C-0031.md
- Created: secretary/commitments/C-0032.md

### Ideas (1)
- Created: secretary/ideas/I-0015.md

### Daily Note
- Created: secretary/daily/2024-02-17.md

### Index
- Updated: secretary/index.md

## Skipped (already synced)
- 15 decisions
- 22 commitments
- 8 ideas
```

## Git Sync

Run `scripts/vault-git-sync.sh` to commit and push vault changes:

```bash
bash "$GIT_SYNC_SCRIPT" manual
```

This script:
1. Initializes git repo in vault if needed (with `.gitignore`)
2. Configures GitHub remote via `gh` if available
3. Pulls latest changes (rebase)
4. Stages all changes (`git add -A`)
5. Commits with message: `Secretary sync: <project> at <timestamp>`
6. Pushes to remote if GitHub is configured

### Git Sync Output

```markdown
# Vault Git Sync

- **Vault:** ~/guerra_vault
- **Remote:** github.com/mwguerra/obsidian-vault-backup (private)
- **Branch:** main

## Changes Committed
- 6 new files
- 1 modified file

**Commit:** abc1234 - Secretary sync: claude-code-plugins at 2024-02-17 14:30:00
**Pushed:** Yes
```

## External Change Detection

Detect changes made outside Claude Code sessions:

### Git Changes

```bash
# Get commits not in our activity_timeline
LAST_KNOWN=$(sqlite3 "$DB_PATH" "
    SELECT MAX(timestamp) FROM activity_timeline WHERE activity_type = 'commit'
" 2>/dev/null)

git log --since="$LAST_KNOWN" --format="%H|%h|%s|%an|%ci" 2>/dev/null
```

### File Changes

```bash
# Find files modified since last session ended
LAST_SESSION_END=$(sqlite3 "$DB_PATH" "
    SELECT MAX(ended_at) FROM sessions WHERE status = 'completed'
" 2>/dev/null)

find . -type f -newer /tmp/secretary-reference \
    -not -path "./.git/*" \
    -not -path "./node_modules/*" \
    -not -path "./vendor/*" \
    2>/dev/null | head -50
```

### GitHub Changes

If `gh` CLI is available and authenticated:

```bash
# New notifications
gh api notifications --jq '.[] | select(.reason == "comment") | .subject.title' 2>/dev/null

# Issues assigned to you
gh issue list --assignee @me --json number,title,updatedAt 2>/dev/null
```

### Recording External Changes

For each detected change, insert into the `external_changes` table:

```sql
INSERT INTO external_changes (
    id, change_type, source, description,
    details, project, file_path,
    detected_at, relevance_score
) VALUES (
    :id, :type, :source, :description,
    :details_json, :project, :file_path,
    datetime('now'), :relevance
);
```

### Detect Output

```markdown
# External Changes Detected

## Git (3 commits)

| Hash | Message | Author | When |
|------|---------|--------|------|
| abc123 | fix: resolve timeout | John | 2 hours ago |
| def456 | feat: add caching | John | 3 hours ago |
| ghi789 | docs: update README | Jane | 5 hours ago |

## Files Modified (8)

- `src/api/cache.ts` - modified 2 hours ago
- `src/config/settings.ts` - modified 3 hours ago
- `README.md` - modified 5 hours ago
- ... (5 more)

## GitHub (2 items)

- New comment on PR #45: "Looks good, but..."
- Issue #67 assigned to you: "Bug in login flow"

---
*Use `/secretary:sync acknowledge` to mark all as seen*
*Use `/secretary:sync acknowledge X-001` to mark specific change as seen*
```

## Acknowledge Action

Mark external changes as acknowledged:

### Acknowledge All

```sql
UPDATE external_changes
SET acknowledged = 1,
    acknowledged_at = datetime('now')
WHERE acknowledged = 0;
```

### Acknowledge Specific

```sql
UPDATE external_changes
SET acknowledged = 1,
    acknowledged_at = datetime('now')
WHERE id = :id;
```

### Acknowledge Output

```markdown
Acknowledged 5 external changes.
```

## Notes

- Vault sync only creates notes for records where `vault_note_path IS NULL`
- Git sync uses `flock` or equivalent to prevent conflicts with the background worker
- External change detection runs in the current working directory
- The sync state is tracked in `worker_state.last_vault_sync_at`
- For automatic periodic sync, use `/secretary:cron setup` to install the background worker
