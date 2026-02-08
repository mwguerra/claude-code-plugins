#!/usr/bin/env bash
# migrate-v1-to-v2.sh - Migrate taskmanager from JSON v1 to SQLite v2
#
# Usage: migrate-v1-to-v2.sh [TASKMANAGER_DIR]
#   TASKMANAGER_DIR: Path to .taskmanager directory (default: .taskmanager)
#
# This script migrates:
#   - tasks.json -> tasks table (flattened hierarchy with parent_id)
#   - tasks-archive.json -> tasks table (with archived_at set)
#   - memories.json -> memories table
#   - state.json -> state table
#
# Original files are backed up to backup-v1/

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASKMANAGER_DIR="${1:-.taskmanager}"
DB_FILE="$TASKMANAGER_DIR/taskmanager.db"
BACKUP_DIR="$TASKMANAGER_DIR/backup-v1"
LOG_FILE="$TASKMANAGER_DIR/migration.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TASKS_MIGRATED=0
ARCHIVED_MIGRATED=0
MEMORIES_MIGRATED=0

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    local msg="$1"
    echo -e "${BLUE}[INFO]${NC} $msg"
    echo "[$(date -Iseconds)] INFO: $msg" >> "$LOG_FILE"
}

log_warn() {
    local msg="$1"
    echo -e "${YELLOW}[WARN]${NC} $msg" >&2
    echo "[$(date -Iseconds)] WARN: $msg" >> "$LOG_FILE"
}

log_error() {
    local msg="$1"
    echo -e "${RED}[ERROR]${NC} $msg" >&2
    echo "[$(date -Iseconds)] ERROR: $msg" >> "$LOG_FILE"
}

log_success() {
    local msg="$1"
    echo -e "${GREEN}[OK]${NC} $msg"
    echo "[$(date -Iseconds)] OK: $msg" >> "$LOG_FILE"
}

# ============================================================================
# Prerequisite Checks
# ============================================================================

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check for sqlite3
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3 is not installed. Please install it first."
        exit 1
    fi
    log_info "  sqlite3: $(sqlite3 --version | head -1)"

    # Check for jq
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install it first."
        exit 1
    fi
    log_info "  jq: $(jq --version)"

    # Check taskmanager directory exists
    if [[ ! -d "$TASKMANAGER_DIR" ]]; then
        log_error "Taskmanager directory not found: $TASKMANAGER_DIR"
        exit 1
    fi
    log_info "  Directory: $TASKMANAGER_DIR"

    # Check if database already exists
    if [[ -f "$DB_FILE" ]]; then
        log_error "Database already exists: $DB_FILE"
        log_error "If you want to re-migrate, remove the database first."
        exit 1
    fi

    # Check for source JSON files
    local has_tasks=false
    local has_archive=false
    local has_memories=false
    local has_state=false

    [[ -f "$TASKMANAGER_DIR/tasks.json" ]] && has_tasks=true
    [[ -f "$TASKMANAGER_DIR/tasks-archive.json" ]] && has_archive=true
    [[ -f "$TASKMANAGER_DIR/memories.json" ]] && has_memories=true
    [[ -f "$TASKMANAGER_DIR/state.json" ]] && has_state=true

    if [[ "$has_tasks" == "false" && "$has_archive" == "false" && "$has_memories" == "false" && "$has_state" == "false" ]]; then
        log_error "No JSON files found to migrate"
        exit 1
    fi

    log_info "  tasks.json: $has_tasks"
    log_info "  tasks-archive.json: $has_archive"
    log_info "  memories.json: $has_memories"
    log_info "  state.json: $has_state"

    log_success "Prerequisites check passed"
}

# ============================================================================
# Database Creation
# ============================================================================

create_database() {
    log_info "Creating database with schema..."

    # Find schema.sql
    local schema_file="$SCRIPT_DIR/schema.sql"
    if [[ ! -f "$schema_file" ]]; then
        log_error "Schema file not found: $schema_file"
        exit 1
    fi

    # Create database and apply schema
    sqlite3 "$DB_FILE" < "$schema_file"

    if [[ $? -eq 0 ]]; then
        log_success "Database created: $DB_FILE"
    else
        log_error "Failed to create database"
        exit 1
    fi
}

# ============================================================================
# Task Migration (Recursive Flattening)
# ============================================================================

