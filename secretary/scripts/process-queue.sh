#!/bin/bash
# Secretary Plugin - Queue Item Processing
# Processes pending queue items: AI extraction, DB inserts, vault note creation
#
# Usage: process-queue.sh [--inline] [--limit N]
# --inline: Called from capture.sh (time-boxed, no vault sync)
# --limit N: Process at most N items (default: 50)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PLUGIN_ROOT/hooks/scripts/lib/utils.sh"
source "$PLUGIN_ROOT/hooks/scripts/lib/db.sh"
source "$SCRIPT_DIR/ai-extract.sh"

set +e

# Parse arguments
INLINE_MODE=false
LIMIT=50

while [[ $# -gt 0 ]]; do
    case "$1" in
        --inline) INLINE_MODE=true; shift ;;
        --limit) LIMIT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

debug_log "process-queue.sh started (inline=$INLINE_MODE, limit=$LIMIT)"

DB=$(ensure_db)
if [[ -z "$DB" ]]; then
    debug_log "process-queue.sh: database not initialized"
    exit 0
fi

# ============================================================================
# Process pending items (FIFO, priority first)
# ============================================================================

ITEMS=$(sqlite3 -separator '|' "$DB" "
    SELECT id, item_type, data, session_id, project
    FROM queue
    WHERE status = 'pending'
      AND attempts < 3
    ORDER BY priority ASC, created_at ASC
    LIMIT $LIMIT
" 2>/dev/null)

if [[ -z "$ITEMS" ]]; then
    debug_log "No pending items in queue"
    exit 0
fi

PROCESSED=0
FAILED=0

while IFS='|' read -r queue_id item_type data session_id project; do
    [[ -z "$queue_id" ]] && continue

    debug_log "Processing queue item $queue_id (type=$item_type)"

    # Mark as processing
    sqlite3 "$DB" "UPDATE queue SET status = 'processing', attempts = attempts + 1 WHERE id = $queue_id" 2>/dev/null

    PROCESS_OK=true

    case "$item_type" in

        # ====================================================================
        # USER PROMPT / TOOL OUTPUT / AGENT OUTPUT
        # Extract decisions, ideas, commitments via single AI call
        # ====================================================================
        user_prompt|tool_output|agent_output)
            # Extract the text to analyze
            TEXT_TO_ANALYZE="$data"
            # If it's JSON with input/output, combine them
            if echo "$data" | jq -e '.input' >/dev/null 2>&1; then
                TEXT_TO_ANALYZE=$(echo "$data" | jq -r '(.input // "") + "\n" + (.output // "")' 2>/dev/null)
            fi

            # Single AI call for all three types
            EXTRACTION=$(smart_extract_all_items "$TEXT_TO_ANALYZE")

            if [[ -n "$EXTRACTION" ]]; then
                # Process decisions
                DECISIONS=$(echo "$EXTRACTION" | jq -c '.decisions // []' 2>/dev/null)
                if [[ "$DECISIONS" != "[]" && -n "$DECISIONS" ]]; then
                    echo "$DECISIONS" | jq -c '.[]' 2>/dev/null | while IFS= read -r decision; do
                        D_TITLE=$(echo "$decision" | jq -r '.title' 2>/dev/null)
                        D_CATEGORY=$(echo "$decision" | jq -r '.category // "general"' 2>/dev/null)
                        D_RATIONALE=$(echo "$decision" | jq -r '.rationale // ""' 2>/dev/null)

                        if [[ -n "$D_TITLE" && "$D_TITLE" != "null" ]]; then
                            D_ID=$(get_next_id "decisions" "D")
                            db_exec "INSERT INTO decisions (id, title, description, rationale, category, project, source_session_id, source_context, status)
                                     VALUES ('$D_ID', '$(sql_escape "$D_TITLE")', '$(sql_escape "$D_TITLE")', '$(sql_escape "$D_RATIONALE")', '$(sql_escape "$D_CATEGORY")', '$(sql_escape "$project")', '$(sql_escape "$session_id")', '', 'active')"

                            # Activity log
                            db_exec "INSERT INTO activity_timeline (activity_type, entity_type, entity_id, project, title, session_id)
                                     VALUES ('decision', 'decisions', '$D_ID', '$(sql_escape "$project")', '$(sql_escape "$D_TITLE")', '$(sql_escape "$session_id")')"

                            # Update daily note
                            TODAY=$(get_date)
                            CURRENT_DECISIONS=$(sqlite3 "$DB" "SELECT COALESCE(new_decisions, '[]') FROM daily_notes WHERE date = '$TODAY'" 2>/dev/null)
                            if [[ "$CURRENT_DECISIONS" == "[]" || -z "$CURRENT_DECISIONS" ]]; then
                                CURRENT_DECISIONS="[\"$D_ID\"]"
                            else
                                CURRENT_DECISIONS=$(echo "$CURRENT_DECISIONS" | sed "s/\]$/,\"$D_ID\"]/")
                            fi
                            sqlite3 "$DB" "UPDATE daily_notes SET new_decisions = '$CURRENT_DECISIONS', updated_at = datetime('now') WHERE date = '$TODAY'" 2>/dev/null

                            debug_log "Created decision: $D_ID - $D_TITLE"
                        fi
                    done
                fi

                # Process ideas
                IDEAS=$(echo "$EXTRACTION" | jq -c '.ideas // []' 2>/dev/null)
                if [[ "$IDEAS" != "[]" && -n "$IDEAS" ]]; then
                    echo "$IDEAS" | jq -c '.[]' 2>/dev/null | while IFS= read -r idea; do
                        I_TITLE=$(echo "$idea" | jq -r '.title' 2>/dev/null)
                        I_TYPE=$(echo "$idea" | jq -r '.type // "exploration"' 2>/dev/null)
                        I_POTENTIAL=$(echo "$idea" | jq -r '.potential // ""' 2>/dev/null)

                        if [[ -n "$I_TITLE" && "$I_TITLE" != "null" ]]; then
                            I_ID=$(get_next_id "ideas" "I")
                            db_exec "INSERT INTO ideas (id, title, description, idea_type, project, source_session_id, source_context, status)
                                     VALUES ('$I_ID', '$(sql_escape "$I_TITLE")', '$(sql_escape "$I_POTENTIAL")', '$(sql_escape "$I_TYPE")', '$(sql_escape "$project")', '$(sql_escape "$session_id")', '', 'captured')"

                            db_exec "INSERT INTO activity_timeline (activity_type, entity_type, entity_id, project, title, session_id)
                                     VALUES ('idea', 'ideas', '$I_ID', '$(sql_escape "$project")', '$(sql_escape "$I_TITLE")', '$(sql_escape "$session_id")')"

                            TODAY=$(get_date)
                            CURRENT_IDEAS=$(sqlite3 "$DB" "SELECT COALESCE(new_ideas, '[]') FROM daily_notes WHERE date = '$TODAY'" 2>/dev/null)
                            if [[ "$CURRENT_IDEAS" == "[]" || -z "$CURRENT_IDEAS" ]]; then
                                CURRENT_IDEAS="[\"$I_ID\"]"
                            else
                                CURRENT_IDEAS=$(echo "$CURRENT_IDEAS" | sed "s/\]$/,\"$I_ID\"]/")
                            fi
                            sqlite3 "$DB" "UPDATE daily_notes SET new_ideas = '$CURRENT_IDEAS', updated_at = datetime('now') WHERE date = '$TODAY'" 2>/dev/null

                            debug_log "Created idea: $I_ID - $I_TITLE"
                        fi
                    done
                fi

                # Process commitments
                COMMITMENTS=$(echo "$EXTRACTION" | jq -c '.commitments // []' 2>/dev/null)
                if [[ "$COMMITMENTS" != "[]" && -n "$COMMITMENTS" ]]; then
                    echo "$COMMITMENTS" | jq -c '.[]' 2>/dev/null | while IFS= read -r commitment; do
                        C_TITLE=$(echo "$commitment" | jq -r '.title' 2>/dev/null)
                        C_PRIORITY=$(echo "$commitment" | jq -r '.priority // "medium"' 2>/dev/null)
                        C_DUE_TYPE=$(echo "$commitment" | jq -r '.due_type // "unspecified"' 2>/dev/null)

                        if [[ -n "$C_TITLE" && "$C_TITLE" != "null" ]]; then
                            C_ID=$(get_next_id "commitments" "C")
                            db_exec "INSERT INTO commitments (id, title, source_type, source_session_id, project, priority, due_type, status)
                                     VALUES ('$C_ID', '$(sql_escape "$C_TITLE")', 'conversation', '$(sql_escape "$session_id")', '$(sql_escape "$project")', '$(sql_escape "$C_PRIORITY")', '$(sql_escape "$C_DUE_TYPE")', 'pending')"

                            db_exec "INSERT INTO activity_timeline (activity_type, entity_type, entity_id, project, title, session_id)
                                     VALUES ('commitment', 'commitments', '$C_ID', '$(sql_escape "$project")', '$(sql_escape "$C_TITLE")', '$(sql_escape "$session_id")')"

                            debug_log "Created commitment: $C_ID - $C_TITLE"
                        fi
                    done
                fi
            else
                debug_log "AI extraction returned empty for queue item $queue_id"
            fi
            ;;

        # ====================================================================
        # COMMIT
        # Parse git metadata, add to activity timeline
        # ====================================================================
        commit)
            COMMIT_HASH=$(echo "$data" | jq -r '.hash // empty' 2>/dev/null)
            COMMIT_MSG=$(echo "$data" | jq -r '.subject // empty' 2>/dev/null)
            COMMIT_PROJECT=$(echo "$data" | jq -r '.project // empty' 2>/dev/null)
            COMMIT_BRANCH=$(echo "$data" | jq -r '.branch // empty' 2>/dev/null)
            COMMIT_SHORT=$(echo "$data" | jq -r '.short_hash // empty' 2>/dev/null)

            if [[ -n "$COMMIT_HASH" ]]; then
                db_exec "INSERT INTO activity_timeline (activity_type, entity_type, entity_id, project, title, details, session_id)
                         VALUES ('commit', 'commit', '$COMMIT_SHORT', '$(sql_escape "$COMMIT_PROJECT")', '$(sql_escape "$COMMIT_MSG")', '$(sql_escape "$data")', '$(sql_escape "$session_id")')"

                # Update session commits array
                if [[ -n "$session_id" ]]; then
                    CURRENT_COMMITS=$(sqlite3 "$DB" "SELECT COALESCE(commits, '[]') FROM sessions WHERE id = '$(sql_escape "$session_id")'" 2>/dev/null)
                    if [[ "$CURRENT_COMMITS" == "[]" || -z "$CURRENT_COMMITS" ]]; then
                        CURRENT_COMMITS="[\"$COMMIT_SHORT\"]"
                    else
                        CURRENT_COMMITS=$(echo "$CURRENT_COMMITS" | sed "s/\]$/,\"$COMMIT_SHORT\"]/")
                    fi
                    sqlite3 "$DB" "UPDATE sessions SET commits = '$CURRENT_COMMITS', updated_at = datetime('now') WHERE id = '$(sql_escape "$session_id")'" 2>/dev/null
                fi

                debug_log "Processed commit: $COMMIT_SHORT - $COMMIT_MSG"
            fi
            ;;

        # ====================================================================
        # STOP / SESSION END
        # Close session, generate summary
        # ====================================================================
        stop|session_end)
            STOP_SESSION=$(echo "$data" | jq -r '.session_id // empty' 2>/dev/null)
            STOP_PROJECT=$(echo "$data" | jq -r '.project // empty' 2>/dev/null)

            if [[ -z "$STOP_SESSION" ]]; then
                STOP_SESSION="$session_id"
            fi

            # Dedup: check if this session was already processed
            if [[ -n "$STOP_SESSION" ]]; then
                ALREADY_PROCESSED=$(sqlite3 "$DB" "
                    SELECT COUNT(*) FROM queue
                    WHERE session_id = '$(sql_escape "$STOP_SESSION")'
                      AND item_type IN ('stop', 'session_end')
                      AND status = 'processed'
                      AND id != $queue_id
                " 2>/dev/null || echo "0")

                if [[ "$ALREADY_PROCESSED" != "0" ]]; then
                    debug_log "Session $STOP_SESSION already processed, skipping"
                    sqlite3 "$DB" "UPDATE queue SET status = 'processed', processed_at = datetime('now') WHERE id = $queue_id" 2>/dev/null
                    PROCESSED=$((PROCESSED + 1))
                    continue
                fi

                # Calculate session duration
                SESSION_DATA=$(sqlite3 -separator '|' "$DB" "
                    SELECT started_at, COALESCE(project, '') FROM sessions WHERE id = '$(sql_escape "$STOP_SESSION")'
                " 2>/dev/null)

                if [[ -n "$SESSION_DATA" ]]; then
                    STARTED_AT=$(echo "$SESSION_DATA" | cut -d'|' -f1)
                    NOW=$(get_iso_timestamp)

                    # Calculate duration (approximate)
                    START_EPOCH=$(date_to_epoch "$STARTED_AT")
                    NOW_EPOCH=$(date +%s)
                    if [[ "$START_EPOCH" != "0" ]]; then
                        DURATION_SECS=$((NOW_EPOCH - START_EPOCH))
                        DURATION_MINS=$((DURATION_SECS / 60))
                    else
                        DURATION_SECS=0
                        DURATION_MINS=0
                    fi

                    # Get commit count for this session
                    COMMIT_COUNT=$(sqlite3 "$DB" "
                        SELECT COUNT(*) FROM activity_timeline
                        WHERE session_id = '$(sql_escape "$STOP_SESSION")' AND activity_type = 'commit'
                    " 2>/dev/null || echo "0")

                    # Generate session summary (AI if not inline mode)
                    SUMMARY=""
                    if [[ "$INLINE_MODE" == "false" ]]; then
                        # Get recent activity for this session
                        HIGHLIGHTS=$(sqlite3 "$DB" "
                            SELECT activity_type || ': ' || title
                            FROM activity_timeline
                            WHERE session_id = '$(sql_escape "$STOP_SESSION")'
                            ORDER BY timestamp DESC LIMIT 20
                        " 2>/dev/null)
                        SUMMARY=$(ai_generate_session_summary "$STOP_PROJECT" "$DURATION_MINS" "$COMMIT_COUNT" "$HIGHLIGHTS" 2>/dev/null || echo "")
                    fi

                    if [[ -z "$SUMMARY" ]]; then
                        SUMMARY="Session in $STOP_PROJECT (${DURATION_MINS}m, $COMMIT_COUNT commits)"
                    fi

                    # Update session
                    sqlite3 "$DB" "
                        UPDATE sessions SET
                            status = 'completed',
                            ended_at = '$NOW',
                            duration_seconds = $DURATION_SECS,
                            summary = '$(sql_escape "$SUMMARY")',
                            updated_at = datetime('now')
                        WHERE id = '$(sql_escape "$STOP_SESSION")'
                    " 2>/dev/null

                    db_exec "INSERT INTO activity_timeline (activity_type, entity_type, entity_id, project, title, session_id)
                             VALUES ('session_end', 'sessions', '$(sql_escape "$STOP_SESSION")', '$(sql_escape "$STOP_PROJECT")', '$(sql_escape "$SUMMARY")', '$(sql_escape "$STOP_SESSION")')"

                    debug_log "Closed session $STOP_SESSION (${DURATION_MINS}m, $COMMIT_COUNT commits)"
                fi
            fi
            ;;

        *)
            debug_log "Unknown queue item type: $item_type"
            ;;
    esac

    # Mark as processed or failed
    if [[ "$PROCESS_OK" == "true" ]]; then
        sqlite3 "$DB" "UPDATE queue SET status = 'processed', processed_at = datetime('now') WHERE id = $queue_id" 2>/dev/null
        PROCESSED=$((PROCESSED + 1))
    else
        sqlite3 "$DB" "UPDATE queue SET status = CASE WHEN attempts >= 3 THEN 'failed' ELSE 'pending' END, error_message = 'Processing error' WHERE id = $queue_id" 2>/dev/null
        FAILED=$((FAILED + 1))
    fi

done <<< "$ITEMS"

debug_log "process-queue.sh completed: $PROCESSED processed, $FAILED failed"
