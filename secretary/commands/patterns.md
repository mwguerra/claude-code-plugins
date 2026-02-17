---
name: patterns
description: View and analyze detected behavior patterns - productivity insights, workflow habits, and time preferences
allowed-tools: Read, Bash, Glob, Grep
argument-hint: "[analyze|detail <id>|dismiss <id>]"
---

# Secretary Patterns Command

Discover, analyze, and manage workflow patterns detected from your activity data. Patterns reveal behaviors, preferences, productivity rhythms, and tool usage habits.

## Usage

```
/secretary:patterns                     # Show discovered patterns (default)
/secretary:patterns list                # Same as above
/secretary:patterns analyze             # Run pattern discovery on recent data
/secretary:patterns detail P-0001       # Show full pattern details
/secretary:patterns dismiss P-0001      # Dismiss/deactivate a pattern
```

## What Are Patterns?

Patterns are behaviors and tendencies automatically detected from your sessions, commits, decisions, and commitments:

| Type | Description | Example |
|------|-------------|---------|
| behavior | How you work | "Commits in batches of 3-5" |
| preference | What you prefer | "Favors functional programming style" |
| workflow | Process tendencies | "Tests before implementation" |
| time | When you are productive | "Most active between 9-12 AM" |
| tool | Tool usage habits | "Heavy git user, 15+ commits/day" |

## Database Location

```bash
DB_PATH="$HOME/.claude/secretary/secretary.db"

if [[ ! -f "$DB_PATH" ]]; then
    echo "Secretary database not initialized. Run /secretary:init first."
    exit 1
fi
```

## List Action (default)

Show patterns above the configured confidence threshold (default 0.6):

```sql
SELECT
    id, title, description, pattern_type, category,
    confidence, evidence_count,
    first_observed, last_observed
FROM patterns
WHERE status = 'active'
  AND confidence >= 0.6
ORDER BY confidence DESC, evidence_count DESC
LIMIT 20;
```

Also show investigating patterns (below threshold):

```sql
SELECT
    id, title, pattern_type, confidence, evidence_count
FROM patterns
WHERE status = 'active'
  AND confidence < 0.6
ORDER BY evidence_count DESC
LIMIT 5;
```

### List Output

```markdown
# Discovered Patterns

## High Confidence (>80%)

### [P-0001] Morning Productivity Peak
**Type:** time | **Confidence:** 92% | **Evidence:** 45 observations
You complete 60% of commitments between 9-12 AM.

### [P-0002] Test-First Approach
**Type:** workflow | **Confidence:** 85% | **Evidence:** 28 observations
You typically write tests before implementation (75% of features).

## Medium Confidence (60-80%)

### [P-0003] Batch Committing
**Type:** behavior | **Confidence:** 72% | **Evidence:** 15 observations
You tend to make 3-5 commits in quick succession.

### [P-0004] Architecture-Heavy Decisions
**Type:** preference | **Confidence:** 68% | **Evidence:** 23 observations
65% of your decisions are architecture-related.

## Investigating (<60%)

### [P-0005] Weekend Work Sessions
**Type:** time | **Confidence:** 45% | **Evidence:** 6 observations
Some activity detected on weekends (needs more data).

---
*5 patterns active | 1 investigating*
*Use `/secretary:patterns analyze` to run discovery*
```

## Analyze Action

Run pattern discovery algorithms against the last 30 days of data. This queries multiple tables and derives patterns from the results.

### Time Patterns

```sql
-- Session timing by hour
SELECT
    CAST(strftime('%H', started_at) AS INTEGER) as hour,
    COUNT(*) as count,
    AVG(duration_seconds) as avg_duration
FROM sessions
WHERE started_at >= datetime('now', '-30 days')
GROUP BY hour
ORDER BY count DESC;
```

Detect: Most productive hours, morning vs afternoon vs evening preference.

### Day-of-Week Patterns

```sql
SELECT
    strftime('%w', started_at) as day_of_week,
    COUNT(*) as count,
    COALESCE(SUM(duration_seconds), 0) as total_duration
FROM sessions
WHERE started_at >= datetime('now', '-30 days')
GROUP BY day_of_week
ORDER BY count DESC;
```

### Commit Patterns

```sql
-- Commit type distribution
SELECT
    CASE
        WHEN title LIKE 'feat%' THEN 'feature'
        WHEN title LIKE 'fix%' THEN 'bugfix'
        WHEN title LIKE 'refactor%' THEN 'refactor'
        WHEN title LIKE 'docs%' THEN 'docs'
        WHEN title LIKE 'test%' THEN 'test'
        WHEN title LIKE 'chore%' THEN 'chore'
        ELSE 'other'
    END as commit_type,
    COUNT(*) as count
FROM activity_timeline
WHERE activity_type = 'commit'
  AND timestamp >= datetime('now', '-30 days')
GROUP BY commit_type
ORDER BY count DESC;
```

### Commitment Patterns

```sql
-- Completion rate
SELECT
    status,
    COUNT(*) as count,
    AVG(deferred_count) as avg_deferrals
FROM commitments
WHERE created_at >= datetime('now', '-30 days')
GROUP BY status;

-- Average time to complete
SELECT
    AVG(julianday(completed_at) - julianday(created_at)) as avg_days_to_complete
FROM commitments
WHERE completed_at IS NOT NULL
  AND created_at >= datetime('now', '-30 days');
```