# Insert a single task into the database
insert_task() {
    local json="$1"
    local parent_id="$2"
    local archived_at="$3"

    # Extract fields from JSON
    local id=$(echo "$json" | jq -r '.id // empty')
    local title=$(echo "$json" | jq -r '.title // empty')
    local description=$(echo "$json" | jq -r '.description // empty')
    local details=$(echo "$json" | jq -r '.details // empty')
    local test_strategy=$(echo "$json" | jq -r '.testStrategy // empty')
    local status=$(echo "$json" | jq -r '.status // "planned"')
    local type=$(echo "$json" | jq -r '.type // "feature"')
    local priority=$(echo "$json" | jq -r '.priority // "medium"')

    # Complexity fields
    local complexity_score=$(echo "$json" | jq -r '.complexity.score // empty')
    local complexity_scale=$(echo "$json" | jq -r '.complexity.scale // empty')
    local complexity_reasoning=$(echo "$json" | jq -r '.complexity.reasoning // empty')
    local complexity_expansion_prompt=$(echo "$json" | jq -r '.complexity.expansionPrompt // empty')

    # Time fields
    local estimate_seconds=$(echo "$json" | jq -r '.estimateSeconds // empty')
    local duration_seconds=$(echo "$json" | jq -r '.durationSeconds // empty')
    local owner=$(echo "$json" | jq -r '.owner // empty')

    # Writing domain fields
    local domain=$(echo "$json" | jq -r '.domain // "software"')
    local writing_type=$(echo "$json" | jq -r '.writingType // empty')
    local content_unit=$(echo "$json" | jq -r '.contentUnit // empty')
    local writing_stage=$(echo "$json" | jq -r '.writingStage // empty')
    local target_word_count=$(echo "$json" | jq -r '.targetWordCount // empty')
    local current_word_count=$(echo "$json" | jq -r '.currentWordCount // empty')

    # Timestamps
    local created_at=$(echo "$json" | jq -r '.createdAt // empty')
    local updated_at=$(echo "$json" | jq -r '.updatedAt // empty')
    local started_at=$(echo "$json" | jq -r '.startedAt // empty')
    local completed_at=$(echo "$json" | jq -r '.completedAt // empty')

    # JSON fields
    local tags=$(echo "$json" | jq -c '.tags // []')
    local dependencies=$(echo "$json" | jq -c '.dependencies // []')
    local dependency_analysis=$(echo "$json" | jq -c '.dependencyAnalysis // empty')
    local meta=$(echo "$json" | jq -c '.meta // {}')

    # Skip if no ID
    if [[ -z "$id" ]]; then
        log_warn "Skipping task without ID"
        return
    fi

    # Handle nulls for SQL
    [[ "$parent_id" == "null" || -z "$parent_id" ]] && parent_id=""
    [[ "$description" == "null" ]] && description=""
    [[ "$details" == "null" ]] && details=""
    [[ "$test_strategy" == "null" ]] && test_strategy=""
    [[ "$complexity_score" == "null" ]] && complexity_score=""
    [[ "$complexity_scale" == "null" ]] && complexity_scale=""
    [[ "$complexity_reasoning" == "null" ]] && complexity_reasoning=""
    [[ "$complexity_expansion_prompt" == "null" ]] && complexity_expansion_prompt=""
    [[ "$estimate_seconds" == "null" ]] && estimate_seconds=""
    [[ "$duration_seconds" == "null" ]] && duration_seconds=""
    [[ "$owner" == "null" ]] && owner=""
    [[ "$writing_type" == "null" ]] && writing_type=""
    [[ "$content_unit" == "null" ]] && content_unit=""
    [[ "$writing_stage" == "null" ]] && writing_stage=""
    [[ "$target_word_count" == "null" ]] && target_word_count=""
    [[ "$current_word_count" == "null" ]] && current_word_count=""
    [[ "$created_at" == "null" ]] && created_at=""
    [[ "$updated_at" == "null" ]] && updated_at=""
    [[ "$started_at" == "null" ]] && started_at=""
    [[ "$completed_at" == "null" ]] && completed_at=""
    [[ "$archived_at" == "null" ]] && archived_at=""
    [[ "$dependency_analysis" == "null" ]] && dependency_analysis=""

    # Escape single quotes for SQL
    title="${title//\'/\'\'}"
    description="${description//\'/\'\'}"
    details="${details//\'/\'\'}"
    test_strategy="${test_strategy//\'/\'\'}"
    complexity_reasoning="${complexity_reasoning//\'/\'\'}"
    complexity_expansion_prompt="${complexity_expansion_prompt//\'/\'\'}"
    owner="${owner//\'/\'\'}"
    writing_type="${writing_type//\'/\'\'}"
    content_unit="${content_unit//\'/\'\'}"
    writing_stage="${writing_stage//\'/\'\'}"
    dependency_analysis="${dependency_analysis//\'/\'\'}"

    # Build SQL INSERT
    sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO tasks (
    id, parent_id, title, description, details, test_strategy,
    status, type, priority,
    complexity_score, complexity_scale, complexity_reasoning, complexity_expansion_prompt,
    estimate_seconds, duration_seconds, owner,
    domain, writing_type, content_unit, writing_stage,
    target_word_count, current_word_count,
    created_at, updated_at, started_at, completed_at, archived_at,
    tags, dependencies, dependency_analysis, meta
) VALUES (
    '${id}',
    $([ -n "$parent_id" ] && echo "'$parent_id'" || echo "NULL"),
    '${title}',
    $([ -n "$description" ] && echo "'$description'" || echo "NULL"),
    $([ -n "$details" ] && echo "'$details'" || echo "NULL"),
    $([ -n "$test_strategy" ] && echo "'$test_strategy'" || echo "NULL"),
    '${status}',
    '${type}',
    '${priority}',
    $([ -n "$complexity_score" ] && echo "$complexity_score" || echo "NULL"),
    $([ -n "$complexity_scale" ] && echo "'$complexity_scale'" || echo "NULL"),
    $([ -n "$complexity_reasoning" ] && echo "'$complexity_reasoning'" || echo "NULL"),
    $([ -n "$complexity_expansion_prompt" ] && echo "'$complexity_expansion_prompt'" || echo "NULL"),
    $([ -n "$estimate_seconds" ] && echo "$estimate_seconds" || echo "NULL"),
    $([ -n "$duration_seconds" ] && echo "$duration_seconds" || echo "NULL"),
    $([ -n "$owner" ] && echo "'$owner'" || echo "NULL"),
    '${domain}',
    $([ -n "$writing_type" ] && echo "'$writing_type'" || echo "NULL"),
    $([ -n "$content_unit" ] && echo "'$content_unit'" || echo "NULL"),
    $([ -n "$writing_stage" ] && echo "'$writing_stage'" || echo "NULL"),
    $([ -n "$target_word_count" ] && echo "$target_word_count" || echo "NULL"),
    $([ -n "$current_word_count" ] && echo "$current_word_count" || echo "NULL"),
    $([ -n "$created_at" ] && echo "'$created_at'" || echo "datetime('now')"),
    $([ -n "$updated_at" ] && echo "'$updated_at'" || echo "datetime('now')"),
    $([ -n "$started_at" ] && echo "'$started_at'" || echo "NULL"),
    $([ -n "$completed_at" ] && echo "'$completed_at'" || echo "NULL"),
    $([ -n "$archived_at" ] && echo "'$archived_at'" || echo "NULL"),
    '${tags}',
    '${dependencies}',
    $([ -n "$dependency_analysis" ] && echo "'$dependency_analysis'" || echo "NULL"),
    '${meta}'
);
EOF

    if [[ $? -eq 0 ]]; then
        ((TASKS_MIGRATED++))
    else
        log_warn "Failed to insert task: $id"
    fi
}

