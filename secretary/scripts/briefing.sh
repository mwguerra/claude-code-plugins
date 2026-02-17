#!/bin/bash
# Secretary Plugin - Session Briefing Generator
# SQL-only queries — no AI calls. Must complete in < 2s.
#
# Usage: briefing.sh <session_id> <project> <branch>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PLUGIN_ROOT/hooks/scripts/lib/utils.sh"
source "$PLUGIN_ROOT/hooks/scripts/lib/db.sh"

set +e

SESSION_ID="${1:-}"
PROJECT="${2:-unknown}"
BRANCH="${3:-}"

if ! is_enabled "briefing"; then
    exit 0
fi

DB=$(ensure_db)
if [[ -z "$DB" ]]; then
    exit 0
fi

# ============================================================================
# Date Context
# ============================================================================

TODAY=$(get_date)
DAY_OF_WEEK=$(date +%A)

# ============================================================================
# Previous Day Summary (first session of the day only)
# ============================================================================

FIRST_SESSION_TODAY=$(sqlite3 "$DB" "
    SELECT COUNT(*) FROM sessions
    WHERE date(started_at) = date('now') AND id != '$(sql_escape "$SESSION_ID")'
" 2>/dev/null || echo "0")

MORNING_BRIEFING=""

if [[ "$FIRST_SESSION_TODAY" == "0" ]]; then
    YESTERDAY=$(days_ago_date 1)
    YESTERDAY_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_notes WHERE date = '$YESTERDAY'" 2>/dev/null || echo "0")

    if [[ "$YESTERDAY_EXISTS" != "0" ]]; then
        YESTERDAY_DATA=$(sqlite3 -separator '|' "$DB" "
            SELECT sessions_count, commits_count, COALESCE(completed_commitments,'[]'),
                   COALESCE(new_ideas,'[]'), COALESCE(new_decisions,'[]')
            FROM daily_notes WHERE date = '$YESTERDAY'
        " 2>/dev/null)

        if [[ -n "$YESTERDAY_DATA" ]]; then
            IFS='|' read -r y_sessions y_commits y_completed y_ideas y_decisions <<< "$YESTERDAY_DATA"
            MORNING_BRIEFING+="## Yesterday ($YESTERDAY)\n"
            MORNING_BRIEFING+="- Sessions: ${y_sessions:-0} | Commits: ${y_commits:-0}\n"

            # Count JSON array items
            completed_count=0
            ideas_count=0
            decisions_count=0
            [[ -n "$y_completed" && "$y_completed" != "[]" ]] && completed_count=$(echo "$y_completed" | jq 'length' 2>/dev/null || echo "0")
            [[ -n "$y_ideas" && "$y_ideas" != "[]" ]] && ideas_count=$(echo "$y_ideas" | jq 'length' 2>/dev/null || echo "0")
            [[ -n "$y_decisions" && "$y_decisions" != "[]" ]] && decisions_count=$(echo "$y_decisions" | jq 'length' 2>/dev/null || echo "0")

            [[ "$completed_count" -gt 0 ]] && MORNING_BRIEFING+="- Completed: $completed_count items\n"
            [[ "$ideas_count" -gt 0 ]] && MORNING_BRIEFING+="- Ideas captured: $ideas_count\n"
            [[ "$decisions_count" -gt 0 ]] && MORNING_BRIEFING+="- Decisions made: $decisions_count\n"
            MORNING_BRIEFING+="\n"
        fi
    fi
fi

# ============================================================================
# Pending Commitments
# ============================================================================

COMMITMENT_SECTION=""

if [[ "$(get_config '.briefing.includePendingCommitments' 'true')" == "true" ]]; then
    PROJECT_ESCAPED=$(sql_escape "$PROJECT")

    OVERDUE=$(sqlite3 -separator '|' "$DB" "
        SELECT id, title, due_date, priority
        FROM commitments
        WHERE status IN ('pending', 'in_progress')
          AND due_date IS NOT NULL AND due_date < date('now')
        ORDER BY due_date ASC LIMIT 5
    " 2>/dev/null)

    if [[ -n "$OVERDUE" ]]; then
        COMMITMENT_SECTION+="**Overdue:**\n"
        while IFS='|' read -r id title due priority; do
            COMMITMENT_SECTION+="- [$id] $title (due $due)\n"
        done <<< "$OVERDUE"
        COMMITMENT_SECTION+="\n"
    fi

    DUE_TODAY=$(sqlite3 -separator '|' "$DB" "
        SELECT id, title, priority
        FROM commitments
        WHERE status IN ('pending', 'in_progress') AND due_date = date('now')
        ORDER BY priority DESC LIMIT 5
    " 2>/dev/null)

    if [[ -n "$DUE_TODAY" ]]; then
        COMMITMENT_SECTION+="**Due Today:**\n"
        while IFS='|' read -r id title priority; do
            COMMITMENT_SECTION+="- [$id] $title\n"
        done <<< "$DUE_TODAY"
        COMMITMENT_SECTION+="\n"
    fi

    UPCOMING=$(sqlite3 -separator '|' "$DB" "
        SELECT id, title, due_date
        FROM commitments
        WHERE status IN ('pending', 'in_progress')
          AND due_date > date('now') AND due_date <= date('now', '+7 days')
        ORDER BY due_date ASC LIMIT 5
    " 2>/dev/null)

    if [[ -n "$UPCOMING" ]]; then
        COMMITMENT_SECTION+="**Upcoming (7 days):**\n"
        while IFS='|' read -r id title due; do
            COMMITMENT_SECTION+="- [$id] $title (due $due)\n"
        done <<< "$UPCOMING"
        COMMITMENT_SECTION+="\n"
    fi
fi

# ============================================================================
# Recent Decisions
# ============================================================================

DECISIONS_SECTION=""

if [[ "$(get_config '.briefing.includeRecentDecisions' 'true')" == "true" ]]; then
    DAYS_BACK=$(get_config '.briefing.daysBack' '7')
    PROJECT_ESCAPED=$(sql_escape "$PROJECT")

    RECENT_DECISIONS=$(sqlite3 -separator '|' "$DB" "
        SELECT id, title, category
        FROM decisions
        WHERE status = 'active'
          AND (project = '$PROJECT_ESCAPED' OR project IS NULL)
          AND created_at >= datetime('now', '-$DAYS_BACK days')
        ORDER BY created_at DESC LIMIT 5
    " 2>/dev/null)

    if [[ -n "$RECENT_DECISIONS" ]]; then
        DECISIONS_SECTION+="## Recent Decisions\n\n"
        while IFS='|' read -r id title category; do
            DECISIONS_SECTION+="- [$id] $title ($category)\n"
        done <<< "$RECENT_DECISIONS"
        DECISIONS_SECTION+="\n"
    fi
fi

# ============================================================================
# Active Goals
# ============================================================================

GOALS_SECTION=""

if [[ "$(get_config '.briefing.includeGoalProgress' 'true')" == "true" ]]; then
    ACTIVE_GOALS=$(sqlite3 -separator '|' "$DB" "
        SELECT id, title, progress_percentage, target_date
        FROM goals
        WHERE status = 'active'
        ORDER BY progress_percentage DESC LIMIT 5
    " 2>/dev/null)

    if [[ -n "$ACTIVE_GOALS" ]]; then
        GOALS_SECTION+="## Active Goals\n\n"
        while IFS='|' read -r id title progress target; do
            # ASCII progress bar
            filled=$((progress / 10))
            bar=""
            for ((i=0; i<10; i++)); do
                if [[ $i -lt $filled ]]; then bar+="="; else bar+="-"; fi
            done
            if [[ -n "$target" ]]; then
                GOALS_SECTION+="- [$id] $title [$bar] ${progress}% (target: $target)\n"
            else
                GOALS_SECTION+="- [$id] $title [$bar] ${progress}%\n"
            fi
        done <<< "$ACTIVE_GOALS"
        GOALS_SECTION+="\n"
    fi
fi

# ============================================================================
# GitHub Items (from cache only, no API calls)
# ============================================================================

GITHUB_SECTION=""

if is_enabled "github"; then
    CACHED_DATA=$(sqlite3 "$DB" "
        SELECT data FROM github_cache
        WHERE id = 'combined' AND expires_at > datetime('now')
    " 2>/dev/null)

    if [[ -n "$CACHED_DATA" ]]; then
        ISSUES_JSON=$(echo "$CACHED_DATA" | jq -r '.issues // []' 2>/dev/null)
        if [[ "$ISSUES_JSON" != "[]" && -n "$ISSUES_JSON" ]]; then
            GITHUB_SECTION+="**Assigned Issues:**\n"
            echo "$ISSUES_JSON" | jq -c '.[]' 2>/dev/null | head -5 | while IFS= read -r line; do
                num=$(echo "$line" | jq -r '.number')
                title=$(echo "$line" | jq -r '.title')
                repo=$(echo "$line" | jq -r '.repository.name // .repository // "unknown"')
                GITHUB_SECTION+="- #$num $title ($repo)\n"
            done
            GITHUB_SECTION+="\n"
        fi

        REVIEWS_JSON=$(echo "$CACHED_DATA" | jq -r '.reviews // []' 2>/dev/null)
        if [[ "$REVIEWS_JSON" != "[]" && -n "$REVIEWS_JSON" ]]; then
            GITHUB_SECTION+="**PRs Needing Review:**\n"
            echo "$REVIEWS_JSON" | jq -c '.[]' 2>/dev/null | head -5 | while IFS= read -r line; do
                num=$(echo "$line" | jq -r '.number')
                title=$(echo "$line" | jq -r '.title')
                GITHUB_SECTION+="- #$num $title\n"
            done
            GITHUB_SECTION+="\n"
        fi
    fi
fi

# ============================================================================
# Queue Status
# ============================================================================

QUEUE_COUNT=$(get_queue_count)
QUEUE_NOTE=""
if [[ "$QUEUE_COUNT" -gt 0 ]]; then
    QUEUE_NOTE="*$QUEUE_COUNT items pending in queue*\n"
fi

# ============================================================================
# Ideas Inbox
# ============================================================================

IDEAS_SECTION=""

RECENT_IDEAS=$(sqlite3 -separator '|' "$DB" "
    SELECT id, title, idea_type
    FROM ideas WHERE status = 'captured'
    ORDER BY created_at DESC LIMIT 5
" 2>/dev/null)

if [[ -n "$RECENT_IDEAS" ]]; then
    IDEAS_SECTION+="## Ideas Inbox\n\n"
    while IFS='|' read -r id title idea_type; do
        IDEAS_SECTION+="- [$id] $title ($idea_type)\n"
    done <<< "$RECENT_IDEAS"
    IDEAS_SECTION+="\n"
fi

# ============================================================================
# Output Briefing
# ============================================================================

HAS_CONTENT=false
[[ -n "$MORNING_BRIEFING" ]] && HAS_CONTENT=true
[[ -n "$COMMITMENT_SECTION" ]] && HAS_CONTENT=true
[[ -n "$DECISIONS_SECTION" ]] && HAS_CONTENT=true
[[ -n "$GOALS_SECTION" ]] && HAS_CONTENT=true
[[ -n "$GITHUB_SECTION" ]] && HAS_CONTENT=true
[[ -n "$IDEAS_SECTION" ]] && HAS_CONTENT=true

if [[ "$HAS_CONTENT" == "true" ]]; then
    echo ""
    echo "# Secretary Briefing"
    echo ""
    echo "**Session:** $SESSION_ID | **Project:** $PROJECT | **Date:** $TODAY ($DAY_OF_WEEK)"
    [[ -n "$BRANCH" ]] && echo "**Branch:** $BRANCH"
    echo ""

    [[ -n "$MORNING_BRIEFING" ]] && echo -e "$MORNING_BRIEFING"
    [[ -n "$COMMITMENT_SECTION" ]] && echo -e "## Commitments\n\n$COMMITMENT_SECTION"
    [[ -n "$DECISIONS_SECTION" ]] && echo -e "$DECISIONS_SECTION"
    [[ -n "$GOALS_SECTION" ]] && echo -e "$GOALS_SECTION"
    [[ -n "$GITHUB_SECTION" ]] && echo -e "## GitHub\n\n$GITHUB_SECTION"
    [[ -n "$IDEAS_SECTION" ]] && echo -e "$IDEAS_SECTION"
    [[ -n "$QUEUE_NOTE" ]] && echo -e "$QUEUE_NOTE"

    echo "---"
    echo "*Use \`/secretary:status\` for full dashboard, \`/secretary:track\` to manage commitments*"
    echo ""
fi

exit 0
