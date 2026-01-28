---
name: status
description: Display workflow dashboard with current session, pending items, and activity summary
allowed-tools: Read, Bash, Glob, Grep
---

# Workflow Status Command

Display a comprehensive dashboard of your current workflow state.

## Usage

```
/workflow:status                  # Full dashboard
/workflow:status quick            # Quick summary (counts only)
/workflow:status project          # Current project focus
```

## Database Location

```bash
DB_PATH="$HOME/.claude/my-workflow/workflow.db"
```

## Dashboard Sections

### 1. Current Session

```sql
SELECT
    s.id, s.project, s.branch, s.started_at,
    (strftime('%s', 'now') - strftime('%s', s.started_at)) as duration_seconds
FROM sessions s
JOIN state st ON st.current_session_id = s.id
WHERE st.id = 1;
```

### 2. Commitment Summary

```sql
SELECT
    status,
    COUNT(*) as count
FROM commitments
WHERE status NOT IN ('completed', 'canceled')
GROUP BY status;

-- Overdue count
SELECT COUNT(*) as overdue
FROM commitments
WHERE status IN ('pending', 'in_progress')
  AND due_date < date('now');
```

### 3. Recent Activity

```sql
SELECT
    activity_type, title, timestamp
FROM activity_timeline
WHERE timestamp >= datetime('now', '-24 hours')
ORDER BY timestamp DESC
LIMIT 10;
```

### 4. Goal Progress

```sql
SELECT
    id, title, progress_percentage, target_date
FROM goals
WHERE status = 'active'
ORDER BY
    CASE
        WHEN target_date IS NOT NULL AND target_date < date('now', '+7 days') THEN 1
        ELSE 2
    END,
    progress_percentage DESC
LIMIT 5;
```

### 5. Decision Count

```sql
SELECT
    project,
    COUNT(*) as decisions
FROM decisions
WHERE status = 'active'
  AND created_at >= datetime('now', '-7 days')
GROUP BY project;
```

### 6. External Changes

```sql
SELECT COUNT(*) as unacknowledged
FROM external_changes
WHERE acknowledged = 0;
```

### 7. Productivity Stats

```sql
-- Today's stats
SELECT
    COUNT(*) as sessions_today,
    SUM(duration_seconds) as time_today
FROM sessions
WHERE date(started_at) = date('now');

-- This week's stats
SELECT
    COUNT(*) as sessions_week,
    SUM(duration_seconds) as time_week,
    COUNT(DISTINCT project) as projects_week
FROM sessions
WHERE started_at >= datetime('now', '-7 days');
```

## Output Format

### Full Dashboard
```markdown
# Workflow Dashboard

## Current Session

**Project:** claude-code-plugins
**Branch:** feature/my-workflow
**Duration:** 45 minutes
**Session ID:** 20240127-143022-12345

## Commitments

| Status | Count |
|--------|-------|
| Pending | 8 |
| In Progress | 2 |
| **Overdue** | **3** |
| Deferred | 4 |

**Urgent:**
- [C-0001] Fix auth bug - **overdue 2 days**
- [C-0003] Review PR #45 - **due today**

## Goals

| Goal | Progress | Target |
|------|----------|--------|
| [G-0001] Launch MVP | [=========-] 90% | Feb 1 |
| [G-0002] Test Coverage | [======----] 60% | Feb 15 |

## Recent Activity (24h)

- 14:30 - commit: feat: add workflow commands
- 14:15 - decision: Use SQLite for storage
- 13:45 - commitment: Review API design
- 13:30 - session_start: claude-code-plugins
- ... (6 more)

## Decisions This Week

| Project | Count |
|---------|-------|
| claude-code-plugins | 5 |
| api-service | 2 |

## External Changes

**3 unacknowledged changes** - run `/workflow:sync detect`

## Productivity

### Today
- Sessions: 3
- Time: 2h 15m

### This Week
- Sessions: 15
- Time: 18h 30m
- Projects: 4

---
*Dashboard generated at 2024-01-27 14:45*
*Use `/workflow:briefing` for prioritized action items*
```

### Quick Summary
```markdown
# Workflow Quick Status

📊 **Commitments:** 8 pending (3 overdue)
🎯 **Goals:** 2 active (90% and 60%)
📝 **Decisions:** 7 this week
⏱️ **Today:** 3 sessions, 2h 15m
⚠️ **External:** 3 unacknowledged changes
```

### Project Focus
```markdown
# Project: claude-code-plugins

## Session
- Current duration: 45m
- Total today: 2h 15m
- Total this week: 8h 30m

## Commitments (this project)
- Pending: 4
- Overdue: 1
- [C-0012] Implement hook system - due tomorrow

## Decisions (this project)
- [D-0015] Use SQLite storage - today
- [D-0014] Hook-based tracking - yesterday

## Recent Commits
- abc123 feat: add workflow commands
- def456 fix: session tracking
- ghi789 docs: update README

## Goals (this project)
- [G-0005] Complete plugin [======----] 60%
```

## State Persistence

Update last viewed time:
```sql
UPDATE state
SET last_briefing_at = datetime('now'),
    updated_at = datetime('now')
WHERE id = 1;
```
