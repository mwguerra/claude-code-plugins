---
description: Display secretary dashboard with current session, queue depth, commitments, goals, and recent activity
allowed-tools: Read, Bash, Glob, Grep
---

# Secretary Status Command

Display a comprehensive dashboard of your current workflow state, including queue depth, session info, pending commitments, active goals, and recent activity.

## Usage

```
/secretary:status                  # Full dashboard
/secretary:status quick            # Quick summary (counts only)
/secretary:status project          # Current project focus
/secretary:status queue            # Queue-focused view
```

## Database Location

```bash
DB_PATH="$HOME/.claude/secretary/secretary.db"
```

First verify the database exists:

```bash
if [[ ! -f "$DB_PATH" ]]; then
    echo "Secretary database not initialized. Run /secretary:init first."
    exit 1
fi
```

## Dashboard Sections

### 1. Current Session

```sql
SELECT
    s.id, s.project, s.branch, s.directory, s.started_at, s.status,
    (strftime('%s', 'now') - strftime('%s', s.started_at)) as duration_seconds
FROM sessions s
JOIN state st ON st.current_session_id = s.id
WHERE st.id = 1;
```

Format duration as `Xh Ym` or `Ym`.

### 2. Queue Depth

```sql
SELECT
    status,
    COUNT(*) as count
FROM queue
GROUP BY status;
```

Show pending, processing, failed, and expired counts. Highlight if pending > 0 or failed > 0.

Also query worker state:

```sql
SELECT
    last_run_at,
    last_success_at,
    last_error,
    items_processed,
    total_runs
FROM worker_state WHERE id = 1;
```

### 3. Commitment Summary

```sql
-- Active commitments by status
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
  AND due_date IS NOT NULL
  AND due_date < date('now');

-- Urgent items (overdue or due today)
SELECT id, title, due_date, priority
FROM commitments
WHERE status IN ('pending', 'in_progress')
  AND due_date IS NOT NULL
  AND due_date <= date('now')
ORDER BY due_date ASC, priority DESC
LIMIT 5;
```

### 4. Active Goals

```sql
SELECT
    id, title, progress_percentage, target_date, goal_type
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

Display progress bars:
- Filled character: `=`
- Empty character: `-`
- Width: 20 characters
- Formula: `filled = progress_percentage * 20 / 100`

### 5. Recent Activity (Last 10)

```sql
SELECT
    activity_type, entity_id, title, timestamp, project
FROM activity_timeline
ORDER BY timestamp DESC
LIMIT 10;
```

Format as relative time (e.g., "2 hours ago", "yesterday").

### 6. Decisions This Week

```sql
SELECT
    project,
    COUNT(*) as decisions
FROM decisions
WHERE status = 'active'
  AND created_at >= datetime('now', '-7 days')
GROUP BY project;
```

### 7. External Changes

```sql
SELECT COUNT(*) as unacknowledged
FROM external_changes
WHERE acknowledged = 0;
```

### 8. Productivity Stats

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

Format time as `Xh Ym`.

## Output Format

### Full Dashboard

```markdown
# Secretary Dashboard

## Current Session

**Project:** claude-code-plugins
**Branch:** feature/secretary
**Duration:** 45 minutes
**Session ID:** 20240217-143022-12345

## Queue

| Status | Count |
|--------|-------|
| Pending | 3 |
| Processing | 0 |
| Failed | 0 |
| Expired | 12 |

**Worker:** Last run 5 min ago | 142 items processed total | 28 runs

## Commitments

| Status | Count |
|--------|-------|
| Pending | 8 |
| In Progress | 2 |
| Deferred | 4 |
| **Overdue** | **3** |

**Urgent:**
- [C-0001] Fix auth bug - **overdue 2 days** (HIGH)
- [C-0003] Review PR #45 - **due today**

## Goals

| Goal | Progress | Target |
|------|----------|--------|
| [G-0001] Launch MVP | [==================--] 90% | Feb 1 |
| [G-0002] Test Coverage | [============--------] 60% | Feb 15 |

## Recent Activity

| When | Type | Item |
|------|------|------|
| 14:30 | commit | feat: add workflow commands |
| 14:15 | decision | Use SQLite for storage |
| 13:45 | commitment | Review API design |
| 13:30 | session_start | claude-code-plugins |
| ... | | (6 more) |

## Decisions This Week

| Project | Count |
|---------|-------|
| claude-code-plugins | 5 |
| api-service | 2 |

## External Changes

**3 unacknowledged changes** - run `/secretary:sync`

## Productivity

### Today
- Sessions: 3
- Time: 2h 15m

### This Week
- Sessions: 15
- Time: 18h 30m
- Projects: 4

---
*Dashboard generated at 2024-02-17 14:45*
*Use `/secretary:briefing` for prioritized action items*
```

### Quick Summary

```markdown
# Secretary Quick Status

**Queue:** 3 pending | 0 failed
**Commitments:** 8 pending (3 overdue)
**Goals:** 2 active (90% and 60%)
**Decisions:** 7 this week
**Today:** 3 sessions, 2h 15m
**External:** 3 unacknowledged changes
**Worker:** Last run 5 min ago, healthy
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
- [G-0005] Complete plugin [============--------] 60%
```

### Queue View

```markdown
# Secretary Queue Status

## Queue Depth

| Status | Count |
|--------|-------|
| Pending | 3 |
| Processing | 0 |
| Processed | 245 |
| Failed | 1 |
| Expired | 12 |

## Failed Items

| ID | Type | Error | Attempts |
|----|------|-------|----------|
| 42 | user_prompt | AI extraction timeout | 3/3 |

## Worker State

- **Last Run:** 2024-02-17 14:40 (5 min ago)
- **Last Success:** 2024-02-17 14:40
- **Total Runs:** 28
- **Items Processed:** 142
- **Last Error:** None
- **Last Vault Sync:** 2024-02-17 14:25
- **Last GitHub Refresh:** 2024-02-17 14:30

## Pending Items (oldest first)

| ID | Type | Priority | Age |
|----|------|----------|-----|
| 301 | user_prompt | 5 | 2 min |
| 302 | tool_output | 5 | 1 min |
| 303 | commit | 3 | 30 sec |
```
