---
allowed-tools: Bash
description: Manage tags across tasks - list, add, remove, filter, rename
argument-hint: "<list | add | remove | filter | rename> [options]"
---

# Tags Command

You are implementing `taskmanager:tags`.

## Purpose

Manage tags stored as JSON arrays in the `tags` column of the tasks table. Tags enable organizing tasks into sprints, feature groups, milestones, or any custom categorization.

## Arguments

- `list` - List all unique tags with task counts
- `add <tag> <id1> [id2...]` - Add a tag to one or more tasks
- `remove <tag> <id1> [id2...]` - Remove a tag from one or more tasks
- `filter <tag>` - Show all tasks with a specific tag
- `rename <old-tag> <new-tag>` - Rename a tag across all tasks

## Database Location

All operations use the SQLite database at `.taskmanager/taskmanager.db`.

## Behavior

### list — List all unique tags

```bash
DB=".taskmanager/taskmanager.db"

echo "=== Tags ==="
echo ""

sqlite3 -column -header "$DB" "
SELECT
    tag.value as Tag,
    COUNT(DISTINCT t.id) as 'Task Count',
    SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) as Done,
    SUM(CASE WHEN t.status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END) as Remaining
FROM tasks t, json_each(t.tags) tag
WHERE t.archived_at IS NULL
GROUP BY tag.value
ORDER BY COUNT(DISTINCT t.id) DESC;
"
```

If no tags exist, output:
```
No tags found. Use 'taskmanager:tags add <tag> <task-id>' to add tags.
```

### add — Add a tag to tasks

```bash
DB=".taskmanager/taskmanager.db"
TAG="$1"  # The tag to add
# $2, $3, ... are task IDs

for TASK_ID in "${TASK_IDS[@]}"; do
    # Check if tag already exists on this task
    EXISTS=$(sqlite3 "$DB" "
        SELECT COUNT(*) FROM tasks t, json_each(t.tags) tag
        WHERE t.id = '$TASK_ID' AND tag.value = '$TAG';
    ")

    if [[ "$EXISTS" == "0" ]]; then
        sqlite3 "$DB" "
            UPDATE tasks SET
                tags = json_insert(tags, '$[#]', '$TAG'),
                updated_at = datetime('now')
            WHERE id = '$TASK_ID';
        "
        echo "Added tag '$TAG' to task $TASK_ID"
    else
        echo "Task $TASK_ID already has tag '$TAG'"
    fi
done
```

Validation:
- If the task doesn't exist, report error and skip.
- Tags are case-sensitive strings.

### remove — Remove a tag from tasks

```bash
DB=".taskmanager/taskmanager.db"
TAG="$1"  # The tag to remove
# $2, $3, ... are task IDs

for TASK_ID in "${TASK_IDS[@]}"; do
    sqlite3 "$DB" "
        UPDATE tasks SET
            tags = (
                SELECT COALESCE(json_group_array(tag.value), '[]')
                FROM json_each(tags) tag
                WHERE tag.value != '$TAG'
            ),
            updated_at = datetime('now')
        WHERE id = '$TASK_ID';
    "
    echo "Removed tag '$TAG' from task $TASK_ID"
done
```

### filter — Show tasks with a specific tag

```bash
DB=".taskmanager/taskmanager.db"
TAG="$1"

echo "=== Tasks tagged '$TAG' ==="
echo ""

sqlite3 -column -header "$DB" "
SELECT
    t.id as ID,
    SUBSTR(t.title, 1, 40) as Title,
    t.status as Status,
    t.priority as Priority,
    COALESCE(t.complexity_scale, '-') as Size
FROM tasks t, json_each(t.tags) tag
WHERE tag.value = '$TAG'
  AND t.archived_at IS NULL
ORDER BY
    CASE t.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    t.id;
"

# Summary
sqlite3 "$DB" "
SELECT
    'Total: ' || COUNT(*) || ' | Done: ' ||
    SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) || ' | Remaining: ' ||
    SUM(CASE WHEN t.status NOT IN ('done', 'canceled', 'duplicate') THEN 1 ELSE 0 END)
FROM tasks t, json_each(t.tags) tag
WHERE tag.value = '$TAG' AND t.archived_at IS NULL;
"
```

### rename — Rename a tag across all tasks

```bash
DB=".taskmanager/taskmanager.db"
OLD_TAG="$1"
NEW_TAG="$2"

# Count affected tasks
COUNT=$(sqlite3 "$DB" "
    SELECT COUNT(DISTINCT t.id)
    FROM tasks t, json_each(t.tags) tag
    WHERE tag.value = '$OLD_TAG';
")

if [[ "$COUNT" == "0" ]]; then
    echo "No tasks found with tag '$OLD_TAG'"
    exit 0
fi

echo "Renaming tag '$OLD_TAG' to '$NEW_TAG' across $COUNT tasks..."

# Update all tasks that have the old tag
sqlite3 "$DB" "
    UPDATE tasks SET
        tags = (
            SELECT json_group_array(
                CASE WHEN tag.value = '$OLD_TAG' THEN '$NEW_TAG' ELSE tag.value END
            )
            FROM json_each(tags) tag
        ),
        updated_at = datetime('now')
    WHERE id IN (
        SELECT t.id FROM tasks t, json_each(t.tags) tag
        WHERE tag.value = '$OLD_TAG'
    );
"

echo "Renamed '$OLD_TAG' -> '$NEW_TAG' on $COUNT tasks"
```

---

## Logging Requirements

**To decisions.log** (ALWAYS):
- Tag additions, removals, and renames with affected task counts

---

## Usage Examples

```bash
# List all tags
taskmanager:tags list

# Add a tag to tasks
taskmanager:tags add sprint-3 1.1 1.2 1.3

# Add a tag to a single task
taskmanager:tags add security 2.1

# Remove a tag from tasks
taskmanager:tags remove sprint-2 1.1 1.2

# Filter tasks by tag
taskmanager:tags filter sprint-3

# Rename a tag across all tasks
taskmanager:tags rename sprint-3 sprint-4
```

---

## Related Commands

- `taskmanager:stats` - View statistics (includes tag distribution)
- `taskmanager:dashboard` - View dashboard (includes tag breakdown)
- `taskmanager:get-task <id>` - View task details including tags
- `taskmanager:update-task <id> --tags '["tag1"]'` - Replace all tags on a task