# Recursively process tasks and subtasks
process_tasks_recursive() {
    local tasks_json="$1"
    local parent_id="$2"
    local archived_at="$3"

    # Get number of tasks
    local count=$(echo "$tasks_json" | jq 'length')

    for ((i=0; i<count; i++)); do
        local task=$(echo "$tasks_json" | jq ".[$i]")
        local task_id=$(echo "$task" | jq -r '.id')

        # Insert this task
        insert_task "$task" "$parent_id" "$archived_at"

        # Process subtasks recursively
        local subtasks=$(echo "$task" | jq '.subtasks // []')
        local subtask_count=$(echo "$subtasks" | jq 'length')

        if [[ $subtask_count -gt 0 ]]; then
            process_tasks_recursive "$subtasks" "$task_id" "$archived_at"
        fi
    done
}

migrate_tasks() {
    local tasks_file="$TASKMANAGER_DIR/tasks.json"

    if [[ ! -f "$tasks_file" ]]; then
        log_warn "tasks.json not found, skipping task migration"
        return
    fi

    log_info "Migrating tasks from tasks.json..."

    # Validate JSON
    if ! jq empty "$tasks_file" 2>/dev/null; then
        log_error "Invalid JSON in tasks.json"
        return 1
    fi

    # Get tasks array
    local tasks=$(jq '.tasks // []' "$tasks_file")
    local task_count=$(echo "$tasks" | jq 'length')

    log_info "  Found $task_count top-level tasks"

    # Process all tasks recursively
    process_tasks_recursive "$tasks" "" ""

    log_success "Migrated $TASKS_MIGRATED tasks from tasks.json"
}

