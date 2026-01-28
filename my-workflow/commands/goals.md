---
name: goals
description: Set and track goals, objectives, and milestones with progress visualization
allowed-tools: Read, Bash, Glob, Grep
---

# Goals Command

Manage objectives, milestones, and habits with progress tracking.

## Usage

```
/workflow:goals                      # List active goals
/workflow:goals add "title"          # Add new goal
/workflow:goals progress G-0001 75   # Update progress to 75%
/workflow:goals complete G-0001      # Mark as completed
/workflow:goals abandon G-0001       # Mark as abandoned
/workflow:goals detail G-0001        # Show goal details
```

## Arguments

- No args or `list` → List active goals with progress
- `add "title"` → Create new goal (prompts for type, timeframe, target)
- `progress <id> <percent>` → Update progress percentage
- `complete <id>` → Mark goal as completed
- `abandon <id>` → Mark goal as abandoned
- `detail <id>` → Show full goal details with history

## Database Location

```bash
DB_PATH="$HOME/.claude/my-workflow/workflow.db"
```

## Goal Types

- **objective** - High-level goal (e.g., "Launch MVP")
- **milestone** - Checkpoint within a larger goal
- **habit** - Recurring behavior to maintain
- **okr** - Objective with Key Results

## List Action

```sql
SELECT
    id, title, goal_type, timeframe,
    progress_percentage, target_date, status,
    parent_goal_id
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

## Add Action

1. Parse title from args
2. Use AskUserQuestion to gather:
   - Goal type (objective, milestone, habit, okr)
   - Timeframe (weekly, monthly, quarterly, yearly)
   - Target date (optional)
   - Target value (if measurable)
   - Parent goal (if milestone)

3. Generate ID and insert:
```sql
INSERT INTO goals (
    id, title, goal_type, timeframe,
    target_date, target_value, target_unit,
    parent_goal_id, status, progress_percentage
) VALUES (
    :id, :title, :goal_type, :timeframe,
    :target_date, :target_value, :target_unit,
    :parent_goal, 'active', 0
);
```

## Progress Action

```sql
UPDATE goals
SET progress_percentage = :percent,
    updated_at = datetime('now')
WHERE id = :id;
```

Also update parent goal progress if this is a milestone:
```sql
-- Recalculate parent progress as average of children
UPDATE goals
SET progress_percentage = (
    SELECT AVG(progress_percentage)
    FROM goals
    WHERE parent_goal_id = :parent_id
),
updated_at = datetime('now')
WHERE id = :parent_id;
```

Log activity:
```sql
INSERT INTO activity_timeline (activity_type, entity_type, entity_id, title, details)
VALUES ('goal_progress', 'goals', :id, 'Updated: ' || :title, '{"progress": ' || :percent || '}');
```

## Output Format

### List
```markdown
# Active Goals

## Objectives

### [G-0001] Launch MVP Product
[==================--] 90% | Target: Feb 1, 2024
└── Milestones:
    - [G-0002] Complete backend API [====================] 100%
    - [G-0003] Frontend integration [================----] 80%
    - [G-0004] Testing & QA [============--------] 60%

### [G-0005] Improve Code Quality
[==========----------] 50% | Quarterly
└── Milestones:
    - [G-0006] Achieve 80% test coverage [========------------] 40%
    - [G-0007] Zero critical bugs [================----] 80%

## Habits

- [G-0010] Daily code review [========] 8/10 this week
- [G-0011] Weekly documentation update [====] 4/4 this month

---
*3 objectives | 4 milestones | 2 habits active*
```

### Add Confirmation
```markdown
Created goal:
- **ID:** G-0012
- **Title:** Implement caching strategy
- **Type:** Milestone
- **Parent:** [G-0005] Improve Code Quality
- **Target:** March 15, 2024
- **Progress:** 0%
```

### Progress Update
```markdown
Updated: [G-0003] Frontend integration

Progress: 75% → 80% (+5%)
[================----] 80%

Parent goal [G-0001] updated: 87% → 90%
```

## Hierarchical Goals

Goals can have parent-child relationships:

```
Objective: Launch MVP (G-0001)
├── Milestone: Backend API (G-0002)
│   ├── Milestone: Auth system (G-0008)
│   └── Milestone: Data layer (G-0009)
├── Milestone: Frontend (G-0003)
└── Milestone: Testing (G-0004)
```

Progress rolls up automatically from children to parents.

## Progress Bar Generation

```python
def progress_bar(percent, width=20):
    filled = int(percent * width / 100)
    empty = width - filled
    return '[' + '=' * filled + '-' * empty + ']'
```
