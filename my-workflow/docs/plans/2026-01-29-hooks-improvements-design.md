# My-Workflow Hooks Improvements Design

**Date:** 2026-01-29
**Status:** Ready for Implementation

## Overview

This design addresses four key issues identified during testing:

1. **Single Item Per Hook** - Hooks only capture first match, missing multiple decisions/ideas/commitments
2. **Scattered SQL Calls** - 50+ direct sqlite3 calls across scripts, no abstraction
3. **Daily Note Not Synced** - Vault daily note is empty template while database has data
4. **Orphaned Sessions** - Sessions stuck as "active" when Claude exits unexpectedly

## Design Decisions

| Issue | Solution | Rationale |
|-------|----------|-----------|
| Multiple items | AI extraction | More accurate at identifying distinct items |
| SQL abstraction | db-helper.sh | Keeps bash stack, easy to debug |
| Daily note sync | Update on each activity | Real-time visibility in Obsidian |
| Orphaned sessions | Process-aware cleanup | Only closes truly orphaned sessions |

---

## Component 1: Database Helper Layer (`db-helper.sh`)

### Purpose
Encapsulate all SQLite operations in typed functions with consistent error handling.

### Functions

```bash
# =============================================================================
# Session Operations
# =============================================================================
db_create_session(session_id, project, directory, branch)
db_update_session(session_id, field, value)
db_close_session(session_id, summary, status)
db_get_session(session_id) -> JSON
db_get_active_sessions(directory) -> JSON array
db_get_current_session_id() -> string

# =============================================================================
# Entity Insert Operations (return new ID)
# =============================================================================
db_insert_decision(title, description, category, rationale, session_id) -> D-XXXX
db_insert_idea(title, description, type, session_id) -> I-XXXX
db_insert_commitment(title, description, priority, due_type, session_id) -> C-XXXX

# =============================================================================
# Entity Query Operations
# =============================================================================
db_get_decision(id) -> JSON
db_get_idea(id) -> JSON
db_get_commitment(id) -> JSON
db_get_today_decisions() -> JSON array
db_get_today_ideas() -> JSON array
db_get_pending_commitments() -> JSON array
db_check_duplicate(table, title, hours_back) -> boolean

# =============================================================================
# Daily Note Operations
# =============================================================================
db_ensure_daily_note(date)
db_update_daily_note(date, field, value)
db_add_daily_decision(date, decision_id)
db_add_daily_idea(date, idea_id)
db_add_daily_session(date, session_id, duration)

# =============================================================================
# Activity Timeline
# =============================================================================
db_log_activity(type, title, entity_type, entity_id, project, metadata_json)

# =============================================================================
# State Management
# =============================================================================
db_get_state(field) -> value
db_set_state(field, value)

# =============================================================================
# Utility
# =============================================================================
db_get_next_id(table, prefix) -> formatted ID
db_exec(sql) -> execute without output
db_query(sql) -> return JSON
db_escape(string) -> SQL-escaped string
```

### Implementation Notes
- All functions source from `hook-utils.sh` for shared config
- JSON output uses `sqlite3 -json` for structured data
- Error handling: functions return non-zero on failure
- Logging: all operations log to debug when WORKFLOW_DEBUG=1

---

## Component 2: AI Multi-Item Extractor (`ai-extractor.sh`)

### Purpose
Use Claude to extract ALL decisions, ideas, and commitments from text in a single call.

### Interface

```bash
# Extract all items from text
# Returns JSON with arrays of each type
ai_extract_all_items(text) -> {
  "decisions": [
    {"title": "...", "category": "...", "rationale": "..."},
    ...
  ],
  "ideas": [
    {"title": "...", "type": "...", "potential": "..."},
    ...
  ],
  "commitments": [
    {"title": "...", "priority": "...", "due_type": "..."},
    ...
  ],
  "language": "en"
}
```

### Prompt Design

