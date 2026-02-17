---
name: goals
description: Set and track goals, objectives, and milestones with progress visualization
allowed-tools: Read, Bash, Glob, Grep, AskUserQuestion
argument-hint: "<action> [args]"
---

# Secretary Goals Command

Manage objectives, milestones, and habits with progress tracking and hierarchical goal relationships.

## Usage

```
/secretary:goals                         # List active goals (default)
/secretary:goals list                    # Same as above
/secretary:goals add "title"             # Add new goal
/secretary:goals update-progress G-0001 75   # Update progress to 75%
/secretary:goals complete G-0001         # Mark as completed
/secretary:goals abandon G-0001          # Mark as abandoned
/secretary:goals detail G-0001           # Show full goal details
```

## Arguments

Parse the args to determine the action:
- No args or `list` -> List active goals with progress bars
- `add "title"` -> Create new goal (prompts for details)
- `update-progress <id> <percent>` -> Update progress percentage
- `complete <id>` -> Mark goal as completed (100%)
- `abandon <id>` -> Mark goal as abandoned
- `detail <id>` -> Show full goal details with sub-goals

## Database Location

```bash
DB_PATH="$HOME/.claude/secretary/secretary.db"

if [[ ! -f "$DB_PATH" ]]; then
    echo "Secretary database not initialized. Run /secretary:init first."
    exit 1
fi
```

## Goal Types

- **objective** - High-level goal (e.g., "Launch MVP")
- **milestone** - Checkpoint within a larger goal
- **habit** - Recurring behavior to maintain
- **okr** - Objective with Key Results

## Timeframes

- daily, weekly, monthly, quarterly, yearly

## List Action (default)

```sql
SELECT
    id, title, goal_type, timeframe,
    progress_percentage, target_date, target_value,
    current_value, target_unit, status,
    parent_goal_id, project
FROM goals
WHERE status = 'active'
ORDER BY
    CASE goal_type
        WHEN 'objective' THEN 1
        WHEN 'okr' THEN 2
        WHEN 'milestone' THEN 3
        WHEN 'habit' THEN 4
        ELSE 5
    END,
    progress_percentage DESC;
```

Also query sub-goals for hierarchical display:

```sql
SELECT
    id, title, progress_percentage, parent_goal_id
FROM goals
WHERE status = 'active'
  AND parent_goal_id IS NOT NULL
ORDER BY parent_goal_id, progress_percentage DESC;
```

### Progress Bar Generation

Generate ASCII progress bars with 20-character width:

```
filled = floor(progress_percentage * 20 / 100)
empty  = 20 - filled
bar    = '[' + '=' * filled + '-' * empty + ']'
```

Examples:
- 0%:   `[--------------------]`
- 25%:  `[=====---------------]`
- 50%:  `[==========----------]`
- 75%:  `[===============-----]`
- 100%: `[====================]`

### List Output

```markdown
# Active Goals

## Objectives

### [G-0001] Launch MVP Product
[==================--] 90% | Target: Mar 1, 2024
  Milestones:
    - [G-0002] Complete backend API [====================] 100%
    - [G-0003] Frontend integration [================----] 80%
    - [G-0004] Testing & QA [============--------] 60%

### [G-0005] Improve Code Quality
[==========----------] 50% | Quarterly
  Milestones:
    - [G-0006] Achieve 80% test coverage [========------------] 40%
    - [G-0007] Zero critical bugs [================----] 80%

## Habits

- [G-0010] Daily code review [========] 8/10 this week
- [G-0011] Weekly documentation update [====] 4/4 this month

---
*3 objectives | 4 milestones | 2 habits active*
*Use `/secretary:goals update-progress <id> <percent>` to update*
```

## Add Action

1. Parse title from args.
2. Use AskUserQuestion to gather:
   - **Goal type**: objective, milestone, habit, okr
   - **Timeframe**: daily, weekly, monthly, quarterly, yearly
   - **Target date**: optional specific date (YYYY-MM-DD)
   - **Target value** and **unit**: if measurable (e.g., 80 %)
   - **Description**: optional longer description
   - **Parent goal**: if milestone, which parent goal ID
   - **Project**: optional project scope

3. Generate next ID:

```bash
NEXT_ID=$(sqlite3 "$DB_PATH" "
    SELECT printf('%s-%04d', 'G', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1)
    FROM goals WHERE id LIKE 'G-%'
")
```

4. Insert:

```sql
INSERT INTO goals (
    id, title, description, goal_type, timeframe,
    parent_goal_id, project, target_value, target_unit,
    target_date, status, progress_percentage
) VALUES (
    :id, :title, :description, :goal_type, :timeframe,
    :parent_goal_id, :project, :target_value, :target_unit,
    :target_date, 'active', 0
);
```

5. Log activity:

```sql
INSERT INTO activity_timeline (activity_type, entity_type, entity_id, title, project, session_id)
VALUES ('goal_created', 'goals', :id, 'Created goal: ' || :title, :project, :session_id);
```

