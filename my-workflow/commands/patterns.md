---
name: patterns
description: Discover and manage workflow patterns - behaviors, preferences, and productivity insights
allowed-tools: Read, Bash, Glob, Grep
---

# Patterns Command

Discover, analyze, and manage workflow patterns.

## Usage

```
/workflow:patterns                   # Show discovered patterns
/workflow:patterns analyze           # Run pattern discovery
/workflow:patterns detail P-0001     # Show pattern details
/workflow:patterns dismiss P-0001    # Dismiss/deprecate pattern
```

## What Are Patterns?

Patterns are detected behaviors, preferences, and workflows extracted from your activity:

- **Behavior patterns** - How you work (e.g., "Commits in batches")
- **Preference patterns** - What you prefer (e.g., "Favors functional style")
- **Workflow patterns** - Process tendencies (e.g., "Tests before implementation")
- **Time patterns** - When you're productive (e.g., "Most active mornings")
- **Tool patterns** - Tool usage habits (e.g., "Heavy git user")

## Database Location

```bash
DB_PATH="$HOME/.claude/my-workflow/workflow.db"
```

## List Action (default)

Show patterns above confidence threshold:

```sql
SELECT
    id, title, pattern_type, category,
    confidence, evidence_count,
    last_observed
FROM patterns
WHERE status = 'active'
  AND confidence >= 0.6
ORDER BY confidence DESC, evidence_count DESC
LIMIT 20;
```

## Analyze Action

Run pattern discovery algorithms on recent activity.

### Time Patterns

```sql
-- When are sessions happening?
SELECT
    strftime('%H', started_at) as hour,
    COUNT(*) as count,
    AVG(duration_seconds) as avg_duration
FROM sessions
WHERE started_at >= datetime('now', '-30 days')
GROUP BY hour
ORDER BY count DESC;
```

Detect: Most productive hours, session timing preferences

### Commit Patterns

```sql
-- Commit message patterns
SELECT
    CASE
        WHEN title LIKE 'feat%' THEN 'feature'
        WHEN title LIKE 'fix%' THEN 'bugfix'
        WHEN title LIKE 'refactor%' THEN 'refactor'
        WHEN title LIKE 'docs%' THEN 'docs'
        WHEN title LIKE 'test%' THEN 'test'
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
-- How often are commitments completed vs deferred?
SELECT
    status,
    COUNT(*) as count,
    AVG(deferred_count) as avg_deferrals
FROM commitments
WHERE created_at >= datetime('now', '-30 days')
GROUP BY status;

-- Average time to complete commitments
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
GROUP BY category
ORDER BY count DESC;
```

### Session Patterns

```sql
-- Session length distribution
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

## Pattern Creation

When a pattern is detected:

```sql
INSERT INTO patterns (
    id, title, description, pattern_type, category,
    confidence, evidence_count, evidence_data,
    first_observed, last_observed, status
) VALUES (
    :id, :title, :description, :type, :category,
    :confidence, :evidence_count, :evidence_json,
    datetime('now'), datetime('now'), 'active'
);
```

Or update existing pattern:
```sql
UPDATE patterns
SET confidence = :new_confidence,
    evidence_count = evidence_count + 1,
    evidence_data = :updated_evidence,
    last_observed = datetime('now'),
    updated_at = datetime('now')
WHERE id = :id;
```

## Output Format

### List
```markdown
# Discovered Patterns

## High Confidence (>80%)

### [P-0001] Morning Productivity Peak
**Type:** Time | **Confidence:** 92%
You complete 60% of commitments between 9-12 AM.
*Based on 45 observations*

### [P-0002] Test-First Approach
**Type:** Workflow | **Confidence:** 85%
You typically write tests before implementation (75% of features).
*Based on 28 observations*

## Medium Confidence (60-80%)

### [P-0003] Batch Committing
**Type:** Behavior | **Confidence:** 72%
You tend to make 3-5 commits in quick succession.
*Based on 15 observations*

### [P-0004] Architecture-Heavy Decisions
**Type:** Preference | **Confidence:** 68%
65% of your decisions are architecture-related.
*Based on 23 observations*

## Investigating (<60%)

### [P-0005] Weekend Work Sessions
**Type:** Time | **Confidence:** 45%
Some activity detected on weekends (needs more data).
*Based on 6 observations*

---
*5 patterns active | Last analysis: 2 hours ago*
```

### Analyze Output
```markdown
# Pattern Analysis Complete

**Period Analyzed:** Last 30 days
**Data Points:** 156 sessions, 342 commits, 89 commitments

## New Patterns Discovered

- [P-0010] Short session preference (avg 45 min)
- [P-0011] TypeScript dominance (80% of files)

## Updated Patterns

- [P-0001] Morning productivity: 92% → 94% confidence
- [P-0003] Batch committing: 72% → 75% confidence

## Recommendations

Based on patterns:

1. **Schedule deep work in mornings** - Your productivity peaks 9-12 AM
2. **Consider commit splitting** - Batch commits may obscure changes
3. **Document decisions earlier** - Only 35% have recorded rationale
```

## Confidence Calculation

```python
# Simple confidence based on evidence and consistency
def calculate_confidence(evidence_count, consistency_rate):
    base = min(evidence_count / 50, 0.5)  # Max 0.5 from evidence count
    consistency = consistency_rate * 0.5   # Max 0.5 from consistency
    return base + consistency
```
