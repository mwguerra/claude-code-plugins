---
name: sync
description: Detect external changes and sync workflow data with Obsidian vault
allowed-tools: Read, Bash, Glob, Grep
---

# Sync Command

Detect changes made outside Claude Code and sync with Obsidian vault.

## Usage

```
/workflow:sync                    # Full sync (detect + vault)
/workflow:sync detect             # Only detect external changes
/workflow:sync vault              # Only sync to Obsidian vault
/workflow:sync acknowledge        # Mark all changes as seen
/workflow:sync acknowledge X-001  # Mark specific change as seen
```

## Database Location

```bash
DB_PATH="$HOME/.claude/my-workflow/workflow.db"
VAULT_CONFIG="$HOME/.claude/obsidian-vault.json"
```

## External Change Detection

### Git Changes

Detect commits/changes made outside this session:

```bash
# Get commits not logged in our activity_timeline
git log --since="$(sqlite3 $DB_PATH "SELECT MAX(timestamp) FROM activity_timeline WHERE activity_type='commit'")" \
    --format="%H|%h|%s|%an|%ci" 2>/dev/null
```

### File Changes

Track file modification times vs last session:

```bash
# Find files modified since last session
find . -type f -newer "$LAST_SESSION_FILE" \
    -not -path "./.git/*" \
    -not -path "./node_modules/*" \
    2>/dev/null | head -50
```

### GitHub Changes

If gh CLI available, check for new activity:

```bash
# New comments on your PRs
gh api notifications --jq '.[] | select(.reason == "comment") | .subject.title'

# Issues assigned to you (not in our cache)
gh issue list --assignee @me --json number,title,updatedAt
```

## Recording External Changes

```sql
INSERT INTO external_changes (
    id, change_type, source, description,
    details, project, file_path,
    detected_at, relevance_score
) VALUES (
    :id, :type, :source, :description,
    :details_json, :project, :file_path,
    datetime('now'), :relevance
);
```

## Vault Sync

### What Gets Synced

1. **Sessions** → `workflow/sessions/YYYY-MM-DD-*.md`
2. **Decisions** → `workflow/decisions/YYYY-MM-DD-*.md`
3. **Commitments** → `workflow/commitments/*.md`
4. **Reviews** → `workflow/reviews/review-YYYY-MM-DD.md`
5. **Goals** → `workflow/goals/*.md`

### Sync Logic

```bash
VAULT_PATH=$(jq -r '.vaultPath' ~/.claude/obsidian-vault.json)
WORKFLOW_FOLDER="$VAULT_PATH/workflow"

# Ensure folder structure
mkdir -p "$WORKFLOW_FOLDER"/{sessions,decisions,commitments,reviews,goals,patterns}
```

### Session Notes

```sql
SELECT id, project, started_at, ended_at, duration_seconds, summary
FROM sessions
WHERE vault_note_path IS NULL
  AND status = 'completed'
ORDER BY started_at DESC;
```

For each, create note and update `vault_note_path`.

### Decision Notes

```sql
SELECT id, title, description, rationale, category, project, created_at
FROM decisions
WHERE vault_note_path IS NULL
  AND status = 'active'
ORDER BY created_at DESC;
```

Note format:
```markdown
---
title: "{title}"
decision_id: "{id}"
category: "{category}"
project: "{project}"
date: {date}
status: active
tags: [decision, {category}, {project}]
---

# {title}

**Date:** {date}
**Category:** {category}
**Project:** {project}

## Decision

{description}

## Rationale

{rationale}

## Alternatives Considered

{alternatives}

## Consequences

{consequences}
```

### Commitment Notes

Only sync active/pending commitments:

```sql
SELECT id, title, description, due_date, priority, status, stakeholder
FROM commitments
WHERE vault_note_path IS NULL
  AND status NOT IN ('completed', 'canceled')
ORDER BY due_date ASC;
```

## Output Format

### Detect Results
```markdown
# External Changes Detected

## Git (3 commits)

| Hash | Message | Author | When |
|------|---------|--------|------|
| abc123 | fix: resolve timeout | John | 2 hours ago |
| def456 | feat: add caching | John | 3 hours ago |
| ghi789 | docs: update README | Jane | 5 hours ago |

## Files Modified (8)

- `src/api/cache.ts` - modified 2 hours ago
- `src/config/settings.ts` - modified 3 hours ago
- `README.md` - modified 5 hours ago
- ... (5 more)

## GitHub (2 items)

- New comment on PR #45: "Looks good, but..."
- Issue #67 assigned to you: "Bug in login flow"

---
*Use `/workflow:sync acknowledge` to mark as seen*
```

### Vault Sync Results
```markdown
# Vault Sync Complete

## Synced Items

### Sessions (3)
- Created: `workflow/sessions/2024-01-27-1030-claude-code-plugins.md`
- Created: `workflow/sessions/2024-01-27-1400-api-service.md`
- Created: `workflow/sessions/2024-01-27-1630-website.md`

### Decisions (2)
- Created: `workflow/decisions/2024-01-27-use-redis-caching.md`
- Created: `workflow/decisions/2024-01-27-adopt-conventional-commits.md`

### Commitments (5)
- Updated: `workflow/commitments/C-0015-review-api-design.md`
- Created: `workflow/commitments/C-0020-implement-caching.md`
- ... (3 more)

## Skipped (already synced)
- 12 sessions
- 8 decisions
- 15 commitments

---
*Vault location: ~/guerra_vault/workflow/*
```

## Bi-directional Sync (Future)

Eventually support reading changes from vault notes back to DB:
- Parse frontmatter for status changes
- Detect manual edits to descriptions
- Handle deletions/archives