### Add Output

```markdown
Created goal:
- **ID:** G-0012
- **Title:** Implement caching strategy
- **Type:** Milestone
- **Parent:** [G-0005] Improve Code Quality
- **Target:** March 15, 2024
- **Progress:** [--------------------] 0%
```

## Update Progress Action

1. Parse ID and percentage from args.
2. Validate percentage is 0-100.

```sql
UPDATE goals
SET progress_percentage = :percent,
    current_value = CASE WHEN target_value IS NOT NULL THEN :percent * target_value / 100 ELSE current_value END,
    updated_at = datetime('now')
WHERE id = :id;
```

3. If this goal has a parent, recalculate the parent's progress as the average of all its children:

```sql
UPDATE goals
SET progress_percentage = (
    SELECT COALESCE(AVG(progress_percentage), 0)
    FROM goals
    WHERE parent_goal_id = :parent_id
      AND status = 'active'
),
updated_at = datetime('now')
WHERE id = :parent_id;
```

4. Log activity:

```sql
INSERT INTO activity_timeline (activity_type, entity_type, entity_id, title, details, project, session_id)
VALUES ('goal_progress', 'goals', :id, 'Updated: ' || :title,
        '{"old_progress": ' || :old_percent || ', "new_progress": ' || :new_percent || '}',
        :project, :session_id);
```

### Update Progress Output

```markdown
Updated: [G-0003] Frontend integration

Progress: 75% -> 80% (+5%)
[================----] 80%

Parent goal [G-0001] Launch MVP updated: 87% -> 90%
[==================--] 90%
```

## Complete Action

```sql
UPDATE goals
SET status = 'completed',
    progress_percentage = 100,
    updated_at = datetime('now')
WHERE id = :id;
```

If the goal has a parent, recalculate the parent's progress.

Log activity:

```sql
INSERT INTO activity_timeline (activity_type, entity_type, entity_id, title, project, session_id)
VALUES ('goal_completed', 'goals', :id, 'Completed goal: ' || :title, :project, :session_id);
```

### Complete Output

```markdown
Completed: [G-0002] Complete backend API
[====================] 100%

Parent goal [G-0001] updated: 90% -> 93%
```

## Abandon Action

```sql
UPDATE goals
SET status = 'abandoned',
    updated_at = datetime('now')
WHERE id = :id;
```

Use AskUserQuestion to confirm and optionally ask for a reason.

Log activity:

```sql
INSERT INTO activity_timeline (activity_type, entity_type, entity_id, title, project, session_id)
VALUES ('goal_abandoned', 'goals', :id, 'Abandoned goal: ' || :title, :project, :session_id);
```

## Detail Action

```sql
SELECT * FROM goals WHERE id = :id;
```

Also fetch sub-goals:

```sql
SELECT id, title, progress_percentage, status
FROM goals
WHERE parent_goal_id = :id
ORDER BY
    CASE status WHEN 'active' THEN 0 WHEN 'completed' THEN 1 ELSE 2 END,
    progress_percentage DESC;
```

And related commitments:

```sql
SELECT id, title, status
FROM commitments
WHERE related_commitments LIKE '%' || :goal_id || '%'
   OR id IN (SELECT value FROM json_each(
       (SELECT related_commitments FROM goals WHERE id = :goal_id)
   ))
LIMIT 10;
```

### Detail Output

```markdown
# Goal: [G-0001] Launch MVP Product

- **Type:** Objective
- **Timeframe:** Quarterly
- **Status:** Active
- **Progress:** [==================--] 90%
- **Target Date:** March 1, 2024
- **Project:** my-app
- **Created:** 2024-01-15

## Description

Launch the minimum viable product with core features: auth, dashboard, and API.

## Sub-Goals

| ID | Title | Progress | Status |
|----|-------|----------|--------|
| G-0002 | Complete backend API | [====================] 100% | Completed |
| G-0003 | Frontend integration | [================----] 80% | Active |
| G-0004 | Testing & QA | [============--------] 60% | Active |

## Related Commitments

- [C-0015] Implement auth flow (completed)
- [C-0018] API documentation (pending)
```

## Hierarchical Goals

Goals support parent-child relationships:

```
Objective: Launch MVP (G-0001)
├── Milestone: Backend API (G-0002) - 100%
│   ├── Milestone: Auth system (G-0008)
│   └── Milestone: Data layer (G-0009)
├── Milestone: Frontend (G-0003) - 80%
└── Milestone: Testing (G-0004) - 60%
```

Progress rolls up automatically from children to parents when using `update-progress` or `complete`.

## Error Handling

- If goal ID not found: "Goal ':id' not found. Use `/secretary:goals list` to see active goals."
- If percentage out of range: "Progress must be between 0 and 100."
- If database not initialized: "Secretary database not initialized. Run `/secretary:init` first."
