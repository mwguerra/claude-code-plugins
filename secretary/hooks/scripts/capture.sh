#!/bin/bash
# Secretary Plugin - The Single Hook Script
# Architecture: "Capture Fast, Process Later"
#
# Every hook event maps here. This script MUST complete in < 50ms for most events
# (up to 15s for session_start which includes briefing output).
#
# All it does is a SQLite INSERT into the queue table.
# Heavy processing (AI extraction, vault sync) happens in the background worker.
#
# Usage: capture.sh <event_type>
# Events: session_start, user_prompt, post_tool_bash, post_tool_edit,
#          post_tool_write, post_tool_task, subagent_stop, stop, session_end

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/db.sh"
source "$SCRIPT_DIR/lib/git-detect.sh"

# Don't fail on errors - hooks must never block Claude
set +e

EVENT_TYPE="${1:-}"

if [[ -z "$EVENT_TYPE" ]]; then
    debug_log "capture.sh: no event type provided"
    exit 0
fi

debug_log "capture.sh triggered: $EVENT_TYPE"

# Ensure database exists
DB=$(ensure_db)
if [[ -z "$DB" ]]; then
    debug_log "capture.sh: database not initialized"
    exit 0
fi

PROJECT=$(get_project_name 2>/dev/null || echo "unknown")
SESSION_ID=$(get_current_session_id 2>/dev/null || echo "")

# ============================================================================
# Event Handlers
# ============================================================================