### Decision Patterns

```sql
-- Decision categories
SELECT category, COUNT(*) as count
FROM decisions
WHERE created_at >= datetime('now', '-30 days')
  AND status = 'active'
GROUP BY category
ORDER BY count DESC;
```

### Session Length Patterns

```sql
SELECT
    CASE
        WHEN duration_seconds < 1800 THEN 'short'
        WHEN duration_seconds < 7200 THEN 'medium'
        ELSE 'long'
    END as length_category,
    COUNT(*) as count,
    AVG(duration_seconds) as avg_seconds
FROM sessions
WHERE duration_seconds IS NOT NULL
  AND started_at >= datetime('now', '-30 days')
GROUP BY length_category;
```

### Project Focus Patterns

```sql
SELECT
    project,
    COUNT(*) as sessions,
    SUM(duration_seconds) as total_seconds,
    COUNT(DISTINCT date(started_at)) as days_worked
FROM sessions
WHERE started_at >= datetime('now', '-30 days')
GROUP BY project
ORDER BY total_seconds DESC;
```

### Creating or Updating Patterns

When a pattern is detected from analysis, either create a new one or update an existing one:

**Create new pattern:**

```sql
-- Generate next ID
SELECT printf('%s-%04d', 'P', COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 0) + 1)
FROM patterns WHERE id LIKE 'P-%';

INSERT INTO patterns (
    id, title, description, pattern_type, category,
    confidence, evidence_count, evidence_data,
    recommendations, first_observed, last_observed, status
) VALUES (
    :id, :title, :description, :type, :category,
    :confidence, :evidence_count, :evidence_json,
    :recommendations_json, datetime('now'), datetime('now'), 'active'
);
```

**Update existing pattern:**

```sql
UPDATE patterns
SET confidence = :new_confidence,
    evidence_count = evidence_count + :new_evidence,
    evidence_data = :updated_evidence_json,
    last_observed = datetime('now'),
    updated_at = datetime('now')
WHERE id = :id;
```

### Confidence Calculation

Confidence is based on evidence volume and consistency:

```
base = min(evidence_count / 50, 0.5)        # Max 0.5 from volume
consistency = consistency_rate * 0.5         # Max 0.5 from consistency
confidence = base + consistency              # Total: 0.0 to 1.0
```

### Analyze Output

```markdown
# Pattern Analysis Complete

**Period Analyzed:** Last 30 days
**Data Points:** 156 sessions, 342 commits, 89 commitments, 34 decisions

## New Patterns Discovered

### [P-0010] Short Session Preference
**Type:** behavior | **Confidence:** 55%
Average session duration is 45 minutes. 60% of sessions are under 1 hour.
*Based on 156 sessions*

### [P-0011] TypeScript Dominance
**Type:** preference | **Confidence:** 62%
80% of commit activity is in TypeScript/JavaScript projects.
*Based on 342 commits*

## Updated Patterns

| Pattern | Old Confidence | New Confidence | Evidence |
|---------|----------------|----------------|----------|
| [P-0001] Morning Productivity | 92% | 94% | +12 |
| [P-0003] Batch Committing | 72% | 75% | +8 |

## Recommendations

Based on detected patterns:

1. **Schedule deep work in mornings** - Your productivity peaks 9-12 AM (P-0001)
2. **Consider commit splitting** - Batch commits may obscure individual changes (P-0003)
3. **Document decisions earlier** - Only 35% of decisions have recorded rationale (P-0004)
4. **Take breaks** - 20% of sessions exceed 3 hours with declining commit rates (P-0010)

---
*Analysis based on 30-day rolling window*
*Use `/secretary:patterns detail <id>` for full evidence*
```

## Detail Action

Show full details of a specific pattern:

```sql
SELECT * FROM patterns WHERE id = :id;
```

### Detail Output

```markdown
# Pattern: [P-0001] Morning Productivity Peak

- **Type:** time
- **Category:** productivity
- **Confidence:** 94%
- **Status:** Active
- **Evidence:** 45 observations
- **First Observed:** 2024-01-15
- **Last Observed:** 2024-02-17

## Description

You complete 60% of commitments and make 55% of commits between 9 AM and 12 PM.
Sessions started in the morning are 30% longer on average than afternoon sessions.

## Evidence

- 45 morning sessions averaging 72 minutes
- 28 afternoon sessions averaging 55 minutes
- 12 evening sessions averaging 35 minutes
- Morning commitment completion rate: 78%
- Afternoon commitment completion rate: 52%

## Recommendations

- Schedule complex tasks and deep work for morning hours
- Use afternoons for reviews, meetings, and lighter tasks
- Consider blocking 9-12 AM as "focus time"
```

## Dismiss Action

Deactivate a pattern that is no longer relevant:

```sql
UPDATE patterns
SET status = 'dismissed',
    updated_at = datetime('now')
WHERE id = :id;
```

### Dismiss Output

```markdown
Dismissed: [P-0005] Weekend Work Sessions

The pattern will no longer appear in listings.
Remaining active patterns: 4
```

## Error Handling

- If pattern ID not found: "Pattern ':id' not found. Use `/secretary:patterns` to see active patterns."
- If no data for analysis: "Not enough data for pattern analysis. Need at least 7 days of activity."
- If database not initialized: "Secretary database not initialized. Run `/secretary:init` first."
