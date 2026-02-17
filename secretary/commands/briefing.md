---
name: briefing
description: Generate a manual session briefing with pending work, commitments, goals, and GitHub items
allowed-tools: Read, Bash, Glob, Grep
---

# Secretary Briefing Command

Generate a comprehensive briefing for the current session. This produces the same output as the automatic briefing shown on session start (via hooks), but can be triggered manually at any time.

## Usage

```
/secretary:briefing                # Full briefing for current context
/secretary:briefing --project X    # Briefing scoped to project X
```

## Implementation

Run the briefing script with the current session context:

```bash
DB_PATH="$HOME/.claude/secretary/secretary.db"
BRIEFING_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/briefing.sh"

# Verify database exists
if [[ ! -f "$DB_PATH" ]]; then
    echo "Secretary database not initialized. Run /secretary:init first."
    exit 1
fi

# Get current session info
SESSION_ID=$(sqlite3 "$DB_PATH" "SELECT current_session_id FROM state WHERE id = 1" 2>/dev/null)
```

Detect the current project from the working directory:

```bash
PROJECT=$(basename "$(git remote get-url origin 2>/dev/null | sed 's/\.git$//')" 2>/dev/null || basename "$(pwd)")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
```

Run the briefing script:

```bash
bash "$BRIEFING_SCRIPT" "$SESSION_ID" "$PROJECT" "$BRANCH"
```

## What the Briefing Includes

The `scripts/briefing.sh` script generates all sections below using SQL-only queries (no AI calls, completes in under 2 seconds):

### 1. Previous Day Summary (first session of the day only)

If this is the first session today, shows yesterday's daily note summary:
- Sessions count, commits count
- Completed commitments
- Ideas captured
- Decisions made

### 2. Pending Commitments

Grouped by urgency:

**Overdue:**
```sql
SELECT id, title, due_date, priority FROM commitments
WHERE status IN ('pending', 'in_progress')
  AND due_date IS NOT NULL AND due_date < date('now')
ORDER BY due_date ASC LIMIT 5;
```

**Due Today:**
```sql
SELECT id, title, priority FROM commitments
WHERE status IN ('pending', 'in_progress')
  AND due_date = date('now')
ORDER BY priority DESC LIMIT 5;
```

**Upcoming (7 days):**
```sql
SELECT id, title, due_date FROM commitments
WHERE status IN ('pending', 'in_progress')
  AND due_date > date('now')
  AND due_date <= date('now', '+7 days')
ORDER BY due_date ASC LIMIT 5;
```

### 3. Recent Decisions

Active decisions from this project or global, within the configured lookback window:

```sql
SELECT id, title, category FROM decisions
WHERE status = 'active'
  AND (project = :project OR project IS NULL)
  AND created_at >= datetime('now', '-7 days')
ORDER BY created_at DESC LIMIT 5;
```

### 4. Active Goals

Goals with ASCII progress bars:

```sql
SELECT id, title, progress_percentage, target_date FROM goals
WHERE status = 'active'
ORDER BY progress_percentage DESC LIMIT 5;
```

### 5. GitHub Items (from cache)

Reads from `github_cache` table (no API calls during briefing):
- Assigned issues
- PRs needing review
- Your open PRs

### 6. Ideas Inbox

Recently captured ideas not yet triaged:

```sql
SELECT id, title, idea_type FROM ideas
WHERE status = 'captured'
ORDER BY created_at DESC LIMIT 5;
```

### 7. Queue Status

Shows pending queue item count if > 0.

## Output Format

```markdown
# Secretary Briefing

**Session:** 20240217-143022-12345 | **Project:** claude-code-plugins | **Date:** 2024-02-17 (Monday)
**Branch:** feature/secretary

## Yesterday (2024-02-16)
- Sessions: 5 | Commits: 12
- Completed: 3 items
- Ideas captured: 2
- Decisions made: 1

## Commitments

**Overdue:**
- [C-0001] Fix auth bug (due 2024-02-15)
- [C-0002] Review PR #45 (due 2024-02-16)

**Due Today:**
- [C-0003] Update documentation

**Upcoming (7 days):**
- [C-0004] Refactor service (due 2024-02-20)

## Recent Decisions

- [D-0005] Use queue-based architecture (architecture)
- [D-0006] Adopt SQLCipher for memory encryption (technology)

## Active Goals

- [G-0001] Launch MVP [==================--] 90% (target: 2024-03-01)
- [G-0002] Test Coverage [============--------] 60%

## GitHub

**Assigned Issues:**
- #45 Bug: Login timeout (repo-name)

**PRs Needing Review:**
- #67 Add caching layer (other-repo)

## Ideas Inbox

- [I-0012] Add pattern-based recommendations (exploration)
- [I-0013] Vault bi-directional sync (feature)

*3 items pending in queue*

---
*Use `/secretary:status` for full dashboard, `/secretary:track` to manage commitments*
```

## State Update

After generating the briefing, update the last briefing timestamp:

```sql
UPDATE state
SET last_briefing_at = datetime('now'),
    updated_at = datetime('now')
WHERE id = 1;
```

## Notes

- The briefing script exits silently if there is no data to show (e.g., fresh install)
- All data comes from SQL queries, never from AI calls
- The script is the same one used by the `SessionStart` hook for automatic briefings
- Configuration in `~/.claude/secretary.json` controls which sections are included
