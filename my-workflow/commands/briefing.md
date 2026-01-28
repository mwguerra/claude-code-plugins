---
name: briefing
description: Generate an intelligent session briefing with pending work, commitments, and GitHub items
allowed-tools: Read, Bash, Glob, Grep
---

# Workflow Briefing Command

Generate a comprehensive briefing for the current session.

## What to Include

1. **Pending Commitments**
   - Overdue items (red alert)
   - Due today (yellow)
   - Upcoming (next 7 days)

2. **Recent Decisions** (from this project)
   - Active architectural decisions
   - Process decisions that apply

3. **Active Goals**
   - Current progress
   - Milestone status

4. **GitHub Items** (if configured)
   - Assigned issues
   - PRs needing review
   - Your open PRs

5. **External Changes**
   - Changes detected outside Claude Code
   - Unacknowledged items

## Implementation

1. First, check if the database exists:
   ```bash
   DB_PATH="$HOME/.claude/my-workflow/workflow.db"
   if [[ ! -f "$DB_PATH" ]]; then
       echo "Workflow database not initialized. Run /workflow:init first."
       exit 1
   fi
   ```

2. Query each section from SQLite:

   **Commitments:**
   ```sql
   -- Overdue
   SELECT id, title, due_date, priority FROM commitments
   WHERE status IN ('pending', 'in_progress')
     AND due_date IS NOT NULL AND due_date < date('now')
   ORDER BY due_date ASC LIMIT 10;

   -- Due today
   SELECT id, title, priority FROM commitments
   WHERE status IN ('pending', 'in_progress')
     AND due_date = date('now')
   ORDER BY priority DESC LIMIT 10;

   -- Upcoming
   SELECT id, title, due_date FROM commitments
   WHERE status IN ('pending', 'in_progress')
     AND due_date > date('now')
     AND due_date <= date('now', '+7 days')
   ORDER BY due_date ASC LIMIT 10;
   ```

   **Decisions:**
   ```sql
   SELECT id, title, category, created_at FROM decisions
   WHERE status = 'active'
     AND (project = :project OR project IS NULL)
     AND created_at >= datetime('now', '-7 days')
   ORDER BY created_at DESC LIMIT 5;
   ```

   **Goals:**
   ```sql
   SELECT id, title, goal_type, progress_percentage, target_date FROM goals
   WHERE status = 'active'
   ORDER BY progress_percentage DESC LIMIT 5;
   ```

3. For GitHub, check if gh CLI is available and fetch/cache data

4. Format as markdown with clear sections

## Output Format

```markdown
# Workflow Briefing

**Project:** {project}
**Date:** {date}
**Session:** {session_id}

## Attention Needed

### Overdue Commitments
- [C-0001] Fix authentication bug (due 2024-01-20) **OVERDUE**

### Due Today
- [C-0003] Review PR #123

## Active Context

### Recent Decisions
- [D-0005] Using SQLite for workflow storage (architecture)

### Goal Progress
- [G-0001] Complete MVP [=======---] 70%

## GitHub

### Assigned Issues
- #45 Bug: Login timeout (repo-name)

### PRs Needing Review
- #67 Add caching layer (other-repo)

---
*Use `/workflow:track` to manage commitments*
```