# ============================================================================
# Archive Migration
# ============================================================================

migrate_archive() {
    local archive_file="$TASKMANAGER_DIR/tasks-archive.json"

    if [[ ! -f "$archive_file" ]]; then
        log_warn "tasks-archive.json not found, skipping archive migration"
        return
    fi

    log_info "Migrating tasks from tasks-archive.json..."

    # Validate JSON
    if ! jq empty "$archive_file" 2>/dev/null; then
        log_error "Invalid JSON in tasks-archive.json"
        return 1
    fi

    # Get archived tasks
    local tasks=$(jq '.tasks // []' "$archive_file")
    local task_count=$(echo "$tasks" | jq 'length')

    log_info "  Found $task_count archived tasks"

    # Get last updated timestamp or use now
    local archived_at=$(jq -r '.lastUpdated // empty' "$archive_file")
    [[ -z "$archived_at" || "$archived_at" == "null" ]] && archived_at=$(date -Iseconds)

    # Reset counter for archive
    local pre_count=$TASKS_MIGRATED

    # Process all archived tasks recursively
    process_tasks_recursive "$tasks" "" "$archived_at"

    ARCHIVED_MIGRATED=$((TASKS_MIGRATED - pre_count))
    log_success "Migrated $ARCHIVED_MIGRATED tasks from tasks-archive.json"
}

# ============================================================================
# Memory Migration
# ============================================================================

