---
name: executive
description: Strategic analysis, work prioritization, pattern recognition, and productivity reviews for the secretary plugin
allowed-tools: Read, Bash, Glob, Grep
---

# Executive Skill

Analyze productivity, prioritize work, detect patterns, and generate strategic recommendations.

## When to Use

- User asks "What's most important?" or "What should I focus on?"
- User asks "How am I doing?" or "How productive have I been?"
- User wants productivity analysis (daily, weekly, monthly)
- Generating weekly or monthly strategic reviews
- Detecting bottlenecks, stagnation, or work distribution issues
- Recommending focus areas or schedule adjustments
- User asks about patterns or trends in their work
- User wants goal progress assessment or risk analysis

## Database Location

```bash
SECRETARY_DB_PATH="$HOME/.claude/secretary/secretary.db"
```

## Work Prioritization

### Priority Scoring

Score each commitment by multiple weighted factors:

```sql
SELECT
    c.id, c.title, c.due_date, c.priority, c.project, c.stakeholder,
    -- Urgency (0-100)
    CASE
        WHEN c.due_date < date('now') THEN 100
        WHEN c.due_date = date('now') THEN 80
        WHEN c.due_date <= date('now', '+2 days') THEN 60
        WHEN c.due_date <= date('now', '+7 days') THEN 40
        ELSE 20
    END as urgency,
    -- Priority weight (0-40)
    CASE c.priority
        WHEN 'critical' THEN 40
        WHEN 'high' THEN 30
        WHEN 'medium' THEN 20
        ELSE 10
    END as priority_score,
    -- Stakeholder factor (0-20)
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
URGENT + IMPORTANT     -> Do First
NOT URGENT + IMPORTANT -> Schedule
URGENT + NOT IMPORTANT -> Delegate
NOT URGENT + NOT IMPORTANT -> Eliminate
```

## Productivity Analysis

### Session Metrics

```sql
-- Daily summary (last 30 days)
SELECT
    date(started_at) as date,
    COUNT(*) as sessions,
    SUM(duration_seconds) / 3600.0 as hours,
    AVG(duration_seconds) / 60.0 as avg_minutes,
    COUNT(DISTINCT project) as projects
FROM sessions
WHERE started_at >= datetime('now', '-30 days') AND status = 'completed'
GROUP BY date(started_at)
ORDER BY date DESC;
```

### Completion Rates

```sql
-- Weekly completion rate (last 90 days)
SELECT
    strftime('%Y-%W', created_at) as week,
    COUNT(*) as created,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
    ROUND(100.0 * SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) / COUNT(*), 1) as rate,
    SUM(CASE WHEN status = 'deferred' THEN 1 ELSE 0 END) as deferred,
    SUM(CASE WHEN status = 'canceled' THEN 1 ELSE 0 END) as canceled
FROM commitments
WHERE created_at >= datetime('now', '-90 days')
GROUP BY week
ORDER BY week DESC;
```

### Time Distribution

```sql
-- Where is time going? (last 7 days)
SELECT
    project,
    SUM(duration_seconds) / 3600.0 as hours,
    ROUND(100.0 * SUM(duration_seconds) / (
        SELECT SUM(duration_seconds) FROM sessions
        WHERE started_at >= datetime('now', '-7 days') AND status = 'completed'
    ), 1) as percentage,
    COUNT(*) as sessions
FROM sessions
WHERE started_at >= datetime('now', '-7 days') AND status = 'completed'
GROUP BY project
ORDER BY hours DESC;
```

### Decision Velocity

```sql
-- How often decisions are being made
SELECT
    strftime('%Y-%W', created_at) as week,
    COUNT(*) as total,
    SUM(CASE WHEN category = 'architecture' THEN 1 ELSE 0 END) as architecture,
    SUM(CASE WHEN category = 'technology' THEN 1 ELSE 0 END) as technology,
    SUM(CASE WHEN category = 'process' THEN 1 ELSE 0 END) as process,
    SUM(CASE WHEN category = 'design' THEN 1 ELSE 0 END) as design
FROM decisions
WHERE created_at >= datetime('now', '-90 days')
GROUP BY week
ORDER BY week DESC;
```

## Goal Tracking

### Progress Velocity

