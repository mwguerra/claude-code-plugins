---
name: track
description: Manage commitments - add, list, complete, defer action items and follow-ups
allowed-tools: Read, Bash, Glob, Grep
---

# Commitment Tracking Command

Manage your commitments, promises, and action items.

## Usage

```
/workflow:track                    # List pending commitments
/workflow:track add "title"        # Add new commitment
/workflow:track complete C-0001    # Mark as completed
/workflow:track defer C-0001       # Defer to later
/workflow:track edit C-0001        # Edit commitment details
/workflow:track delete C-0001      # Delete commitment
```

## Arguments

Parse the args to determine the action:
- No args or `list` → List pending commitments
- `add "title"` → Create new commitment
- `complete <id>` → Mark as completed
- `defer <id> [date]` → Defer until date (or indefinitely)
- `edit <id>` → Interactive edit
- `delete <id>` → Delete commitment

## Database Location

```bash
DB_PATH="$HOME/.claude/my-workflow/workflow.db"
```

## List Action (default)

Query and display pending commitments grouped by urgency:

```sql
-- Get all non-completed commitments
SELECT
    id, title, due_date, due_type, priority, status,
    CASE
        WHEN due_date < date('now') THEN 'overdue'
        WHEN due_date = date('now') THEN 'today'
        WHEN due_date <= date('now', '+7 days') THEN 'this_week'
        ELSE 'later'
    END as urgency
FROM commitments
WHERE status NOT IN ('completed', 'canceled')
ORDER BY
    CASE urgency
        WHEN 'overdue' THEN 1
        WHEN 'today' THEN 2
        WHEN 'this_week' THEN 3
        ELSE 4
    END,
    CASE priority
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
    END;
```

## Add Action

1. Parse the title from args
2. Ask user for additional details using AskUserQuestion:
   - Due date (today, tomorrow, this week, specific date, no date)
   - Priority (critical, high, medium, low)
   - Assignee (self or external)

3. Generate next ID:
   ```sql
   SELECT MAX(CAST(SUBSTR(id, 3) AS INTEGER)) + 1 FROM commitments;
   ```

4. Insert:
   ```sql
   INSERT INTO commitments (id, title, due_date, due_type, priority, status, source_type)
   VALUES (:id, :title, :due_date, :due_type, :priority, 'pending', 'manual');
   ```

## Complete Action

```sql
UPDATE commitments
SET status = 'completed',
    completed_at = datetime('now'),
    updated_at = datetime('now')
WHERE id = :id;
```

Also log activity:
```sql
INSERT INTO activity_timeline (activity_type, entity_type, entity_id, title, project)
VALUES ('commitment_completed', 'commitments', :id, 'Completed: ' || :title, :project);
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

## Output Format

### List
```markdown
# Pending Commitments

## Overdue (2)
- [C-0001] **Fix auth bug** - due Jan 20 (HIGH)
- [C-0002] Review PR - due Jan 22

## Due Today (1)
- [C-0003] Update docs (MEDIUM)

## This Week (3)
- [C-0004] Refactor service - due Jan 28
- [C-0005] Write tests - due Jan 29
- [C-0006] Deploy staging - due Jan 30

## Someday (2)
- [C-0007] Research caching strategies
- [C-0008] Improve logging

---
*Total: 8 pending | Use `/workflow:track complete <id>` to mark done*
```

### Add Confirmation
```markdown
Created commitment:
- **ID:** C-0009
- **Title:** Review new API design
- **Due:** Tomorrow (2024-01-26)
- **Priority:** High
```

### Complete Confirmation
```markdown
Completed: [C-0001] Fix auth bug

Stats:
- Completed today: 3
- Remaining: 7
```