migrate_memories() {
    local memories_file="$TASKMANAGER_DIR/memories.json"

    if [[ ! -f "$memories_file" ]]; then
        log_warn "memories.json not found, skipping memory migration"
        return
    fi

    log_info "Migrating memories from memories.json..."

    # Validate JSON
    if ! jq empty "$memories_file" 2>/dev/null; then
        log_error "Invalid JSON in memories.json"
        return 1
    fi

    # Get memories array
    local memories=$(jq '.memories // []' "$memories_file")
    local memory_count=$(echo "$memories" | jq 'length')

    log_info "  Found $memory_count memories"

    for ((i=0; i<memory_count; i++)); do
        local memory=$(echo "$memories" | jq ".[$i]")

        # Extract fields
        local id=$(echo "$memory" | jq -r '.id // empty')
        local title=$(echo "$memory" | jq -r '.title // empty')
        local kind=$(echo "$memory" | jq -r '.kind // "other"')
        local why_important=$(echo "$memory" | jq -r '.whyImportant // empty')
        local body=$(echo "$memory" | jq -r '.body // empty')

        # Source fields
        local source_type=$(echo "$memory" | jq -r '.source.type // "other"')
        local source_name=$(echo "$memory" | jq -r '.source.name // empty')
        local source_via=$(echo "$memory" | jq -r '.source.via // empty')
        local auto_updatable=$(echo "$memory" | jq -r '.autoUpdatable // true')

        # Scoring
        local importance=$(echo "$memory" | jq -r '.importance // 3')
        local confidence=$(echo "$memory" | jq -r '.confidence // 0.8')
        local status=$(echo "$memory" | jq -r '.status // "active"')
        local superseded_by=$(echo "$memory" | jq -r '.supersededBy // empty')

        # JSON fields
        local scope=$(echo "$memory" | jq -c '.scope // {}')
        local tags=$(echo "$memory" | jq -c '.tags // []')
        local links=$(echo "$memory" | jq -c '.links // []')

        # Usage
        local use_count=$(echo "$memory" | jq -r '.useCount // 0')
        local last_used_at=$(echo "$memory" | jq -r '.lastUsedAt // empty')
        local last_conflict_at=$(echo "$memory" | jq -r '.lastConflictAt // empty')
        local conflict_resolutions=$(echo "$memory" | jq -c '.conflictResolutions // []')

        # Timestamps
        local created_at=$(echo "$memory" | jq -r '.createdAt // empty')
        local updated_at=$(echo "$memory" | jq -r '.updatedAt // empty')

        # Skip if no ID
        if [[ -z "$id" ]]; then
            log_warn "Skipping memory without ID"
            continue
        fi

        # Handle nulls
        [[ "$why_important" == "null" ]] && why_important=""
        [[ "$source_name" == "null" ]] && source_name=""
        [[ "$source_via" == "null" ]] && source_via=""
        [[ "$superseded_by" == "null" ]] && superseded_by=""
        [[ "$last_used_at" == "null" ]] && last_used_at=""
        [[ "$last_conflict_at" == "null" ]] && last_conflict_at=""
        [[ "$created_at" == "null" ]] && created_at=""
        [[ "$updated_at" == "null" ]] && updated_at=""

        # Convert boolean to integer
        [[ "$auto_updatable" == "true" ]] && auto_updatable=1 || auto_updatable=0

        # Escape single quotes
        title="${title//\'/\'\'}"
        why_important="${why_important//\'/\'\'}"
        body="${body//\'/\'\'}"
        source_name="${source_name//\'/\'\'}"
        source_via="${source_via//\'/\'\'}"

        # Insert memory
        sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO memories (
    id, title, kind, why_important, body,
    source_type, source_name, source_via, auto_updatable,
    importance, confidence, status, superseded_by,
    scope, tags, links,
    use_count, last_used_at, last_conflict_at, conflict_resolutions,
    created_at, updated_at
) VALUES (
    '${id}',
    '${title}',
    '${kind}',
    '${why_important}',
    '${body}',
    '${source_type}',
    $([ -n "$source_name" ] && echo "'$source_name'" || echo "NULL"),
    $([ -n "$source_via" ] && echo "'$source_via'" || echo "NULL"),
    ${auto_updatable},
    ${importance},
    ${confidence},
    '${status}',
    $([ -n "$superseded_by" ] && echo "'$superseded_by'" || echo "NULL"),
    '${scope}',
    '${tags}',
    '${links}',
    ${use_count},
    $([ -n "$last_used_at" ] && echo "'$last_used_at'" || echo "NULL"),
    $([ -n "$last_conflict_at" ] && echo "'$last_conflict_at'" || echo "NULL"),
    '${conflict_resolutions}',
    $([ -n "$created_at" ] && echo "'$created_at'" || echo "datetime('now')"),
    $([ -n "$updated_at" ] && echo "'$updated_at'" || echo "datetime('now')")
);
EOF

        if [[ $? -eq 0 ]]; then
            ((MEMORIES_MIGRATED++))
        else
            log_warn "Failed to insert memory: $id"
        fi
    done

    log_success "Migrated $MEMORIES_MIGRATED memories"
}

# ============================================================================
# State Migration
# ============================================================================