```sql
SELECT
    g.id, g.title, g.goal_type, g.progress_percentage,
    g.target_date, g.target_value, g.current_value, g.target_unit,
    -- Days remaining
    ROUND(julianday(g.target_date) - julianday('now'), 0) as days_remaining,
    -- Required daily progress
    ROUND((100 - g.progress_percentage) / NULLIF(julianday(g.target_date) - julianday('now'), 0), 2) as required_daily,
    -- Risk status
    CASE
        WHEN g.target_date < date('now') AND g.progress_percentage < 100 THEN 'overdue'
        WHEN (100 - g.progress_percentage) / NULLIF(julianday(g.target_date) - julianday('now'), 0) > 5 THEN 'at_risk'
        WHEN (100 - g.progress_percentage) / NULLIF(julianday(g.target_date) - julianday('now'), 0) > 2 THEN 'needs_attention'
        ELSE 'on_track'
    END as risk_status
FROM goals g
WHERE g.status = 'active' AND g.target_date IS NOT NULL
ORDER BY days_remaining ASC;
```

## Bottleneck Detection

### Long-Pending Items

```sql
SELECT id, title, priority, project,
    ROUND(julianday('now') - julianday(created_at), 0) as days_pending
FROM commitments
WHERE status = 'pending'
ORDER BY days_pending DESC
LIMIT 10;
```

### Frequently Deferred

```sql
SELECT id, title, deferred_count, priority, project
FROM commitments
WHERE deferred_count >= 2
  AND status NOT IN ('completed', 'canceled')
ORDER BY deferred_count DESC;
```

### Blocked Work

```sql
-- Items that have been in_progress for a long time
SELECT id, title, priority, project,
    ROUND(julianday('now') - julianday(updated_at), 0) as days_stale
FROM commitments
WHERE status = 'in_progress'
  AND updated_at < datetime('now', '-7 days')
ORDER BY days_stale DESC;
```

## Pattern Integration

Use detected patterns to inform recommendations:

```sql
SELECT id, title, pattern_type, category, confidence,
    evidence_count, recommendations, frequency
FROM patterns
WHERE status = 'active' AND confidence >= 0.6
ORDER BY confidence DESC, evidence_count DESC;
```

Apply insights:
- **Productivity timing** - Schedule important work during peak hours
- **Work style** - Recommend process improvements
- **Completion patterns** - Adjust estimation and scheduling
- **Context switching** - Recommend focus blocks
- **Deferral patterns** - Flag items that need attention or elimination

## Output Guidelines

### Priority Report

```markdown
# Work Priorities

## Do Today
1. **[C-0001] Fix auth bug** - Overdue, critical
   - Stakeholder: Product team
   - Estimated: 2 hours

2. **[C-0003] Review PR** - Due today
   - Impact: Team velocity

## Schedule This Week
3. **[G-0002] API integration** - Goal at risk (60%)
   - Required: +8%/day
4. **[C-0005] Update docs** - Low urgency, high value

## Consider Dropping
- [C-0010] Research task - 3x deferred, low impact
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
| Decisions | 5 | stable |

## Concerns
1. Carryover growing - 8 items >2 weeks
2. Goal G-0003 at risk - needs 20%/week
3. Context switching - 5 projects in 7 days

## Recommendations
1. Clear backlog tomorrow (2h)
2. Documentation sprint Wednesday
3. Weekly planning Friday

## Wins
- Morning productivity pattern continues
- Test coverage improving steadily
```

## Review Types

### Weekly Focus
- Top 3 priorities for the week
- Carryover items analysis
- Goal trajectory check
- Time allocation review
- Pattern-based scheduling suggestions

### Monthly Strategy
- Progress on major objectives
- Decision patterns analysis (categories, reversal rate)
- Productivity trends (velocity, efficiency)
- Knowledge graph growth
- Recommendation adjustments

## Recommendation Categories

1. **Immediate Actions** - What to do right now
2. **Scheduling** - When to do what, based on data
3. **Process Changes** - How to improve workflows
4. **Risk Mitigation** - What to watch for
5. **Celebration** - What went well (motivation matters)

## Error Handling

- Handle empty datasets gracefully ("Not enough data yet for analysis")
- Provide default recommendations when data is sparse
- Note when analysis is based on limited data
- Degrade gracefully if specific tables have no rows

## Related Commands

- `/secretary:review` - Generate weekly or monthly review
- `/secretary:patterns` - View detected work patterns
- `/secretary:goals` - Manage and track goals
- `/secretary:status` - Full dashboard with metrics
- `/secretary:priorities` - Ranked priority list
