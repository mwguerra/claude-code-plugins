---
allowed-tools: Skill(taskmanager)
description: Archive existing terminal tasks to reduce tasks.json file size
argument-hint: "[--dry-run]"
---

# Migrate Archive Command

You are implementing `taskmanager:migrate-archive`.

## Purpose

This command migrates existing terminal tasks (done/canceled/duplicate) from `tasks.json` to `tasks-archive.json`. Use this when:

- `tasks.json` has grown too large (exceeds token limits)
- You have many completed tasks that haven't been archived yet
- You want to reduce file size without losing historical data

## Arguments

- `--dry-run` or `-n`: Show what would be archived without making changes

## Behavior

### 1. Load current state

1. Read `.taskmanager/tasks.json`.
2. Read `.taskmanager/tasks-archive.json` (create from template if not exists).
3. Count total tasks and terminal tasks.

### 2. Find archivable tasks

A task is archivable if:

1. Its `status` is terminal (`done`, `canceled`, or `duplicate`).
2. It does NOT already have `archivedRef: true`.
3. For parent tasks: All direct children are either already archived OR terminal.

Algorithm:
1. Flatten all tasks from the tree.
2. Filter for terminal tasks without `archivedRef`.
3. Sort by depth (deepest first) to archive leaves before parents.
4. For each candidate, verify all children are terminal/archived before archiving.

### 3. Dry-run mode (`--dry-run`)

If `--dry-run` flag is present:

1. List all tasks that would be archived:
   ```
   Tasks to archive (dry-run):
   - 1.2.3: "Implement user auth" (done)
   - 1.2.4: "Add login form" (done)
   - 1.2: "Authentication feature" (done) [parent]
   - 2.1: "Setup database" (canceled)

   Total: 4 tasks would be archived
   Estimated size reduction: ~12,000 tokens
   ```

2. Show projected file sizes:
   ```
   Current tasks.json: ~31,000 tokens
   After migration: ~19,000 tokens
   Archive size: ~12,000 tokens (added)
   ```

3. Do NOT modify any files.
4. Exit with summary.

### 4. Archive execution (without `--dry-run`)

For each archivable task (bottom-up, leaves first):

1. **Copy to archive**:
   - Read the full task object from `tasks.json`.
   - Add `archivedAt: <current ISO timestamp>`.
   - Append to `tasks-archive.json.tasks[]`.

2. **Replace with stub in tasks.json**:
   - Keep only: `id`, `title`, `status`, `parentId`, `priority`, `complexity`, `estimateSeconds`, `durationSeconds`, `completedAt`
   - Add: `archivedRef: true`
   - Set: `subtasks: []`
   - Remove all other fields.

3. **Update archive metadata**:
   - Set `tasks-archive.json.lastUpdated` to current timestamp.

4. **Log the archival**:
   - Append to `decisions.log`: `Migrated task <id> to archive`

### 5. Write files

1. Write updated `tasks-archive.json`.
2. Write updated `tasks.json` with stubs.

### 6. Summary

Display migration results:

```
Migration complete:

Archived tasks: 15
- Leaf tasks: 12
- Parent tasks: 3

File sizes:
- tasks.json: 31,000 → 18,500 tokens (40% reduction)
- tasks-archive.json: 0 → 12,500 tokens

Next steps:
- Dashboard and metrics will continue to work (stubs retain metric fields)
- Use `taskmanager:dashboard` to verify
- Archived task details are preserved in tasks-archive.json
```

## Error Handling

- If `tasks.json` cannot be parsed: Log error, abort.
- If archive already contains a task with same ID: Skip that task, warn user.
- If write fails: Log error, attempt rollback (restore original files).

## Notes

- This command is idempotent: Running it again will only archive newly completed tasks.
- Already-stubbed tasks (with `archivedRef: true`) are skipped.
- Parent tasks are only archived after all children are archived.
- The archive preserves the complete task history including all metadata.
