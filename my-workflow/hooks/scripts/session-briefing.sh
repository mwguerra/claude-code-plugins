#!/bin/bash
# My Workflow Plugin - Session Start Briefing
# Triggered by SessionStart event

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

debug_log "session-briefing.sh triggered"

# Check if briefing is enabled
if ! is_enabled "briefing"; then
    debug_log "Briefing disabled"
    exit 0
fi

# Ensure database exists
DB=$(ensure_db)
if [[ -z "$DB" ]]; then
    debug_log "Database not initialized"
    exit 0
fi

# Start a new session
SESSION_ID=$(generate_session_id)
PROJECT=$(get_project_name)
BRANCH=$(get_git_branch)
TIMESTAMP=$(get_iso_timestamp)

# Create session record
db_exec "INSERT INTO sessions (id, project, branch, started_at, status)
         VALUES ('$SESSION_ID', '$PROJECT', '$BRANCH', '$TIMESTAMP', 'active')"

# Set as current session
set_current_session "$SESSION_ID"

# Log activity
activity_log "session_start" "Started session in $PROJECT" "sessions" "$SESSION_ID" "$PROJECT" "{}"

# Build briefing output
BRIEFING=""

# ============================================================================
# Pending Commitments
# ============================================================================

if [[ "$(get_config '.briefing.includePendingCommitments' 'true')" == "true" ]]; then
    # Get overdue commitments
    OVERDUE=$(sqlite3 -json "$DB" "
        SELECT id, title, due_date, priority
        FROM commitments
        WHERE status IN ('pending', 'in_progress')
          AND due_date IS NOT NULL
          AND due_date < date('now')
        ORDER BY due_date ASC
        LIMIT 5
    " 2>/dev/null)

    # Get commitments due today
    DUE_TODAY=$(sqlite3 -json "$DB" "
        SELECT id, title, due_date, priority
        FROM commitments
        WHERE status IN ('pending', 'in_progress')
          AND due_date = date('now')
        ORDER BY priority DESC
        LIMIT 5
    " 2>/dev/null)

    # Get upcoming commitments (next 7 days)
    UPCOMING=$(sqlite3 -json "$DB" "
        SELECT id, title, due_date, priority
        FROM commitments
        WHERE status IN ('pending', 'in_progress')
          AND due_date > date('now')
          AND due_date <= date('now', '+7 days')
        ORDER BY due_date ASC
        LIMIT 5
    " 2>/dev/null)

    # Build commitments section
    COMMITMENT_SECTION=""

    if [[ "$OVERDUE" != "[]" && -n "$OVERDUE" ]]; then
        COMMITMENT_SECTION+="**Overdue:**\n"
        while IFS= read -r line; do
            id=$(echo "$line" | jq -r '.id')
            title=$(echo "$line" | jq -r '.title')
            due=$(echo "$line" | jq -r '.due_date')
            COMMITMENT_SECTION+="- [$id] $title (due $due)\n"
        done < <(echo "$OVERDUE" | jq -c '.[]' 2>/dev/null)
        COMMITMENT_SECTION+="\n"
    fi

    if [[ "$DUE_TODAY" != "[]" && -n "$DUE_TODAY" ]]; then
        COMMITMENT_SECTION+="**Due Today:**\n"
        while IFS= read -r line; do
            id=$(echo "$line" | jq -r '.id')
            title=$(echo "$line" | jq -r '.title')
            COMMITMENT_SECTION+="- [$id] $title\n"
        done < <(echo "$DUE_TODAY" | jq -c '.[]' 2>/dev/null)
        COMMITMENT_SECTION+="\n"
    fi

    if [[ "$UPCOMING" != "[]" && -n "$UPCOMING" ]]; then
        COMMITMENT_SECTION+="**Upcoming (7 days):**\n"
        while IFS= read -r line; do
            id=$(echo "$line" | jq -r '.id')
            title=$(echo "$line" | jq -r '.title')
            due=$(echo "$line" | jq -r '.due_date')
            COMMITMENT_SECTION+="- [$id] $title (due $due)\n"
        done < <(echo "$UPCOMING" | jq -c '.[]' 2>/dev/null)
        COMMITMENT_SECTION+="\n"
    fi

    if [[ -n "$COMMITMENT_SECTION" ]]; then
        BRIEFING+="## Commitments\n\n$COMMITMENT_SECTION"
    fi
fi

# ============================================================================
# Recent Decisions (for this project)
# ============================================================================

if [[ "$(get_config '.briefing.includeRecentDecisions' 'true')" == "true" ]]; then
    DAYS_BACK=$(get_config '.briefing.daysBack' '7')
    PROJECT_ESCAPED=$(sql_escape "$PROJECT")

    RECENT_DECISIONS=$(sqlite3 -json "$DB" "
        SELECT id, title, category, created_at
        FROM decisions
        WHERE status = 'active'
          AND (project = '$PROJECT_ESCAPED' OR project IS NULL)
          AND created_at >= datetime('now', '-$DAYS_BACK days')
        ORDER BY created_at DESC
        LIMIT 5
    " 2>/dev/null)

    if [[ "$RECENT_DECISIONS" != "[]" && -n "$RECENT_DECISIONS" ]]; then
        BRIEFING+="## Recent Decisions\n\n"
        while IFS= read -r line; do
            id=$(echo "$line" | jq -r '.id')
            title=$(echo "$line" | jq -r '.title')
            category=$(echo "$line" | jq -r '.category // "general"')
            BRIEFING+="- [$id] $title ($category)\n"
        done < <(echo "$RECENT_DECISIONS" | jq -c '.[]' 2>/dev/null)
        BRIEFING+="\n"
    fi
fi

# ============================================================================
# Goal Progress
# ============================================================================

if [[ "$(get_config '.briefing.includeGoalProgress' 'true')" == "true" ]]; then
    ACTIVE_GOALS=$(sqlite3 -json "$DB" "
        SELECT id, title, goal_type, progress_percentage, target_date
        FROM goals
        WHERE status = 'active'
          AND (project = '$PROJECT_ESCAPED' OR project IS NULL)
        ORDER BY
          CASE goal_type
            WHEN 'objective' THEN 1
            WHEN 'milestone' THEN 2
            WHEN 'habit' THEN 3
            ELSE 4
          END,
          progress_percentage DESC
        LIMIT 5
    " 2>/dev/null)

    if [[ "$ACTIVE_GOALS" != "[]" && -n "$ACTIVE_GOALS" ]]; then
        BRIEFING+="## Active Goals\n\n"
        while IFS= read -r line; do
            id=$(echo "$line" | jq -r '.id')
            title=$(echo "$line" | jq -r '.title')
            progress=$(echo "$line" | jq -r '.progress_percentage // 0')
            target=$(echo "$line" | jq -r '.target_date // ""')
            progress_bar=""
            filled=$((progress / 10))
            for ((i=0; i<10; i++)); do
                if [[ $i -lt $filled ]]; then
                    progress_bar+="="
                else
                    progress_bar+="-"
                fi
            done
            if [[ -n "$target" ]]; then
                BRIEFING+="- [$id] $title [$progress_bar] ${progress}% (target: $target)\n"
            else
                BRIEFING+="- [$id] $title [$progress_bar] ${progress}%\n"
            fi
        done < <(echo "$ACTIVE_GOALS" | jq -c '.[]' 2>/dev/null)
        BRIEFING+="\n"
    fi
fi

# ============================================================================
# GitHub Items (if enabled)
# ============================================================================

if is_enabled "github" && command -v gh &>/dev/null; then
    GH_USERNAME=$(get_config '.github.username' '')

    if [[ -n "$GH_USERNAME" ]]; then
        # Check if cache is still valid
        CACHE_MINUTES=$(get_config '.github.cacheMinutes' '15')
        CACHE_VALID=$(sqlite3 "$DB" "
            SELECT COUNT(*)
            FROM github_cache
            WHERE cache_type = 'combined'
              AND expires_at > datetime('now')
        " 2>/dev/null)

        if [[ "$CACHE_VALID" == "0" ]]; then
            debug_log "Refreshing GitHub cache..."

            # Fetch assigned issues
            ISSUES=""
            if [[ "$(get_config '.github.trackIssues' 'true')" == "true" ]]; then
                ISSUES=$(gh issue list --assignee "$GH_USERNAME" --state open --limit 10 --json number,title,repository 2>/dev/null || echo "[]")
            fi

            # Fetch PRs needing review
            REVIEWS=""
            if [[ "$(get_config '.github.trackReviews' 'true')" == "true" ]]; then
                REVIEWS=$(gh search prs --review-requested "$GH_USERNAME" --state open --limit 10 --json number,title,repository 2>/dev/null || echo "[]")
            fi

            # Fetch authored PRs
            PRS=""
            if [[ "$(get_config '.github.trackPRs' 'true')" == "true" ]]; then
                PRS=$(gh pr list --author "$GH_USERNAME" --state open --limit 10 --json number,title,repository 2>/dev/null || echo "[]")
            fi

            # Build combined cache
            COMBINED_DATA="{\"issues\":$ISSUES,\"reviews\":$REVIEWS,\"prs\":$PRS}"
            ESCAPED_DATA=$(sql_escape "$COMBINED_DATA")

            db_exec "INSERT OR REPLACE INTO github_cache (id, cache_type, data, fetched_at, expires_at)
                     VALUES ('combined', 'combined', '$ESCAPED_DATA', datetime('now'), datetime('now', '+$CACHE_MINUTES minutes'))"
        fi

        # Read from cache
        CACHED_DATA=$(sqlite3 "$DB" "SELECT data FROM github_cache WHERE id = 'combined'" 2>/dev/null)

        if [[ -n "$CACHED_DATA" ]]; then
            GITHUB_SECTION=""

            # Process issues
            ISSUES_JSON=$(echo "$CACHED_DATA" | jq -r '.issues // []')
            if [[ "$ISSUES_JSON" != "[]" ]]; then
                GITHUB_SECTION+="**Assigned Issues:**\n"
                while IFS= read -r line; do
                    num=$(echo "$line" | jq -r '.number')
                    title=$(echo "$line" | jq -r '.title')
                    repo=$(echo "$line" | jq -r '.repository.name // .repository // "unknown"')
                    GITHUB_SECTION+="- #$num $title ($repo)\n"
                done < <(echo "$ISSUES_JSON" | jq -c '.[]' 2>/dev/null | head -5)
                GITHUB_SECTION+="\n"
            fi

            # Process reviews
            REVIEWS_JSON=$(echo "$CACHED_DATA" | jq -r '.reviews // []')
            if [[ "$REVIEWS_JSON" != "[]" ]]; then
                GITHUB_SECTION+="**PRs Needing Review:**\n"
                while IFS= read -r line; do
                    num=$(echo "$line" | jq -r '.number')
                    title=$(echo "$line" | jq -r '.title')
                    repo=$(echo "$line" | jq -r '.repository.name // .repository // "unknown"')
                    GITHUB_SECTION+="- #$num $title ($repo)\n"
                done < <(echo "$REVIEWS_JSON" | jq -c '.[]' 2>/dev/null | head -5)
                GITHUB_SECTION+="\n"
            fi

            # Process authored PRs
            PRS_JSON=$(echo "$CACHED_DATA" | jq -r '.prs // []')
            if [[ "$PRS_JSON" != "[]" ]]; then
                GITHUB_SECTION+="**Your Open PRs:**\n"
                while IFS= read -r line; do
                    num=$(echo "$line" | jq -r '.number')
                    title=$(echo "$line" | jq -r '.title')
                    repo=$(echo "$line" | jq -r '.repository.name // .repository // "unknown"')
                    GITHUB_SECTION+="- #$num $title ($repo)\n"
                done < <(echo "$PRS_JSON" | jq -c '.[]' 2>/dev/null | head -5)
                GITHUB_SECTION+="\n"
            fi

            if [[ -n "$GITHUB_SECTION" ]]; then
                BRIEFING+="## GitHub\n\n$GITHUB_SECTION"
            fi
        fi
    fi
fi

# ============================================================================
# Daily Note & Previous Day Summary (Morning Briefing)
# ============================================================================

# Get date info (cross-platform compatible)
TODAY=$(get_date)
YEAR=$(date +%Y)
MONTH_LOWER=$(date +%B | tr '[:upper:]' '[:lower:]')
DAY_OF_WEEK=$(date +%A)

# Ensure daily note exists and update activity time
ensure_daily_note
update_daily_note_activity

# Check if this is the first session of the day
FIRST_SESSION_TODAY=$(sqlite3 "$DB" "
    SELECT COUNT(*)
    FROM sessions
    WHERE date(started_at) = date('now')
      AND id != '$SESSION_ID'
" 2>/dev/null || echo "0")

# Generate morning briefing if this is first session of the day
MORNING_BRIEFING=""
if [[ "$FIRST_SESSION_TODAY" == "0" ]]; then
    # Previous day summary
    YESTERDAY_SUMMARY=$(get_previous_day_summary)
    if [[ -n "$YESTERDAY_SUMMARY" ]]; then
        MORNING_BRIEFING="$YESTERDAY_SUMMARY\n\n"
    fi
fi

# Today's planner
TODAY_PLANNER=$(get_today_planner)
if [[ -n "$TODAY_PLANNER" ]]; then
    MORNING_BRIEFING+="$TODAY_PLANNER\n"
fi

# Ideas inbox
IDEAS_INBOX=$(get_ideas_inbox)
if [[ -n "$IDEAS_INBOX" ]]; then
    MORNING_BRIEFING+="$IDEAS_INBOX\n"
fi

# ============================================================================
# Vault: Create/Update Daily Note
# ============================================================================

if is_enabled "vault"; then
    VAULT_PATH=$(check_vault)
    if [[ -n "$VAULT_PATH" ]]; then
        WORKFLOW_FOLDER=$(get_workflow_folder)
        ensure_vault_structure

        # Create daily folder if needed
        ensure_dir "$WORKFLOW_FOLDER/daily"

        DAILY_FILE="$WORKFLOW_FOLDER/daily/$TODAY.md"

        # Only create new daily note if it doesn't exist
        if [[ ! -f "$DAILY_FILE" ]]; then
            {
                echo "---"
                echo "title: \"Daily Note: $TODAY\""
                echo "description: \"Workflow summary for $TODAY\""
                echo "tags: [daily, workflow, $YEAR, $MONTH_LOWER]"
                echo "related: []"
                echo "created: $TODAY"
                echo "updated: $TODAY"
                echo "date: \"$TODAY\""
                echo "day_of_week: \"$DAY_OF_WEEK\""
                echo "---"
                echo ""
                echo "# Daily Note: $TODAY ($DAY_OF_WEEK)"
                echo ""
                echo "## Morning Plan"
                echo ""
                echo "<!-- Set your intentions for today -->"
                echo ""
                # Add today's planner
                if [[ -n "$TODAY_PLANNER" ]]; then
                    echo -e "$TODAY_PLANNER"
                fi
                echo ""
                echo "## Work Log"
                echo ""
                echo "<!-- Sessions and activities will be logged here -->"
                echo ""
                echo "## Reflections"
                echo ""
                echo "<!-- End of day thoughts -->"
                echo ""
                echo "## Personal Notes"
                echo ""
                echo "<!-- Free-form notes -->"
                echo ""
            } > "$DAILY_FILE"

            # Update database
            db_exec "UPDATE daily_notes SET vault_note_path = 'workflow/daily/$TODAY' WHERE date = '$TODAY'"
            debug_log "Created daily vault note: $DAILY_FILE"
        fi
    fi
fi

# ============================================================================
# Output Briefing
# ============================================================================

# Combine morning briefing with existing briefing
if [[ -n "$MORNING_BRIEFING" ]]; then
    BRIEFING="$MORNING_BRIEFING$BRIEFING"
fi

if [[ -n "$BRIEFING" ]]; then
    echo ""
    echo "# Workflow Briefing"
    echo ""
    echo "**Session:** $SESSION_ID"
    echo "**Project:** $PROJECT"
    if [[ -n "$BRANCH" ]]; then
        echo "**Branch:** $BRANCH"
    fi
    echo "**Date:** $(get_date) ($DAY_OF_WEEK)"
    echo ""
    echo -e "$BRIEFING"
    echo "---"
    echo "*Use \`/workflow:status\` for full dashboard, \`/workflow:track\` to manage commitments*"
    echo ""
fi

debug_log "Briefing generated for session $SESSION_ID"

exit 0
