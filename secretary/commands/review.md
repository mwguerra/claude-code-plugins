---
description: Generate weekly or monthly productivity reviews with metrics, accomplishments, and recommendations
allowed-tools: Read, Bash, Glob, Grep
argument-hint: "[weekly|monthly|custom <days>]"
---

# Secretary Review Command

Generate comprehensive reviews of your workflow activity with productivity metrics, accomplishments, and actionable recommendations.

## Usage

```
/secretary:review                  # Weekly review (default)
/secretary:review weekly           # Explicit weekly review
/secretary:review monthly          # Monthly review (last 30 days)
/secretary:review custom 14        # Custom period (14 days)
```

## Database Location

```bash
DB_PATH="$HOME/.claude/secretary/secretary.db"

if [[ ! -f "$DB_PATH" ]]; then
    echo "Secretary database not initialized. Run /secretary:init first."
    exit 1
fi
```

## Period Calculation

Determine the review period based on the argument:
- `weekly` (default): 7 days
- `monthly`: 30 days
- `custom N`: N days

```bash
DAYS=7
case "$1" in
    monthly) DAYS=30 ;;
    custom)  DAYS="${2:-7}" ;;
    *)       DAYS=7 ;;
esac
```

## Data Queries

### Sessions

```sql
-- Current period
SELECT
    COUNT(*) as total_sessions,
    COALESCE(SUM(duration_seconds), 0) as total_duration,
    COALESCE(AVG(duration_seconds), 0) as avg_duration,
    COUNT(DISTINCT project) as projects_touched,
    COUNT(DISTINCT date(started_at)) as days_active
FROM sessions
WHERE started_at >= datetime('now', '-' || :days || ' days');

-- Previous period (for comparison)
SELECT
    COUNT(*) as total_sessions,
    COALESCE(SUM(duration_seconds), 0) as total_duration
FROM sessions
WHERE started_at >= datetime('now', '-' || (:days * 2) || ' days')
  AND started_at < datetime('now', '-' || :days || ' days');
```

### Commitments

```sql
-- Completed this period
SELECT COUNT(*) as completed
FROM commitments
WHERE completed_at >= datetime('now', '-' || :days || ' days');

-- Created this period
SELECT COUNT(*) as created
FROM commitments
WHERE created_at >= datetime('now', '-' || :days || ' days');

-- Carryover (created before period, still open)
SELECT COUNT(*) as carryover
FROM commitments
WHERE created_at < datetime('now', '-' || :days || ' days')
  AND status NOT IN ('completed', 'canceled');

-- Completed list
SELECT id, title, completed_at
FROM commitments
WHERE completed_at >= datetime('now', '-' || :days || ' days')
ORDER BY completed_at DESC;

-- Carryover list (oldest first)
SELECT id, title, created_at,
    CAST(julianday('now') - julianday(created_at) AS INTEGER) as age_days
FROM commitments
WHERE created_at < datetime('now', '-' || :days || ' days')
  AND status NOT IN ('completed', 'canceled')
ORDER BY created_at ASC
LIMIT 10;
```

### Decisions

```sql
SELECT id, title, category, project, created_at
FROM decisions
WHERE created_at >= datetime('now', '-' || :days || ' days')
  AND status = 'active'
ORDER BY created_at DESC;
```

### Ideas

```sql
SELECT COUNT(*) as ideas_captured
FROM ideas
WHERE created_at >= datetime('now', '-' || :days || ' days');

SELECT id, title, idea_type
FROM ideas
WHERE created_at >= datetime('now', '-' || :days || ' days')
ORDER BY created_at DESC
LIMIT 10;
```

### Goal Progress

```sql
SELECT
    id, title, goal_type,
    progress_percentage as current_progress,
    target_date, status
FROM goals
WHERE status = 'active'
ORDER BY progress_percentage DESC;
```

### Activity Timeline Breakdown

```sql
SELECT
    activity_type,
    COUNT(*) as count
FROM activity_timeline
WHERE timestamp >= datetime('now', '-' || :days || ' days')
GROUP BY activity_type
ORDER BY count DESC;
```

### Project Breakdown

```sql
SELECT
    project,
    COUNT(*) as session_count,
    COALESCE(SUM(duration_seconds), 0) as total_seconds
FROM sessions
WHERE started_at >= datetime('now', '-' || :days || ' days')
  AND project IS NOT NULL
GROUP BY project
ORDER BY total_seconds DESC;
```

### Commit Activity

```sql
SELECT
    project,
    COUNT(*) as commit_count
FROM activity_timeline
WHERE activity_type = 'commit'
  AND timestamp >= datetime('now', '-' || :days || ' days')
GROUP BY project
ORDER BY commit_count DESC;
```

### Productivity Patterns (Time of Day)

```sql
SELECT
    CASE
        WHEN CAST(strftime('%H', started_at) AS INTEGER) BETWEEN 6 AND 11 THEN 'Morning (6-12)'
        WHEN CAST(strftime('%H', started_at) AS INTEGER) BETWEEN 12 AND 17 THEN 'Afternoon (12-18)'
        ELSE 'Evening (18+)'
    END as time_slot,
    COUNT(*) as sessions,
    COALESCE(SUM(duration_seconds), 0) as total_seconds
FROM sessions
WHERE started_at >= datetime('now', '-' || :days || ' days')
GROUP BY time_slot
ORDER BY sessions DESC;
```

