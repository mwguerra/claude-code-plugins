#!/bin/bash
# My Workflow Plugin - Hook Utility Functions
# Cross-platform compatible (Linux, macOS, Windows/Git Bash)

# Configuration and database paths
CONFIG_FILE="$HOME/.claude/my-workflow.json"
DB_DIR="$HOME/.claude/my-workflow"
DB_PATH="$DB_DIR/workflow.db"
OBSIDIAN_CONFIG="$HOME/.claude/obsidian-vault.json"

# ============================================================================
# Platform Detection
# ============================================================================

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

# ============================================================================
# Configuration Functions
# ============================================================================

# Get config value using jq
get_config() {
    local path="$1"
    local default="$2"
    if [[ -f "$CONFIG_FILE" ]]; then
        local value
        value=$(jq -r "$path // empty" "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$value" && "$value" != "null" ]]; then
            echo "$value"
            return
        fi
    fi
    echo "$default"
}

# Check if a feature is enabled
is_enabled() {
    local feature="$1"
    local value
    case "$feature" in
        "commits")
            value=$(get_config '.logging.captureCommits' 'true')
            ;;
        "decisions")
            value=$(get_config '.logging.captureDecisions' 'true')
            ;;
        "commitments")
            value=$(get_config '.logging.captureCommitments' 'true')
            ;;
        "ideas")
            value=$(get_config '.logging.captureIdeas' 'true')
            ;;
        "briefing")
            value=$(get_config '.briefing.showOnStart' 'true')
            ;;
        "vault")
            value=$(get_config '.vault.enabled' 'true')
            ;;
        "github")
            value=$(get_config '.briefing.includeGitHub' 'true')
            ;;
        "ai")
            value=$(get_config '.ai.enabled' 'true')
            ;;
        "ai_fallback")
            value=$(get_config '.ai.fallbackOnly' 'false')
            ;;
        *)
            value="false"
            ;;
    esac
    [[ "$value" == "true" ]]
}

# ============================================================================
# Database Functions
# ============================================================================

# Ensure database directory and file exist
ensure_db() {
    if [[ ! -d "$DB_DIR" ]]; then
        mkdir -p "$DB_DIR"
    fi

    if [[ ! -f "$DB_PATH" ]]; then
        # Initialize database with schema
        local schema_file="${CLAUDE_PLUGIN_ROOT}/schemas/schema.sql"
        if [[ -f "$schema_file" ]]; then
            sqlite3 "$DB_PATH" < "$schema_file"
            debug_log "Initialized database from schema"
        else
            debug_log "ERROR: Schema file not found: $schema_file"
            return 1
        fi
    fi
    echo "$DB_PATH"
}

# Run SQL query
db_query() {
    local sql="$1"
    local db
    db=$(ensure_db) || return 1
    sqlite3 -json "$db" "$sql" 2>/dev/null
}

# Run SQL command (no output expected)
db_exec() {
    local sql="$1"
    local db
    db=$(ensure_db) || return 1
    sqlite3 "$db" "$sql" 2>/dev/null
}

# Get next ID for a table with prefix
get_next_id() {
    local table="$1"
    local prefix="$2"
    local db
    db=$(ensure_db) || return 1

    local max_num
    max_num=$(sqlite3 "$db" "SELECT MAX(CAST(SUBSTR(id, ${#prefix}+2) AS INTEGER)) FROM $table WHERE id LIKE '$prefix-%'" 2>/dev/null)

    if [[ -z "$max_num" || "$max_num" == "null" ]]; then
        max_num=0
    fi

    printf "%s-%04d" "$prefix" $((max_num + 1))
}

# ============================================================================
# Session Functions
# ============================================================================

# Generate session ID
generate_session_id() {
    date +"%Y%m%d-%H%M%S-$$"
}

# Get current session ID
get_current_session_id() {
    local db
    db=$(ensure_db) || return 1
    sqlite3 "$db" "SELECT current_session_id FROM state WHERE id = 1" 2>/dev/null
}

# Set current session
set_current_session() {
    local session_id="$1"
    db_exec "UPDATE state SET current_session_id = '$session_id', updated_at = datetime('now') WHERE id = 1"
}

# ============================================================================
# Obsidian Vault Integration
# ============================================================================

