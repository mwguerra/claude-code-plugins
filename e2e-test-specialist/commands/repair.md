---
description: Run integrity checks on the database and offer recovery options
allowed-tools: Bash(bash:*), Bash(sqlite3:*), AskUserQuestion, Read(*)
argument-hint: [--auto-fix]
---

# /e2e-test-specialist:repair

Inspect the SQLite database for integrity issues and offer recovery if any are
found. Useful after a hard crash, an interrupted migration, or when you suspect
WAL corruption.

## Process

### 1. Run integrity check

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

INTEGRITY="$(sqlite3 "$E2E_DB" 'PRAGMA integrity_check;')"
FK_CHECK="$(sqlite3 "$E2E_DB" 'PRAGMA foreign_key_check;')"
QUICK_CHECK="$(sqlite3 "$E2E_DB" 'PRAGMA quick_check;')"

echo "integrity_check     : $INTEGRITY"
echo "foreign_key_check   : ${FK_CHECK:-(no violations)}"
echo "quick_check         : $QUICK_CHECK"
```

### 2. Backup before doing anything else

```bash
BACKUP="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/backup-db.sh" pre-repair)"
echo "Backed up to: $BACKUP"
```

### 3. If `integrity_check` returned anything other than `ok`

Use `AskUserQuestion`:

> "Database integrity check failed. Choose recovery:
>   1. Dump-and-reload (dumps SQL, drops + recreates DB, re-applies dump)
>   2. Restore from latest backup
>   3. Show details and exit"

For dump-and-reload:

```bash
DUMP="$(mktemp).sql"
sqlite3 "$E2E_DB" .dump > "$DUMP"
mv "$E2E_DB" "${E2E_DB}.corrupt"
sqlite3 "$E2E_DB" < "$DUMP"

# Verify
sqlite3 "$E2E_DB" 'PRAGMA integrity_check;'
```

For restore-from-backup:

```bash
LATEST="$(ls -1t $E2E_ROOT_DIR/runs/_backups/*.sqlite | head -1)"
mv "$E2E_DB" "${E2E_DB}.corrupt"
cp "$LATEST" "$E2E_DB"
echo "Restored from: $LATEST"
```

### 4. If `foreign_key_check` returned violations

These are typically orphaned `step_executions.bug_id` (after manual deletes
of bugs). Show the violating rows; offer to NULL them:

```bash
sqlite3 "$E2E_DB" "
  UPDATE step_executions SET bug_id = NULL
   WHERE bug_id IS NOT NULL
     AND bug_id NOT IN (SELECT id FROM bugs);
"
```

### 5. Vacuum + analyze

After repair, reclaim space and refresh statistics:

```bash
sqlite3 "$E2E_DB" 'VACUUM; ANALYZE;'
```

### 6. Final report

```bash
e2e_section "Repair report"
e2e_kv "result"          "${RESULT:-ok}"
e2e_kv "backup"          "$BACKUP"
e2e_kv "size before"     "$BEFORE_SIZE"
e2e_kv "size after"      "$AFTER_SIZE"
```

## Notes

- The `_backups/` directory keeps the last 30 backups by default
  (`backup.keep_count` in config.json).
- If a corrupt DB cannot be recovered via dump-and-reload AND no backup
  exists, the original `.corrupt` file is left in place — you can mail it to
  the SQLite mailing list or use `sqlite3-recover` (third-party tool).