```
You are analyzing text to extract ALL decisions, ideas, and commitments.

DECISIONS are choices made between alternatives:
- "decided to", "we'll go with", "the approach is", "chose to"
- Portuguese: "decidi", "vamos usar", "escolhi"
- Spanish: "decidí", "vamos a usar", "elegí"

IDEAS are suggestions or explorations:
- "what if", "how about", "we could", "might be worth"
- Portuguese: "e se", "que tal", "podemos"
- Spanish: "qué tal si", "podríamos"

COMMITMENTS are action items or promises:
- "I need to", "I have to", "I must", "TODO:", "don't forget"
- Portuguese: "preciso", "tenho que", "não esquecer"
- Spanish: "necesito", "tengo que", "no olvidar"

Extract ALL distinct items. Combine related sentences into single items.
Return valid JSON only, no markdown.
```

### Integration
- Called from `capture-decision.sh`, `capture-idea.sh`, `capture-commitment.sh`
- Falls back to pattern matching if AI unavailable
- Deduplication happens at database layer via `db_check_duplicate()`

---

## Component 3: Real-Time Daily Note Sync

### Approach
Update the vault markdown file immediately when any activity is logged.

### New Function in `hook-utils.sh`

```bash
# Append activity to daily note vault file
vault_append_daily_activity(activity_type, title, entity_id, link_path) {
    local vault_path=$(check_vault)
    local daily_file="$vault_path/workflow/daily/$(get_date).md"

    # Ensure file exists with template
    if [[ ! -f "$daily_file" ]]; then
        create_daily_note_template "$daily_file"
    fi

    # Format entry based on type
    local entry
    case "$activity_type" in
        decision)
            entry="- **Decision**: $title [[${link_path}|${entity_id}]]"
            ;;
        idea)
            entry="- **Idea**: $title [[${link_path}|${entity_id}]]"
            ;;
        commitment)
            entry="- **Commitment**: $title [[${link_path}|${entity_id}]]"
            ;;
        session_start)
            entry="- **Session Started**: $title"
            ;;
        session_end)
            entry="- **Session Ended**: $title ($entity_id)"
            ;;
    esac

    # Append to Work Log section
    append_to_section "$daily_file" "## Work Log" "$entry"
}
```

### Section Management

```bash
# Insert content into a specific section of markdown file
append_to_section(file, section_header, content) {
    # Find section, insert before next ## or end of file
    # Uses sed/awk for in-place editing
}
```

---

## Component 4: Smart Session Cleanup

### Process Detection

```bash
# Check if Claude is running for a given directory
is_claude_running_for_directory(directory) {
    pgrep -x "claude" | while read pid; do
        local cwd=$(readlink /proc/$pid/cwd 2>/dev/null)
        # Match if paths overlap (handles subdirectories)
        if [[ "$directory" == "$cwd"* ]] || [[ "$cwd" == "$directory"* ]]; then
            return 0
        fi
    done
    return 1
}
```

### Cleanup on SessionStart

In `session-briefing.sh`:

```bash
# Before creating new session, cleanup orphans
cleanup_orphaned_sessions() {
    local current_dir=$(pwd)
    local project=$(get_project_name)

    # Get all active sessions for this project
    db_get_active_sessions "$project" | jq -r '.[] | "\(.id)|\(.directory)"' | \
    while IFS='|' read -r session_id session_dir; do
        # Skip if Claude is still running for this session
        if is_claude_running_for_directory "$session_dir"; then
            debug_log "Session $session_id still has active Claude process"
            continue
        fi

        # Close orphaned session
        debug_log "Closing orphaned session: $session_id"
        db_close_session "$session_id" "Session interrupted" "interrupted"

        # Update vault note if exists
        vault_mark_session_interrupted "$session_id"
    done
}
```

### Database Schema Addition

Add `directory` column to sessions table:

```sql
ALTER TABLE sessions ADD COLUMN directory TEXT;
CREATE INDEX idx_sessions_directory ON sessions(directory);
```

---