# Get vault path from obsidian-vault plugin config
get_vault_path() {
    if [[ -f "$OBSIDIAN_CONFIG" ]]; then
        jq -r '.vaultPath // empty' "$OBSIDIAN_CONFIG" 2>/dev/null
    fi
}

# Check if vault integration is available
check_vault() {
    if ! is_enabled "vault"; then
        return 1
    fi

    local vault_path
    vault_path=$(get_vault_path)

    if [[ -z "$vault_path" ]] || [[ ! -d "$vault_path" ]]; then
        return 1
    fi

    echo "$vault_path"
}

# Get workflow folder in vault
get_workflow_folder() {
    local vault_path
    vault_path=$(check_vault) || return 1
    local folder
    folder=$(get_config '.vault.workflowFolder' 'workflow')
    echo "$vault_path/$folder"
}

# Sanitize tag (remove special chars, lowercase)
sanitize_tag() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Create consistent frontmatter for vault notes
# Usage: create_vault_frontmatter "title" "description" "tag1, tag2" "[[related1]], [[related2]]" "extra_yaml"
create_vault_frontmatter() {
    local title="$1"
    local description="$2"
    local tags="$3"
    local related="$4"
    local extra="$5"
    local created="${6:-$(get_date)}"

    echo "---"
    echo "title: \"$(echo "$title" | sed 's/"/\\"/g')\""
    if [[ -n "$description" ]]; then
        echo "description: \"$(echo "$description" | sed 's/"/\\"/g')\""
    fi

    # Format tags as YAML list (portable version)
    echo "tags:"
    if [[ -n "$tags" ]]; then
        echo "$tags" | tr ',' '\n' | while read -r tag; do
            tag=$(echo "$tag" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            local clean_tag=$(sanitize_tag "$tag")
            if [[ -n "$clean_tag" ]]; then
                echo "  - \"$clean_tag\""
            fi
        done
    fi

    # Format related as YAML list with quoted wiki-links (portable version)
    echo "related:"
    if [[ -n "$related" ]]; then
        echo "$related" | tr ',' '\n' | while read -r link; do
            link=$(echo "$link" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [[ -n "$link" ]]; then
                echo "  - \"$link\""
            fi
        done
    fi

    echo "created: $created"
    echo "updated: $(get_date)"
    if [[ -n "$extra" ]]; then
        echo "$extra"
    fi
    echo "---"
}

# Build wiki-link for Obsidian
# Usage: wiki_link "workflow/sessions/2024-01-28-session" "optional display text"
wiki_link() {
    local path="$1"
    local display="$2"
    # Remove .md extension if present
    path="${path%.md}"
    if [[ -n "$display" ]]; then
        echo "[[${path}|${display}]]"
    else
        echo "[[${path}]]"
    fi
}

# Find related notes in vault by searching frontmatter
# Usage: find_related_notes "workflow/sessions" "project" "my-project"
find_related_notes() {
    local folder="$1"
    local field="$2"
    local value="$3"
    local vault_path
    vault_path=$(check_vault) || return

    local results=""
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            # Get relative path without vault prefix and .md extension
            local rel_path="${file#$vault_path/}"
            rel_path="${rel_path%.md}"
            if [[ -n "$results" ]]; then
                results="$results, [[${rel_path}]]"
            else
                results="[[${rel_path}]]"
            fi
        fi
    done < <(grep -l "^${field}:.*${value}" "$vault_path/$folder"/*.md 2>/dev/null | head -5)

    echo "$results"
}

# Get today's session notes for cross-referencing
get_todays_session_links() {
    local workflow_folder
    workflow_folder=$(get_workflow_folder) || return
    local date=$(get_date)
    local results=""

    for file in "$workflow_folder/sessions/${date}"*.md; do
        if [[ -f "$file" ]]; then
            local rel_path="${file#$(get_vault_path)/}"
            rel_path="${rel_path%.md}"
            if [[ -n "$results" ]]; then
                results="$results, [[${rel_path}]]"
            else
                results="[[${rel_path}]]"
            fi
        fi
    done
    echo "$results"
}

# Get recent commit links for a project
get_recent_commit_links() {
    local project="$1"
    local limit="${2:-5}"
    local workflow_folder
    workflow_folder=$(get_workflow_folder) || return

    local results=""
    local count=0
    for file in $(ls -t "$workflow_folder/commits/"*.md 2>/dev/null); do
        if [[ $count -ge $limit ]]; then break; fi
        if grep -q "^project:.*$project" "$file" 2>/dev/null; then
            local rel_path="${file#$(get_vault_path)/}"
            rel_path="${rel_path%.md}"
            if [[ -n "$results" ]]; then
                results="$results, [[${rel_path}]]"
            else
                results="[[${rel_path}]]"
            fi
            count=$((count + 1))
        fi
    done
    echo "$results"
}

# Ensure all workflow vault directories exist
ensure_vault_structure() {
    local workflow_folder
    workflow_folder=$(get_workflow_folder) || return 1

    ensure_dir "$workflow_folder/sessions"
    ensure_dir "$workflow_folder/commits"
    ensure_dir "$workflow_folder/decisions"
    ensure_dir "$workflow_folder/commitments"
    ensure_dir "$workflow_folder/goals"
    ensure_dir "$workflow_folder/reviews"
    ensure_dir "$workflow_folder/patterns"
}

# ============================================================================
# Project/Git Functions
# ============================================================================

# Get project name from git or directory
get_project_name() {
    local dir="${1:-$(pwd)}"

    if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
        local remote
        remote=$(git -C "$dir" remote get-url origin 2>/dev/null)
        if [[ -n "$remote" ]]; then
            basename "$remote" .git
            return
        fi
    fi

    basename "$dir"
}

# Get current git branch
get_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Get latest commit info
get_latest_commit() {
    git log -1 --format="%H|%h|%s|%an|%ci" 2>/dev/null
}

# ============================================================================
# Date/Time Functions (Cross-platform)
# ============================================================================

# Get current date in YYYY-MM-DD format
get_date() {
    date +%Y-%m-%d
}

# Get current datetime in ISO format
get_datetime() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Get ISO 8601 timestamp
get_iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Convert date string to epoch (cross-platform)
# Usage: date_to_epoch "2024-01-28T10:30:00Z"
date_to_epoch() {
    local date_str="$1"
    if [[ "$OS_TYPE" == "macos" ]]; then
        # macOS date command
        date -j -f "%Y-%m-%dT%H:%M:%SZ" "$date_str" +%s 2>/dev/null || \
        date -j -f "%Y-%m-%d %H:%M:%S" "$date_str" +%s 2>/dev/null || \
        echo "0"
    else
        # Linux/GNU date command
        date -d "$date_str" +%s 2>/dev/null || echo "0"
    fi
}

# Get epoch from N days ago (cross-platform)
# Usage: days_ago_epoch 7
days_ago_epoch() {
    local days="$1"
    if [[ "$OS_TYPE" == "macos" ]]; then
        date -v-${days}d +%s
    else
        date -d "$days days ago" +%s
    fi
}

# Get date N days ago in YYYY-MM-DD format (cross-platform)
# Usage: days_ago_date 7
days_ago_date() {
    local days="$1"
    if [[ "$OS_TYPE" == "macos" ]]; then
        date -v-${days}d +%Y-%m-%d
    else
        date -d "$days days ago" +%Y-%m-%d
    fi
}

# Get file modification time as epoch (cross-platform)
# Usage: file_mtime "/path/to/file"
file_mtime() {
    local file="$1"
    if [[ "$OS_TYPE" == "macos" ]]; then
        stat -f %m "$file" 2>/dev/null || echo "0"
    else
        stat -c %Y "$file" 2>/dev/null || echo "0"
    fi
}

# Touch file with specific date (cross-platform)
# Usage: touch_date "2024-01-28 10:30:00" "/path/to/file"
touch_date() {
    local date_str="$1"
    local file="$2"
    if [[ "$OS_TYPE" == "macos" ]]; then
        # macOS touch format: [[CC]YY]MMDDhhmm[.SS]
        local formatted
        formatted=$(date -j -f "%Y-%m-%d %H:%M:%S" "$date_str" +%Y%m%d%H%M.%S 2>/dev/null)
        touch -t "$formatted" "$file" 2>/dev/null
    else
        touch -d "$date_str" "$file" 2>/dev/null
    fi
}

# ============================================================================
# String Functions
# ============================================================================

# Generate slug from text
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-50
}

# Escape string for SQL (double single quotes for SQLite)
sql_escape() {
    echo "$1" | sed "s/'/''/g"
}

# Escape string for JSON
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# ============================================================================
# Utility Functions
# ============================================================================

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

# Get tool input from environment
get_tool_input() {
    echo "${CLAUDE_TOOL_INPUT:-}"
}

# Get tool output from environment
get_tool_output() {
    echo "${CLAUDE_TOOL_OUTPUT:-}"
}

# Get stop summary from environment
get_stop_summary() {
    echo "${CLAUDE_STOP_SUMMARY:-}"
}

# Get user prompt from environment (for UserPromptSubmit hooks)
get_user_prompt() {
    echo "${CLAUDE_USER_PROMPT:-}"
}

# Get agent output from environment (for SubagentStop hooks)
get_agent_output() {
    echo "${CLAUDE_TOOL_OUTPUT:-}"
}

# ============================================================================
# Logging Functions
# ============================================================================

# Debug log (only when enabled)
debug_log() {
    local msg="$1"
    local debug_file="$DB_DIR/debug.log"

    if [[ "${WORKFLOW_DEBUG:-false}" == "true" ]]; then
        echo "[$(get_iso_timestamp)] $msg" >> "$debug_file"
    fi
}

# Activity log (always)
activity_log() {
    local activity_type="$1"
    local title="$2"
    local entity_type="$3"
    local entity_id="$4"
    local project="$5"
    local details="$6"

    local session_id
    session_id=$(get_current_session_id)

    local escaped_title
    escaped_title=$(sql_escape "$title")
    local escaped_details
    escaped_details=$(sql_escape "$details")

    db_exec "INSERT INTO activity_timeline (activity_type, title, entity_type, entity_id, project, details, session_id)
             VALUES ('$activity_type', '$escaped_title', '$entity_type', '$entity_id', '$project', '$escaped_details', '$session_id')"
}

# ============================================================================
# Daily Notes Functions
# ============================================================================

# Get or create today's daily note
ensure_daily_note() {
    local today
    today=$(get_date)
    local db
    db=$(ensure_db) || return 1

    # Check if daily note exists
    local exists
    exists=$(sqlite3 "$db" "SELECT COUNT(*) FROM daily_notes WHERE date = '$today'" 2>/dev/null || echo "0")

    if [[ "$exists" == "0" ]]; then
        # Create new daily note
        sqlite3 "$db" "INSERT INTO daily_notes (id, date) VALUES ('$today', '$today')" 2>/dev/null
        debug_log "Created daily note for $today"
    fi

    echo "$today"
}

# Update daily note with new idea
update_daily_note_ideas() {
    local idea_id="$1"
    local db
    db=$(ensure_db) || return 1
    local today
    today=$(ensure_daily_note)

    # Get current ideas list
    local current_ideas
    current_ideas=$(sqlite3 "$db" "SELECT COALESCE(new_ideas, '[]') FROM daily_notes WHERE date = '$today'" 2>/dev/null)

    # Add new idea to list
    if [[ "$current_ideas" == "[]" || -z "$current_ideas" ]]; then
        current_ideas="[\"$idea_id\"]"
    else
        current_ideas=$(echo "$current_ideas" | sed "s/\]$/,\"$idea_id\"]/")
    fi

    sqlite3 "$db" "UPDATE daily_notes SET new_ideas = '$current_ideas', updated_at = datetime('now') WHERE date = '$today'" 2>/dev/null
}

# Update daily note with new decision
update_daily_note_decisions() {
    local decision_id="$1"
    local db
    db=$(ensure_db) || return 1
    local today
    today=$(ensure_daily_note)

    local current_decisions
    current_decisions=$(sqlite3 "$db" "SELECT COALESCE(new_decisions, '[]') FROM daily_notes WHERE date = '$today'" 2>/dev/null)

    if [[ "$current_decisions" == "[]" || -z "$current_decisions" ]]; then
        current_decisions="[\"$decision_id\"]"
    else
        current_decisions=$(echo "$current_decisions" | sed "s/\]$/,\"$decision_id\"]/")
    fi

    sqlite3 "$db" "UPDATE daily_notes SET new_decisions = '$current_decisions', updated_at = datetime('now') WHERE date = '$today'" 2>/dev/null
}

# Update daily note with completed commitment
update_daily_note_completed() {
    local commitment_id="$1"
    local db
    db=$(ensure_db) || return 1
    local today
    today=$(ensure_daily_note)

    local current_completed
    current_completed=$(sqlite3 "$db" "SELECT COALESCE(completed_commitments, '[]') FROM daily_notes WHERE date = '$today'" 2>/dev/null)

    if [[ "$current_completed" == "[]" || -z "$current_completed" ]]; then
        current_completed="[\"$commitment_id\"]"
    else
        current_completed=$(echo "$current_completed" | sed "s/\]$/,\"$commitment_id\"]/")
    fi

    sqlite3 "$db" "UPDATE daily_notes SET completed_commitments = '$current_completed', updated_at = datetime('now') WHERE date = '$today'" 2>/dev/null
}

# Update daily note activity times
update_daily_note_activity() {
    local db
    db=$(ensure_db) || return 1
    local today
    today=$(ensure_daily_note)
    local now
    now=$(get_iso_timestamp)

    # Update first activity if not set
    sqlite3 "$db" "UPDATE daily_notes SET first_activity_at = COALESCE(first_activity_at, '$now'), last_activity_at = '$now', updated_at = datetime('now') WHERE date = '$today'" 2>/dev/null
}

# Generate previous day summary for morning briefing
get_previous_day_summary() {
    local db
    db=$(ensure_db) || return 1
    local yesterday
    yesterday=$(days_ago_date 1)

    # Check if yesterday's note exists
    local exists
    exists=$(sqlite3 "$db" "SELECT COUNT(*) FROM daily_notes WHERE date = '$yesterday'" 2>/dev/null || echo "0")

    if [[ "$exists" == "0" ]]; then
        echo ""
        return
    fi

    # Get yesterday's data
    local data
    data=$(sqlite3 -separator '|' "$db" "
        SELECT
            first_activity_at,
            last_activity_at,
            total_work_seconds,
            sessions_count,
            commits_count,
            completed_commitments,
            new_ideas,
            new_decisions
        FROM daily_notes
        WHERE date = '$yesterday'
    " 2>/dev/null)

    if [[ -z "$data" ]]; then
        echo ""
        return
    fi

    IFS='|' read -r first_activity last_activity work_seconds sessions commits completed ideas decisions <<< "$data"

    # Format work time
    local work_hours=$((work_seconds / 3600))
    local work_mins=$(((work_seconds % 3600) / 60))
    local work_time=""
    if [[ $work_hours -gt 0 ]]; then
        work_time="${work_hours}h ${work_mins}m"
    elif [[ $work_mins -gt 0 ]]; then
        work_time="${work_mins}m"
    else
        work_time="minimal"
    fi

    # Format times
    local start_time=""
    local end_time=""
    if [[ -n "$first_activity" ]]; then
        start_time=$(echo "$first_activity" | cut -d'T' -f2 | cut -d':' -f1-2)
    fi
    if [[ -n "$last_activity" ]]; then
        end_time=$(echo "$last_activity" | cut -d'T' -f2 | cut -d':' -f1-2)
    fi

    # Count items
    local completed_count=0
    local ideas_count=0
    local decisions_count=0
    if [[ -n "$completed" && "$completed" != "[]" ]]; then
        completed_count=$(echo "$completed" | grep -o '"' | wc -l)
        completed_count=$((completed_count / 2))
    fi
    if [[ -n "$ideas" && "$ideas" != "[]" ]]; then
        ideas_count=$(echo "$ideas" | grep -o '"' | wc -l)
        ideas_count=$((ideas_count / 2))
    fi
    if [[ -n "$decisions" && "$decisions" != "[]" ]]; then
        decisions_count=$(echo "$decisions" | grep -o '"' | wc -l)
        decisions_count=$((decisions_count / 2))
    fi

    # Build summary
    echo "## Yesterday's Summary ($yesterday)"
    echo ""
    if [[ -n "$start_time" && -n "$end_time" ]]; then
        echo "- **Work window**: $start_time - $end_time ($work_time active)"
    fi
    echo "- **Sessions**: ${sessions:-0}"
    echo "- **Commits**: ${commits:-0}"
    if [[ $completed_count -gt 0 ]]; then
        echo "- **Completed**: $completed_count items"
    fi
    if [[ $ideas_count -gt 0 ]]; then
        echo "- **New ideas**: $ideas_count captured"
    fi
    if [[ $decisions_count -gt 0 ]]; then
        echo "- **Decisions**: $decisions_count made"
    fi
}

# Get today's planner data
get_today_planner() {
    local db
    db=$(ensure_db) || return 1
    local today
    today=$(get_date)

    echo "## Today's Planner"
    echo ""

    # Overdue items
    local overdue
    overdue=$(sqlite3 -separator '|' "$db" "
        SELECT id, title, priority, project
        FROM commitments
        WHERE status IN ('pending', 'in_progress')
          AND due_date < '$today'
        ORDER BY priority DESC, due_date ASC
        LIMIT 10
    " 2>/dev/null)

    if [[ -n "$overdue" ]]; then
        echo "### ⚠️ Overdue"
        echo ""
        while IFS='|' read -r id title priority project; do
            local proj_str=""
            [[ -n "$project" ]] && proj_str=" [$project]"
            echo "- [ ] **$title**$proj_str ($priority)"
        done <<< "$overdue"
        echo ""
    fi

    # Due today
    local due_today
    due_today=$(sqlite3 -separator '|' "$db" "
        SELECT id, title, priority, project
        FROM commitments
        WHERE status IN ('pending', 'in_progress')
          AND due_date = '$today'
        ORDER BY priority DESC
        LIMIT 10
    " 2>/dev/null)

    if [[ -n "$due_today" ]]; then
        echo "### 📅 Due Today"
        echo ""
        while IFS='|' read -r id title priority project; do
            local proj_str=""
            [[ -n "$project" ]] && proj_str=" [$project]"
            echo "- [ ] **$title**$proj_str ($priority)"
        done <<< "$due_today"
        echo ""
    fi

    # High priority items
    local high_priority
    high_priority=$(sqlite3 -separator '|' "$db" "
        SELECT id, title, project
        FROM commitments
        WHERE status IN ('pending', 'in_progress')
          AND priority IN ('critical', 'high')
          AND (due_date IS NULL OR due_date > '$today')
        ORDER BY priority DESC
        LIMIT 5
    " 2>/dev/null)

    if [[ -n "$high_priority" ]]; then
        echo "### 🔥 High Priority"
        echo ""
        while IFS='|' read -r id title project; do
            local proj_str=""
            [[ -n "$project" ]] && proj_str=" [$project]"
            echo "- [ ] **$title**$proj_str"
        done <<< "$high_priority"
        echo ""
    fi

    # Coming up (next 7 days)
    local coming_up
    coming_up=$(sqlite3 -separator '|' "$db" "
        SELECT id, title, due_date, project
        FROM commitments
        WHERE status IN ('pending', 'in_progress')
          AND due_date > '$today'
          AND due_date <= date('$today', '+7 days')
        ORDER BY due_date ASC
        LIMIT 5
    " 2>/dev/null)

    if [[ -n "$coming_up" ]]; then
        echo "### 📆 Coming Up (Next 7 Days)"
        echo ""
        while IFS='|' read -r id title due_date project; do
            local proj_str=""
            [[ -n "$project" ]] && proj_str=" [$project]"
            echo "- [ ] **$title** - due $due_date$proj_str"
        done <<< "$coming_up"
        echo ""
    fi
}

# Get ideas inbox
get_ideas_inbox() {
    local db
    db=$(ensure_db) || return 1

    local recent_ideas
    recent_ideas=$(sqlite3 -separator '|' "$db" "
        SELECT id, title, idea_type, project
        FROM ideas
        WHERE status = 'captured'
        ORDER BY created_at DESC
        LIMIT 10
    " 2>/dev/null)

    if [[ -n "$recent_ideas" ]]; then
        echo "## 💡 Ideas Inbox"
        echo ""
        while IFS='|' read -r id title idea_type project; do
            local proj_str=""
            [[ -n "$project" ]] && proj_str=" [$project]"
            echo "- **$title** ($idea_type)$proj_str"
        done <<< "$recent_ideas"
        echo ""
    fi
}

# ============================================================================
# Real-Time Vault Daily Note Sync
# ============================================================================

# Append a line to a specific section in a markdown file
# Usage: append_to_section "file" "## Section Header" "- new line"
append_to_section() {
    local file="$1"
    local section="$2"
    local content="$3"
    local timestamp=$(date '+%H:%M')

    # If file doesn't exist, create template
    if [[ ! -f "$file" ]]; then
        create_daily_vault_template "$file"
    fi

    # Check if section exists
    if ! grep -q "^$section" "$file" 2>/dev/null; then
        # Add section at end
        echo -e "\n$section\n" >> "$file"
    fi

    # Find section and insert content before next section or end
    # Use awk for reliable section insertion
    awk -v section="$section" -v content="$content" -v ts="$timestamp" '
        BEGIN { found=0; inserted=0 }
        {
            print
            if ($0 == section) {
                found=1
            }
            if (found && !inserted && /^$/) {
                print "- [" ts "] " content
                inserted=1
            }
        }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# Create daily vault note template
create_daily_vault_template() {
    local file="$1"
    local date=$(basename "$file" .md)
    local day_of_week=$(date -d "$date" +%A 2>/dev/null || date -j -f "%Y-%m-%d" "$date" +%A 2>/dev/null || echo "")

    mkdir -p "$(dirname "$file")"

    cat > "$file" << EOF
---
title: "Daily Note: $date"
description: "Workflow summary for $date"
tags: ["daily", "workflow"]
created: $date
updated: $date
date: "$date"
day_of_week: "$day_of_week"
---

# Daily Note: $date ($day_of_week)

## Morning Plan

<!-- Set your intentions for today -->

## Work Log

<!-- Activities logged automatically -->

## Decisions Made

<!-- Decisions captured during sessions -->

## Ideas Captured

<!-- Ideas captured during sessions -->

## Commitments

<!-- Commitments made during sessions -->

## Reflections

<!-- End of day thoughts -->

EOF
}

# Append activity to daily vault note in real-time
# Usage: vault_log_activity "decision" "Title" "D-0001" "workflow/decisions/..."
vault_log_activity() {
    local activity_type="$1"
    local title="$2"
    local entity_id="$3"
    local link_path="${4:-}"

    # Check if vault is enabled
    if ! is_enabled "vault"; then
        return 0
    fi

    local vault_path
    vault_path=$(check_vault)
    if [[ -z "$vault_path" ]]; then
        return 0
    fi

    local workflow_folder=$(get_workflow_folder)
    local today=$(get_date)
    local daily_file="$workflow_folder/daily/${today}.md"

    # Ensure daily file exists
    if [[ ! -f "$daily_file" ]]; then
        create_daily_vault_template "$daily_file"
    fi

    # Format entry based on type
    local section=""
    local entry=""

    case "$activity_type" in
        decision)
            section="## Decisions Made"
            if [[ -n "$link_path" ]]; then
                entry="**Decision**: $title [[${link_path}|${entity_id}]]"
            else
                entry="**Decision**: $title ($entity_id)"
            fi
            ;;
        idea)
            section="## Ideas Captured"
            if [[ -n "$link_path" ]]; then
                entry="**Idea**: $title [[${link_path}|${entity_id}]]"
            else
                entry="**Idea**: $title ($entity_id)"
            fi
            ;;
        commitment)
            section="## Commitments"
            if [[ -n "$link_path" ]]; then
                entry="**Commitment**: $title [[${link_path}|${entity_id}]]"
            else
                entry="**Commitment**: $title ($entity_id)"
            fi
            ;;
        session_start)
            section="## Work Log"
            entry="**Session Started**: $title"
            ;;
        session_end)
            section="## Work Log"
            entry="**Session Ended**: $title (${entity_id})"
            ;;
        commit)
            section="## Work Log"
            if [[ -n "$link_path" ]]; then
                entry="**Commit**: $title [[${link_path}|${entity_id}]]"
            else
                entry="**Commit**: $title"
            fi
            ;;
        *)
            section="## Work Log"
            entry="$title"
            ;;
    esac

    # Append to appropriate section
    append_to_section "$daily_file" "$section" "$entry"
    debug_log "Logged to daily vault: [$activity_type] $title"
}

# Mark a session as interrupted in its vault note
vault_mark_session_interrupted() {
    local session_id="$1"

    local vault_path
    vault_path=$(check_vault)
    if [[ -z "$vault_path" ]]; then
        return 0
    fi

    # Find session note (might not exist)
    local session_note=$(find "$vault_path/workflow/sessions" -name "*${session_id}*.md" 2>/dev/null | head -1)

    if [[ -n "$session_note" && -f "$session_note" ]]; then
        # Add interrupted status to frontmatter
        sed -i 's/^status: active/status: interrupted/' "$session_note" 2>/dev/null || true

        # Append note about interruption
        echo "" >> "$session_note"
        echo "---" >> "$session_note"
        echo "*Session was interrupted (Claude closed unexpectedly)*" >> "$session_note"

        debug_log "Marked session note as interrupted: $session_note"
    fi
}

# ============================================================================
# Process Detection for Session Cleanup
# ============================================================================

# Check if Claude is running for a given directory
# Returns: 0 if Claude is running, 1 if not
is_claude_running_for_directory() {
    local target_dir="$1"

    # Normalize path
    target_dir=$(realpath "$target_dir" 2>/dev/null || echo "$target_dir")

    # Find all Claude main processes (not subshells)
    local pids
    pids=$(pgrep -x "claude" 2>/dev/null) || return 1

    for pid in $pids; do
        local cwd
        cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null) || continue

        # Match if directories overlap (handles subdirectories)
        if [[ "$target_dir" == "$cwd"* ]] || [[ "$cwd" == "$target_dir"* ]]; then
            debug_log "Found Claude process $pid running in $cwd (matches $target_dir)"
            return 0
        fi
    done

    return 1
}

# Cleanup orphaned sessions for current project
# Called at session start
cleanup_orphaned_sessions() {
    local current_dir=$(pwd)
    local project=$(get_project_name)
    local db
    db=$(ensure_db) || return 1

    debug_log "Checking for orphaned sessions in project: $project"

    # Get all active sessions
    local active_sessions
    active_sessions=$(sqlite3 -separator '|' "$db" "
        SELECT id, COALESCE(directory, '')
        FROM sessions
        WHERE status = 'active'
    " 2>/dev/null)

    if [[ -z "$active_sessions" ]]; then
        debug_log "No active sessions to cleanup"
        return 0
    fi

    while IFS='|' read -r session_id session_dir; do
        # If no directory stored, use project as fallback
        if [[ -z "$session_dir" ]]; then
            session_dir="$current_dir"
        fi

        # Skip if Claude is still running for this session
        if is_claude_running_for_directory "$session_dir"; then
            debug_log "Session $session_id still has active Claude process, skipping"
            continue
        fi

        # Close orphaned session
        debug_log "Closing orphaned session: $session_id (dir: $session_dir)"

        local timestamp=$(get_iso_timestamp)
        sqlite3 "$db" "
            UPDATE sessions
            SET status = 'interrupted',
                summary = 'Session interrupted (Claude closed unexpectedly)',
                ended_at = '$timestamp',
                updated_at = '$timestamp'
            WHERE id = '$session_id'
        " 2>/dev/null

        # Update vault note if exists
        vault_mark_session_interrupted "$session_id"

        # Log activity
        activity_log "session_cleanup" "Closed orphaned session: $session_id" "sessions" "$session_id" "$project" "{}"

    done <<< "$active_sessions"
}

# ============================================================================
# Export Functions
# ============================================================================

export OS_TYPE
export -f detect_os
export -f get_config is_enabled
export -f ensure_db db_query db_exec get_next_id
export -f generate_session_id get_current_session_id set_current_session
export -f get_vault_path check_vault get_workflow_folder
export -f sanitize_tag create_vault_frontmatter wiki_link
export -f find_related_notes get_todays_session_links get_recent_commit_links
export -f ensure_vault_structure
export -f get_project_name get_git_branch get_latest_commit
export -f get_date get_datetime get_iso_timestamp
export -f date_to_epoch days_ago_epoch days_ago_date file_mtime touch_date
export -f slugify sql_escape json_escape
export -f ensure_dir get_tool_input get_tool_output get_stop_summary get_user_prompt get_agent_output
export -f debug_log activity_log
export -f ensure_daily_note update_daily_note_ideas update_daily_note_decisions
export -f update_daily_note_completed update_daily_note_activity
export -f get_previous_day_summary get_today_planner get_ideas_inbox
export -f append_to_section create_daily_vault_template vault_log_activity vault_mark_session_interrupted
export -f is_claude_running_for_directory cleanup_orphaned_sessions