### Session Length Distribution

```sql
SELECT
    CASE
        WHEN duration_seconds < 1800 THEN 'Short (<30m)'
        WHEN duration_seconds < 7200 THEN 'Medium (30m-2h)'
        ELSE 'Long (>2h)'
    END as length_category,
    COUNT(*) as count,
    COALESCE(AVG(duration_seconds), 0) as avg_seconds
FROM sessions
WHERE duration_seconds IS NOT NULL
  AND started_at >= datetime('now', '-' || :days || ' days')
GROUP BY length_category;
```

## Output Format

```markdown
# Weekly Workflow Review

**Period:** Feb 10 - Feb 17, 2024
**Generated:** Feb 17, 2024 10:30

## Summary

| Metric | This Week | Previous | Change |
|--------|-----------|----------|--------|
| Sessions | 15 | 12 | +25% |
| Time Invested | 24h 30m | 20h 15m | +21% |
| Commitments Completed | 8 | 6 | +33% |
| Commitments Created | 12 | 8 | +50% |
| Decisions Made | 5 | 3 | +67% |
| Ideas Captured | 7 | 4 | +75% |
| Projects | 3 | 2 | +50% |
| Days Active | 5 | 4 | +25% |

## Commitments

### Completed (8)
- [C-0012] Implemented user auth
- [C-0011] Fixed pagination bug
- [C-0010] Updated API docs
- ... (5 more)

### Created (12)
- [C-0020] Add caching layer
- [C-0019] Refactor services
- ... (10 more)

### Carryover (5)
*Items from previous periods still pending:*
- [C-0005] Review architecture proposal - 14 days old
- [C-0003] Update deployment scripts - 21 days old
- ... (3 more)

## Decisions Made

| ID | Decision | Category | Project |
|----|----------|----------|---------|
| D-0015 | Use Redis for caching | technology | api-service |
| D-0014 | Adopt conventional commits | process | (global) |
| D-0013 | Queue-based architecture | architecture | secretary |

## Ideas Captured (7)

- [I-0020] Pattern-based recommendations (exploration)
- [I-0019] Vault bi-directional sync (feature)
- ... (5 more)

## Goal Progress

- [G-0001] MVP Launch [===================-] 95%  (target: Mar 1)
- [G-0002] Test Coverage [============--------] 60%  (target: Mar 15)
- [G-0003] Documentation [======--------------] 30%  (target: Apr 1)

## Project Breakdown

### claude-code-plugins
- Sessions: 8 | Duration: 14h 20m
- Commits: 23

### api-service
- Sessions: 5 | Duration: 8h 10m
- Commits: 15

### website
- Sessions: 2 | Duration: 2h
- Commits: 5

## Productivity Patterns

### Time of Day
| Time Slot | Sessions | Duration | % of Time |
|-----------|----------|----------|-----------|
| Morning (6-12) | 7 | 12h | 49% |
| Afternoon (12-18) | 6 | 10h | 41% |
| Evening (18+) | 2 | 2h 30m | 10% |

### Session Length
| Category | Count | Avg Duration |
|----------|-------|-------------|
| Short (<30m) | 5 | 18m |
| Medium (30m-2h) | 7 | 1h 15m |
| Long (>2h) | 3 | 3h 20m |

## Activity Breakdown

| Type | Count |
|------|-------|
| commit | 43 |
| decision | 5 |
| commitment_created | 12 |
| commitment_completed | 8 |
| idea | 7 |
| session_start | 15 |
| session_end | 14 |

## Recommendations

Based on this week's activity:

1. **Address Carryover** - 5 items have been pending for 2+ weeks. Consider completing or deferring them.
2. **Goal Focus** - Documentation goal (30%) is lagging behind others. Consider allocating dedicated time.
3. **Commitment Velocity** - Created 12, completed 8. Net backlog grew by 4 items.
4. **Session Pattern** - Most productive in mornings. Schedule deep work during 6-12 AM.

---
*Review generated by Secretary plugin*
*Use `/secretary:goals` to update goal progress*
```

## Vault Sync

If vault integration is enabled, save the review as a vault note:

```bash
VAULT_PATH=$(jq -r '.vaultPath' ~/.claude/obsidian-vault.json 2>/dev/null)
SECRETARY_FOLDER="$VAULT_PATH/secretary/reviews"
mkdir -p "$SECRETARY_FOLDER"

PERIOD_TYPE="weekly"  # or monthly/custom
FILENAME="review-$(date +%Y-%m-%d)-${PERIOD_TYPE}.md"
# Write review markdown content to $SECRETARY_FOLDER/$FILENAME
```

## Generating Recommendations

Analyze the gathered data to produce actionable recommendations:

1. **Carryover Alert**: If carryover > 5, recommend reviewing and clearing old commitments.
2. **Goal Lagging**: If any goal progress < 30% and target_date is within 30 days, flag it.
3. **Commitment Velocity**: If created > completed, note the growing backlog.
4. **Time Distribution**: Identify peak productivity time and suggest scheduling important work then.
5. **Session Length**: If average session < 30 minutes, suggest longer focused sessions. If > 3 hours, suggest breaks.
