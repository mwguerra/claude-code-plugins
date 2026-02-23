---
description: Manage commitments - add, complete, defer, edit, delete, and list action items and follow-ups
allowed-tools: Read, Bash, Glob, Grep, AskUserQuestion
argument-hint: "<action> [args]"
---

# Secretary Track Command

Manage your commitments, promises, and action items. Supports full CRUD operations with urgency grouping.

## Usage

```
/secretary:track                        # List pending commitments (default)
/secretary:track list                   # Same as above
/secretary:track add "title"            # Add new commitment
/secretary:track complete C-0001        # Mark as completed
/secretary:track defer C-0001           # Defer to later
/secretary:track defer C-0001 2024-03-01  # Defer to specific date
/secretary:track edit C-0001            # Edit commitment details
/secretary:track delete C-0001          # Delete commitment
```

## Arguments

Parse the args to determine the action:
- No args or `list` -> List pending commitments
- `add "title"` -> Create new commitment
- `complete <id>` -> Mark as completed
- `defer <id> [date]` -> Defer until date (or indefinitely)
- `edit <id>` -> Interactive edit
- `delete <id>` -> Delete commitment

## Database Location

```bash
DB_PATH="$HOME/.claude/secretary/secretary.db"

if [[ ! -f "$DB_PATH" ]]; then
    echo "Secretary database not initialized. Run /secretary:init first."
    exit 1
fi
```

## List Action (default)

Query and display pending commitments grouped by urgency:

```sql
SELECT
    id, title, description, due_date, due_type, priority, status, project,
    CASE
        WHEN due_date IS NOT NULL AND due_date < date('now') THEN 'overdue'
        WHEN due_date IS NOT NULL AND due_date = date('now') THEN 'today'
        WHEN due_date IS NOT NULL AND due_date <= date('now', '+7 days') THEN 'this_week'
        WHEN due_date IS NOT NULL THEN 'later'
        ELSE 'someday'
    END as urgency
FROM commitments
WHERE status NOT IN ('completed', 'canceled')
ORDER BY
    CASE
        WHEN due_date IS NOT NULL AND due_date < date('now') THEN 1
        WHEN due_date IS NOT NULL AND due_date = date('now') THEN 2
        WHEN due_date IS NOT NULL AND due_date <= date('now', '+7 days') THEN 3
        WHEN due_date IS NOT NULL THEN 4
        ELSE 5
    END,
    CASE priority
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
        ELSE 5
    END,
    created_at ASC;
```

### List Output

```markdown
# Pending Commitments

## Overdue (2)
- [C-0001] **Fix auth bug** - due Feb 20 (HIGH) [api-service]
- [C-0002] Review PR - due Feb 22 [claude-code-plugins]

## Due Today (1)
- [C-0003] Update docs (MEDIUM)

## This Week (3)
- [C-0004] Refactor service - due Feb 28
- [C-0005] Write tests - due Feb 29
- [C-0006] Deploy staging - due Mar 1

## Later (1)
- [C-0010] Plan Q2 roadmap - due Apr 1

## Someday (2)
- [C-0007] Research caching strategies
- [C-0008] Improve logging

---
*Total: 9 pending | Use `/secretary:track complete <id>` to mark done*
```

## Add Action

1. Parse the title from args.
2. Use AskUserQuestion to gather additional details:
   - **Due date**: today, tomorrow, this week, specific date (YYYY-MM-DD), or no date
   - **Due type**: hard, soft, asap, someday
   - **Priority**: critical, high, medium, low
   - **Project**: current project name or other
   - **Description**: optional longer description
   - **Stakeholder**: optional person/team this commitment is to

3. Generate next ID using `get_next_id`:

```bash
NEXT_ID=$(sqlite3 "$DB_PATH" "
    SELECT printf('%s-%04d', 'C', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1)
    FROM commitments WHERE id LIKE 'C-%'
")
```

4. Insert:

```sql
INSERT INTO commitments (
    id, title, description, source_type, source_session_id,
    project, stakeholder, due_date, due_type, priority, status
) VALUES (
    :id, :title, :description, 'manual', :session_id,
    :project, :stakeholder, :due_date, :due_type, :priority, 'pending'
);
```

5. Log activity:

```sql
INSERT INTO activity_timeline (activity_type, entity_type, entity_id, title, project, session_id)
VALUES ('commitment_created', 'commitments', :id, 'Created: ' || :title, :project, :session_id);
```

### Add Output

```markdown
Created commitment:
- **ID:** C-0009
- **Title:** Review new API design
- **Due:** Tomorrow (2024-02-18) - soft
- **Priority:** High
- **Project:** api-service
```

## Complete Action

```sql
UPDATE commitments
SET status = 'completed',
    completed_at = datetime('now'),
    updated_at = datetime('now')
WHERE id = :id;
```

Log activity:

```sql
INSERT INTO activity_timeline (activity_type, entity_type, entity_id, title, project, session_id)
VALUES ('commitment_completed', 'commitments', :id, 'Completed: ' || :title, :project, :session_id);
```

Update daily note completed_commitments array:

```sql
-- Get current date and existing completions
-- Append the commitment ID to the completed_commitments JSON array in daily_notes
```

### Complete Output

```markdown
Completed: [C-0001] Fix auth bug

Stats:
- Completed today: 3
- Remaining: 7
```

## Defer Action

```sql
UPDATE commitments
SET status = 'deferred',
    deferred_until = :new_date,
    deferred_count = deferred_count + 1,
    updated_at = datetime('now')
WHERE id = :id;
```

If no date provided, set `deferred_until = NULL` (someday).

Log activity:

```sql
INSERT INTO activity_timeline (activity_type, entity_type, entity_id, title, project, session_id)
VALUES ('commitment_deferred', 'commitments', :id, 'Deferred: ' || :title, :project, :session_id);
```

### Defer Output

```markdown
Deferred: [C-0005] Write tests
- New date: 2024-03-01
- Times deferred: 2
```

## Edit Action

1. Fetch the current commitment:

```sql
SELECT id, title, description, due_date, due_type, priority, status, project, stakeholder
FROM commitments WHERE id = :id;
```

2. Show current values and use AskUserQuestion to ask which fields to change.

3. Update the changed fields:

```sql
UPDATE commitments
SET title = :title,
    description = :description,
    due_date = :due_date,
    due_type = :due_type,
    priority = :priority,
    project = :project,
    stakeholder = :stakeholder,
    updated_at = datetime('now')
WHERE id = :id;
```

### Edit Output

```markdown
Updated: [C-0005] Write tests

Changes:
- Priority: medium -> high
- Due date: 2024-03-01 -> 2024-02-25
```

## Delete Action

1. Fetch the commitment to show what will be deleted:

```sql
SELECT id, title, status FROM commitments WHERE id = :id;
```

2. Use AskUserQuestion to confirm deletion.

3. Delete:

```sql
DELETE FROM commitments WHERE id = :id;
```

Log activity:

```sql
INSERT INTO activity_timeline (activity_type, entity_type, entity_id, title, project, session_id)
VALUES ('commitment_deleted', 'commitments', :id, 'Deleted: ' || :title, :project, :session_id);
```

### Delete Output

```markdown
Deleted: [C-0008] Improve logging

Remaining commitments: 8
```

## Error Handling

- If commitment ID not found: "Commitment ':id' not found. Use `/secretary:track list` to see all commitments."
- If database not initialized: "Secretary database not initialized. Run `/secretary:init` first."