migrate_state() {
    local state_file="$TASKMANAGER_DIR/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_warn "state.json not found, skipping state migration"
        return
    fi

    log_info "Migrating state from state.json..."

    # Validate JSON
    if ! jq empty "$state_file" 2>/dev/null; then
        log_error "Invalid JSON in state.json"
        return 1
    fi

    # Extract state fields
    local current_task_id=$(jq -r '.currentTaskId // empty' "$state_file")
    local current_subtask_path=$(jq -r '.currentSubtaskPath // empty' "$state_file")
    local current_step=$(jq -r '.currentStep // "idle"' "$state_file")
    local mode=$(jq -r '.mode // "interactive"' "$state_file")
    local started_at=$(jq -r '.startedAt // empty' "$state_file")
    local last_update=$(jq -r '.lastUpdate // empty' "$state_file")

    # JSON fields
    local evidence=$(jq -c '.evidence // {}' "$state_file")
    local verifications_passed=$(jq -c '.verificationsPassed // {}' "$state_file")
    local task_memory=$(jq -c '.taskMemory // []' "$state_file")
    local applied_memories=$(jq -c '.appliedMemories // []' "$state_file")

    # Logging fields
    local debug_enabled=$(jq -r '.logging.debugEnabled // false' "$state_file")
    local session_id=$(jq -r '.logging.sessionId // empty' "$state_file")

    # Handle nulls
    [[ "$current_task_id" == "null" ]] && current_task_id=""
    [[ "$current_subtask_path" == "null" ]] && current_subtask_path=""
    [[ "$started_at" == "null" ]] && started_at=""
    [[ "$last_update" == "null" ]] && last_update=""
    [[ "$session_id" == "null" ]] && session_id=""

    # Convert boolean to integer
    [[ "$debug_enabled" == "true" ]] && debug_enabled=1 || debug_enabled=0

    # Update state table (row already exists from schema initialization)
    sqlite3 "$DB_FILE" <<EOF
UPDATE state SET
    current_task_id = $([ -n "$current_task_id" ] && echo "'$current_task_id'" || echo "NULL"),
    current_subtask_path = $([ -n "$current_subtask_path" ] && echo "'$current_subtask_path'" || echo "NULL"),
    current_step = '${current_step}',
    mode = '${mode}',
    started_at = $([ -n "$started_at" ] && echo "'$started_at'" || echo "NULL"),
    last_update = $([ -n "$last_update" ] && echo "'$last_update'" || echo "NULL"),
    evidence = '${evidence}',
    verifications_passed = '${verifications_passed}',
    task_memory = '${task_memory}',
    applied_memories = '${applied_memories}',
    debug_enabled = ${debug_enabled},
    session_id = $([ -n "$session_id" ] && echo "'$session_id'" || echo "NULL")
WHERE id = 1;
EOF

    if [[ $? -eq 0 ]]; then
        log_success "Migrated state"
    else
        log_error "Failed to migrate state"
    fi
}

# ============================================================================
# Backup Original Files
# ============================================================================

backup_originals() {
    log_info "Backing up original JSON files to $BACKUP_DIR..."

    mkdir -p "$BACKUP_DIR"

    local files_backed=0

    for file in tasks.json tasks-archive.json memories.json state.json; do
        if [[ -f "$TASKMANAGER_DIR/$file" ]]; then
            cp "$TASKMANAGER_DIR/$file" "$BACKUP_DIR/$file"
            ((files_backed++))
            log_info "  Backed up: $file"
        fi
    done

    # Also backup schemas directory if exists
    if [[ -d "$TASKMANAGER_DIR/schemas" ]]; then
        cp -r "$TASKMANAGER_DIR/schemas" "$BACKUP_DIR/schemas"
        log_info "  Backed up: schemas/"
    fi

    log_success "Backed up $files_backed files"
}

# ============================================================================
# Log Migration
# ============================================================================

log_migration() {
    log_info "Recording migration in database..."

    local migration_date=$(date -Iseconds)

    sqlite3 "$DB_FILE" <<EOF
INSERT INTO schema_version (version, applied_at)
VALUES ('2.0.0-migrated', '${migration_date}')
ON CONFLICT(version) DO UPDATE SET applied_at = '${migration_date}';
EOF

    log_success "Migration logged"
}

# ============================================================================
# Summary
# ============================================================================

print_summary() {
    echo ""
    echo "============================================"
    echo "       Migration Complete!"
    echo "============================================"
    echo ""
    echo "  Tasks migrated:    $TASKS_MIGRATED"
    echo "    (from archive):  $ARCHIVED_MIGRATED"
    echo "  Memories migrated: $MEMORIES_MIGRATED"
    echo ""
    echo "  Database: $DB_FILE"
    echo "  Backup:   $BACKUP_DIR"
    echo "  Log:      $LOG_FILE"
    echo ""
    echo "============================================"
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "============================================"
    echo "  Taskmanager Migration: JSON v1 -> SQLite v2"
    echo "============================================"
    echo ""

    # Initialize log file
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "Migration started at $(date -Iseconds)" > "$LOG_FILE"
    echo "Taskmanager directory: $TASKMANAGER_DIR" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    # Run migration steps
    check_prerequisites
    create_database
    migrate_tasks
    migrate_archive
    migrate_memories
    migrate_state
    backup_originals
    log_migration

    print_summary

    echo "Migration completed at $(date -Iseconds)" >> "$LOG_FILE"

    log_success "Migration completed successfully!"
}

# Run main
main "$@"
