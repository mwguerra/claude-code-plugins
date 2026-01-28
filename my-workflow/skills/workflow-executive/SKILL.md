---
name: workflow-executive
description: Strategic analysis, work prioritization, and productivity recommendations
allowed-tools: Read, Bash, Glob, Grep
---

# Workflow Executive Skill

Analyze productivity, prioritize work, and provide strategic recommendations.

## When to Use

- User asks "What's most important?"
- User asks "How am I doing?"
- User wants productivity analysis
- Generating weekly/monthly reviews
- Detecting bottlenecks or issues
- Recommending focus areas

## Database Location

```bash
DB_PATH="$HOME/.claude/my-workflow/workflow.db"
```

## Work Prioritization

### Priority Scoring

Score each commitment by multiple factors:

```sql
SELECT
    c.id, c.title, c.due_date, c.priority, c.project,
    -- Urgency score (0-100)
    CASE
        WHEN c.due_date < date('now') THEN 100
        WHEN c.due_date = date('now') THEN 80
        WHEN c.due_date <= date('now', '+2 days') THEN 60
        WHEN c.due_date <= date('now', '+7 days') THEN 40
        ELSE 20
    END as urgency,
    -- Priority score (0-40)
    CASE c.priority
        WHEN 'critical' THEN 40
        WHEN 'high' THEN 30
        WHEN 'medium' THEN 20
        ELSE 10
    END as priority_score,
    -- Stakeholder score (0-20)
    CASE WHEN c.stakeholder IS NOT NULL THEN 20 ELSE 0 END as stakeholder_score,
    -- Deferral penalty (-10 per deferral)
    -10 * c.deferred_count as deferral_penalty
FROM commitments c
WHERE c.status IN ('pending', 'in_progress')
ORDER BY (urgency + priority_score + stakeholder_score + deferral_penalty) DESC;
```

### Eisenhower Matrix

Categorize work:

```
URGENT + IMPORTANT     → Do First
NOT URGENT + IMPORTANT → Schedule
URGENT + NOT IMPORTANT → Delegate
NOT URGENT + NOT IMPORTANT → Eliminate
```

## Productivity Analysis

### Session Metrics

```sql
-- Daily summary
SELECT
    date(started_at) as date,
    COUNT(*) as sessions,
    SUM(duration_seconds) / 3600.0 as hours,
    AVG(duration_seconds) / 60.0 as avg_minutes
FROM sessions
WHERE started_at >= datetime('now', '-30 days')
GROUP BY date(started_at);
```

### Completion Rates

```sql
-- Weekly completion rate
SELECT
    strftime('%Y-%W', created_at) as week,
    COUNT(*) as created,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
    ROUND(100.0 * SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) / COUNT(*), 1) as rate
FROM commitments
WHERE created_at >= datetime('now', '-90 days')
GROUP BY week;
```

### Time Distribution

```sql
-- Where is time going?
SELECT
    project,
    SUM(duration_seconds) / 3600.0 as hours,
    ROUND(100.0 * SUM(duration_seconds) / (
        SELECT SUM(duration_seconds) FROM sessions
        WHERE started_at >= datetime('now', '-7 days')
    ), 1) as percentage
FROM sessions
WHERE started_at >= datetime('now', '-7 days')
GROUP BY project
ORDER BY hours DESC;
```

## Goal Tracking

### Progress Velocity

```sql
SELECT
    g.id, g.title, g.progress_percentage, g.target_date,
    julianday(g.target_date) - julianday('now') as days_remaining,
    (100 - g.progress_percentage) / NULLIF(julianday(g.target_date) - julianday('now'), 0) as required_daily_progress,
    CASE
        WHEN g.target_date < date('now') AND g.progress_percentage < 100 THEN 'overdue'
        WHEN (100 - g.progress_percentage) / NULLIF(julianday(g.target_date) - julianday('now'), 0) > 5 THEN 'at_risk'
        WHEN (100 - g.progress_percentage) / NULLIF(julianday(g.target_date) - julianday('now'), 0) > 2 THEN 'needs_attention'
        ELSE 'on_track'
    END as risk_status
FROM goals g
WHERE g.status = 'active' AND g.target_date IS NOT NULL;
```

## Bottleneck Detection

### Long-Pending Items

```sql
SELECT id, title, priority,
    julianday('now') - julianday(created_at) as days_pending
FROM commitments
WHERE status = 'pending'
ORDER BY days_pending DESC
LIMIT 10;
```

### Frequently Deferred

```sql
SELECT id, title, deferred_count
FROM commitments
WHERE deferred_count >= 2
ORDER BY deferred_count DESC;
```

### Blocked Work

```sql
SELECT id, title, notes
FROM commitments
WHERE status = 'blocked';
```

## Pattern Integration

Use detected patterns for recommendations:

```sql
SELECT id, title, pattern_type, confidence, recommendations
FROM patterns
WHERE status = 'active' AND confidence >= 0.6
ORDER BY confidence DESC;
```

Apply insights:
- Productivity timing patterns → scheduling suggestions
- Work style patterns → process recommendations
- Completion patterns → estimation adjustments

## Output Guidelines

### Priority Report

```markdown
# Work Priorities

## Do Today
1. **[C-0001] Fix auth bug** - Overdue, critical
2. **[C-0003] Review PR** - Due today

## Schedule This Week
3. **[G-0002] API integration** - Goal at risk
4. **[C-0005] Update docs** - Low urgency, high value

## Consider Dropping
- [C-0010] Research task - 3x deferred
```

### Strategic Review

```markdown
# Weekly Review

## Metrics
| Metric | This Week | Trend |
|--------|-----------|-------|
| Sessions | 18 | +20% |
| Hours | 24h | +15% |
| Completed | 11 | +37% |

## Concerns
1. Carryover growing - 8 items >2 weeks
2. Goal G-0003 at risk - needs 20%/week

## Recommendations
1. Clear backlog tomorrow (2h)
2. Documentation sprint Wednesday
3. Weekly planning Friday
```

## Recommendation Types

1. **Immediate Actions** - What to do now
2. **Scheduling** - When to do what
3. **Process Changes** - How to improve
4. **Risk Mitigation** - What to watch
5. **Celebration** - What went well

## Error Handling

- Handle empty datasets gracefully
- Provide default recommendations when data is sparse
- Note when analysis is based on limited data
