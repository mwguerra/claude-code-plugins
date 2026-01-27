---
allowed-tools: Bash
description: Export SQLite database to JSON for inspection or sharing
argument-hint: "[--tasks | --memories | --all] [output-file]"
---

# Export Command

You are implementing `taskmanager:export`.

## Purpose

Export taskmanager data to JSON format for inspection, sharing, or backup.

## Arguments

- `--tasks` - Export tasks only
- `--memories` - Export memories only
- `--all` - Export everything (default)
- `[output-file]` - Output file path (default: stdout)

## Behavior

### Export tasks

```bash
sqlite3 -json .taskmanager/taskmanager.db "
SELECT * FROM tasks ORDER BY id;
" | jq '{
    version: "2.0.0",
    exported_at: (now | todate),
    tasks: .
}'
```

### Export memories

```bash
sqlite3 -json .taskmanager/taskmanager.db "
SELECT * FROM memories ORDER BY id;
" | jq '{
    version: "2.0.0",
    exported_at: (now | todate),
    memories: .
}'
```

### Export all

```bash
{
    echo '{"version": "2.0.0", "exported_at": "'$(date -Iseconds)'",'
    echo '"tasks": '
    sqlite3 -json .taskmanager/taskmanager.db "SELECT * FROM tasks ORDER BY id;"
    echo ','
    echo '"memories": '
    sqlite3 -json .taskmanager/taskmanager.db "SELECT * FROM memories ORDER BY id;"
    echo ','
    echo '"state": '
    sqlite3 -json .taskmanager/taskmanager.db "SELECT * FROM state;"
    echo '}'
} | jq '.'
```

### Output to file

If output-file is specified:
```bash
# ... export command ... > output-file.json
echo "Exported to output-file.json"
```

## Notes

- Useful for debugging, sharing project state, or creating backups
- Output is valid JSON that could be re-imported if needed
