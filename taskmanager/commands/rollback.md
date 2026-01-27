---
allowed-tools: Bash
description: Revert to JSON format if SQLite migration caused issues
---

# Rollback Command

You are implementing `taskmanager:rollback`.

## Purpose

Revert from SQLite back to JSON format. This restores the backup created during migration.

## Behavior

### 1. Check for backup

```bash
if [[ ! -d ".taskmanager/backup-v1" ]]; then
    echo "Error: No backup found at .taskmanager/backup-v1"
    echo "Rollback is only possible if you migrated from JSON v1"
    exit 1
fi
```

### 2. Confirm with user

```
WARNING: This will:
1. Delete the current SQLite database
2. Restore JSON files from backup
3. Restore the schemas directory

Are you sure? (yes/no)
```

### 3. Perform rollback

```bash
# Remove SQLite database
rm -f .taskmanager/taskmanager.db

# Restore JSON files
cp .taskmanager/backup-v1/*.json .taskmanager/

# Restore schemas if present
if [[ -d ".taskmanager/backup-v1/schemas" ]]; then
    cp -r .taskmanager/backup-v1/schemas .taskmanager/
fi

# Log rollback
echo "$(date -Iseconds) [DECISION] [rollback] Reverted from SQLite v2 to JSON v1" >> .taskmanager/logs/decisions.log
```

### 4. Report

```
Rollback complete. Restored:
- tasks.json
- tasks-archive.json
- memories.json
- state.json
- schemas/

The backup remains at .taskmanager/backup-v1 for safety.
```

## Notes

- Only available if migration backup exists
- Does NOT export current SQLite data - use `export` command first if needed
- Backup is preserved after rollback for safety