case "$EVENT_TYPE" in

    # ========================================================================
    # SESSION START
    # This is the only event that outputs to stdout (briefing)
    # Allowed up to 15s
    # ========================================================================
    session_start)
        # Cleanup orphaned sessions (fast: check process table)
        local_sessions=$(sqlite3 -separator '|' "$DB" "
            SELECT id, COALESCE(directory, '')
            FROM sessions WHERE status = 'active'
        " 2>/dev/null)

        if [[ -n "$local_sessions" ]]; then
            while IFS='|' read -r sid sdir; do
                if [[ -z "$sdir" ]]; then
                    sdir="$(pwd)"
                fi
                if ! is_claude_running_for_directory "$sdir"; then
                    sqlite3 "$DB" "
                        UPDATE sessions SET status = 'interrupted',
                            summary = 'Session interrupted (Claude closed unexpectedly)',
                            ended_at = datetime('now'), updated_at = datetime('now')
                        WHERE id = '$(sql_escape "$sid")'
                    " 2>/dev/null
                    debug_log "Cleaned up orphaned session: $sid"
                fi
            done <<< "$local_sessions"
        fi

        # Create new session
        NEW_SESSION_ID=$(generate_session_id)
        BRANCH=$(get_git_branch 2>/dev/null || echo "")
        DIRECTORY=$(pwd)
        TIMESTAMP=$(get_iso_timestamp)
        ESCAPED_DIR=$(sql_escape "$DIRECTORY")

        sqlite3 "$DB" "
            INSERT INTO sessions (id, project, branch, directory, started_at, status)
            VALUES ('$NEW_SESSION_ID', '$(sql_escape "$PROJECT")', '$(sql_escape "$BRANCH")', '$ESCAPED_DIR', '$TIMESTAMP', 'active')
        " 2>/dev/null

        set_current_session "$NEW_SESSION_ID"

        # Ensure daily note
        TODAY=$(get_date)
        sqlite3 "$DB" "INSERT OR IGNORE INTO daily_notes (id, date) VALUES ('$TODAY', '$TODAY')" 2>/dev/null
        sqlite3 "$DB" "
            UPDATE daily_notes
            SET first_activity_at = COALESCE(first_activity_at, '$TIMESTAMP'),
                last_activity_at = '$TIMESTAMP',
                sessions_count = sessions_count + 1,
                updated_at = datetime('now')
            WHERE date = '$TODAY'
        " 2>/dev/null

        # Time-boxed processing of pending queue items (5s, up to 10 items)
        QUEUE_COUNT=$(get_queue_count)
        if [[ "$QUEUE_COUNT" -gt 0 ]]; then
            WORKER_SCRIPT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}/scripts/process-queue.sh"
            if [[ -f "$WORKER_SCRIPT" ]]; then
                debug_log "Processing up to 10 pending queue items (time-boxed 5s)"
                timeout 5 bash "$WORKER_SCRIPT" --inline --limit 10 2>/dev/null || true
            fi
        fi

        # Generate briefing (SQL queries only, no AI)
        BRIEFING_SCRIPT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$SCRIPT_DIR")")}/scripts/briefing.sh"
        if [[ -f "$BRIEFING_SCRIPT" ]]; then
            bash "$BRIEFING_SCRIPT" "$NEW_SESSION_ID" "$PROJECT" "$BRANCH" 2>/dev/null || true
        fi
        ;;

    # ========================================================================
    # USER PROMPT
    # ========================================================================
    user_prompt)
        PROMPT=$(get_user_prompt)

        # Skip very short prompts (< 15 chars)
        if [[ ${#PROMPT} -lt 15 ]]; then
            debug_log "Skipping short user prompt (${#PROMPT} chars)"
            exit 0
        fi

        # Truncate very long prompts for queue storage
        if [[ ${#PROMPT} -gt 5000 ]]; then
            PROMPT="${PROMPT:0:5000}..."
        fi

        queue_item "user_prompt" "$PROMPT" 5 "$SESSION_ID" "$PROJECT"
        debug_log "Queued user prompt (${#PROMPT} chars)"
        ;;

    # ========================================================================
    # POST TOOL USE - BASH
    # Special handling: detect git commits
    # ========================================================================
    post_tool_bash)
        TOOL_INPUT=$(get_tool_input)
        TOOL_OUTPUT=$(get_tool_output)

        # Fast check: is this a git commit?
        if is_git_commit "$TOOL_INPUT"; then
            # Get commit metadata (fast: git log -1 only)
            COMMIT_DATA=$(get_commit_metadata)
            if [[ -n "$COMMIT_DATA" && "$COMMIT_DATA" != "{}" ]]; then
                queue_item "commit" "$COMMIT_DATA" 3 "$SESSION_ID" "$PROJECT"
                debug_log "Queued commit detection"

                # Update daily note commit count
                TODAY=$(get_date)
                sqlite3 "$DB" "
                    UPDATE daily_notes SET commits_count = commits_count + 1, updated_at = datetime('now')
                    WHERE date = '$TODAY'
                " 2>/dev/null
            fi
        fi

        # Queue the tool output if substantial
        if [[ ${#TOOL_OUTPUT} -ge 20 ]]; then
            # Truncate large outputs
            if [[ ${#TOOL_OUTPUT} -gt 5000 ]]; then
                TOOL_OUTPUT="${TOOL_OUTPUT:0:5000}..."
            fi
            # Include the command for context
            local combined
            combined=$(jq -n --arg input "$TOOL_INPUT" --arg output "$TOOL_OUTPUT" '{input: $input, output: $output}' 2>/dev/null || echo "$TOOL_OUTPUT")
            queue_item "tool_output" "$combined" 7 "$SESSION_ID" "$PROJECT"
            debug_log "Queued bash tool output"
        fi
        ;;

    # ========================================================================
    # POST TOOL USE - EDIT / WRITE / TASK
    # ========================================================================
    post_tool_edit|post_tool_write|post_tool_task)
        TOOL_OUTPUT=$(get_tool_output)

        # Skip if output is too short
        if [[ ${#TOOL_OUTPUT} -lt 20 ]]; then
            debug_log "Skipping short tool output (${#TOOL_OUTPUT} chars)"
            exit 0
        fi

        # Truncate large outputs
        if [[ ${#TOOL_OUTPUT} -gt 5000 ]]; then
            TOOL_OUTPUT="${TOOL_OUTPUT:0:5000}..."
        fi

        queue_item "tool_output" "$TOOL_OUTPUT" 7 "$SESSION_ID" "$PROJECT"
        debug_log "Queued $EVENT_TYPE output"
        ;;

    # ========================================================================
    # SUBAGENT STOP
    # ========================================================================
    subagent_stop)
        AGENT_OUTPUT=$(get_agent_output)

        if [[ ${#AGENT_OUTPUT} -lt 20 ]]; then
            debug_log "Skipping short agent output"
            exit 0
        fi

        if [[ ${#AGENT_OUTPUT} -gt 5000 ]]; then
            AGENT_OUTPUT="${AGENT_OUTPUT:0:5000}..."
        fi

        queue_item "agent_output" "$AGENT_OUTPUT" 6 "$SESSION_ID" "$PROJECT"
        debug_log "Queued agent output"
        ;;

    # ========================================================================
    # STOP
    # ========================================================================
    stop)
        # Read stdin JSON (transcript_path, session_id)
        INPUT_JSON=$(read_hook_input)
        TRANSCRIPT_PATH=""
        if [[ -n "$INPUT_JSON" ]]; then
            TRANSCRIPT_PATH=$(echo "$INPUT_JSON" | jq -r '.transcript_path // empty' 2>/dev/null)
            if [[ "$TRANSCRIPT_PATH" == "~/"* ]]; then
                TRANSCRIPT_PATH="${HOME}${TRANSCRIPT_PATH:1}"
            fi
        fi

        STOP_DATA=$(jq -n \
            --arg transcript "$TRANSCRIPT_PATH" \
            --arg session "$SESSION_ID" \
            --arg project "$PROJECT" \
            '{transcript_path: $transcript, session_id: $session, project: $project}' 2>/dev/null || echo "{}")

        queue_item "stop" "$STOP_DATA" 2 "$SESSION_ID" "$PROJECT"

        # Update session status
        if [[ -n "$SESSION_ID" ]]; then
            sqlite3 "$DB" "
                UPDATE sessions SET status = 'ending', updated_at = datetime('now')
                WHERE id = '$(sql_escape "$SESSION_ID")'
            " 2>/dev/null
        fi

        debug_log "Queued stop event"
        ;;

    # ========================================================================
    # SESSION END
    # ========================================================================
    session_end)
        INPUT_JSON=$(read_hook_input)
        TRANSCRIPT_PATH=""
        if [[ -n "$INPUT_JSON" ]]; then
            TRANSCRIPT_PATH=$(echo "$INPUT_JSON" | jq -r '.transcript_path // empty' 2>/dev/null)
            if [[ "$TRANSCRIPT_PATH" == "~/"* ]]; then
                TRANSCRIPT_PATH="${HOME}${TRANSCRIPT_PATH:1}"
            fi
        fi

        # Dedup check: skip if stop already queued for this session
        if [[ -n "$SESSION_ID" ]]; then
            STOP_EXISTS=$(sqlite3 "$DB" "
                SELECT COUNT(*) FROM queue
                WHERE session_id = '$(sql_escape "$SESSION_ID")'
                  AND item_type = 'stop'
                  AND status IN ('pending', 'processing', 'processed')
            " 2>/dev/null || echo "0")

            if [[ "$STOP_EXISTS" != "0" ]]; then
                debug_log "Stop already queued for session $SESSION_ID, skipping session_end"
                # Just update status
                sqlite3 "$DB" "
                    UPDATE sessions SET status = 'ended', updated_at = datetime('now')
                    WHERE id = '$(sql_escape "$SESSION_ID")'
                " 2>/dev/null
                exit 0
            fi
        fi

        SESSION_END_DATA=$(jq -n \
            --arg transcript "$TRANSCRIPT_PATH" \
            --arg session "$SESSION_ID" \
            --arg project "$PROJECT" \
            '{transcript_path: $transcript, session_id: $session, project: $project}' 2>/dev/null || echo "{}")

        queue_item "session_end" "$SESSION_END_DATA" 2 "$SESSION_ID" "$PROJECT"

        # Update session status
        if [[ -n "$SESSION_ID" ]]; then
            sqlite3 "$DB" "
                UPDATE sessions SET status = 'ended', updated_at = datetime('now')
                WHERE id = '$(sql_escape "$SESSION_ID")'
            " 2>/dev/null
        fi

        # Update daily note activity
        TODAY=$(get_date)
        sqlite3 "$DB" "
            UPDATE daily_notes SET last_activity_at = datetime('now'), updated_at = datetime('now')
            WHERE date = '$TODAY'
        " 2>/dev/null

        debug_log "Queued session_end event"
        ;;

    *)
        debug_log "Unknown event type: $EVENT_TYPE"
        ;;
esac

exit 0