## Component 5: Updated Capture Scripts

### New Flow for `capture-decision.sh` (and similar for idea/commitment)

```bash
#!/bin/bash
source "$SCRIPT_DIR/hook-utils.sh"
source "$SCRIPT_DIR/db-helper.sh"
source "$SCRIPT_DIR/ai-extractor.sh"

# Get input
TOOL_OUTPUT=$(get_tool_output)
[[ -z "$TOOL_OUTPUT" ]] && exit 0

# Try AI extraction for multiple items
if ai_enabled; then
    ITEMS=$(ai_extract_all_items "$TOOL_OUTPUT")

    # Process all decisions
    echo "$ITEMS" | jq -c '.decisions[]' | while read -r decision; do
        title=$(echo "$decision" | jq -r '.title')
        category=$(echo "$decision" | jq -r '.category')
        rationale=$(echo "$decision" | jq -r '.rationale')

        # Check for duplicates
        if db_check_duplicate "decisions" "$title" 1; then
            debug_log "Duplicate decision skipped: $title"
            continue
        fi

        # Insert and get ID
        decision_id=$(db_insert_decision "$title" "$TOOL_OUTPUT" "$category" "$rationale")

        # Create vault note
        create_decision_vault_note "$decision_id" "$title" "$category" "$rationale"

        # Update daily note
        vault_append_daily_activity "decision" "$title" "$decision_id" "workflow/decisions/..."

        debug_log "Created decision: $decision_id"
    done
else
    # Fallback to pattern matching (existing logic but use db-helper)
    # ...
fi
```

---

## Migration Plan

### Step 1: Create db-helper.sh
- Implement all database functions
- Add unit tests
- Keep backward compatibility with existing scripts

### Step 2: Create ai-extractor.sh
- Implement multi-item AI extraction
- Add fallback to pattern matching
- Test with complex multi-item inputs

### Step 3: Add daily note sync
- Implement vault_append_daily_activity
- Update all capture scripts to call it
- Test real-time updates

### Step 4: Add session cleanup
- Add directory column to database
- Implement process detection
- Update session-briefing.sh
- Test with multiple terminals/worktrees

### Step 5: Migrate capture scripts
- Update capture-decision.sh
- Update capture-idea.sh
- Update capture-commitment.sh
- Update capture-user-input.sh
- Update capture-session-summary.sh

### Step 6: Comprehensive testing
- Test all scenarios with complex data
- Test multilingual content
- Test worktree scenarios
- Test crash recovery
- Verify vault notes in Obsidian

---

## Testing Checklist

- [ ] Single decision → creates 1 record + vault note
- [ ] Multiple decisions in one message → creates N records
- [ ] Decision + idea + commitment → creates all 3
- [ ] Portuguese content → correctly detected and saved
- [ ] Spanish content → correctly detected and saved
- [ ] Daily note shows all activities in real-time
- [ ] Session start closes orphaned sessions
- [ ] Parallel terminals don't close each other's sessions
- [ ] Worktree sessions stay independent
- [ ] AI unavailable → pattern matching works
- [ ] Large content (3000+ chars) → handled correctly
- [ ] Special characters in content → properly escaped

---

## Files to Create/Modify

### New Files
- `hooks/scripts/db-helper.sh` - Database abstraction layer
- `hooks/scripts/ai-extractor.sh` - Multi-item AI extraction
- `schemas/migrations/002-add-directory.sql` - Schema migration

### Modified Files
- `hooks/scripts/hook-utils.sh` - Add vault sync functions
- `hooks/scripts/session-briefing.sh` - Add orphan cleanup
- `hooks/scripts/capture-decision.sh` - Use new helpers
- `hooks/scripts/capture-idea.sh` - Use new helpers
- `hooks/scripts/capture-commitment.sh` - Use new helpers
- `hooks/scripts/capture-user-input.sh` - Use new helpers
- `hooks/scripts/capture-session-summary.sh` - Use new helpers
