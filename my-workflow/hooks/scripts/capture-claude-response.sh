#!/bin/bash
# My Workflow Plugin - Capture Claude Response
# Classifies Claude responses using Haiku and saves worthy summaries to session notes
#
# Triggered on: Stop event (when Claude finishes responding)
# Input: JSON via stdin containing transcript_path
#
# The Stop event provides:
# {
#   "session_id": "...",
#   "transcript_path": "~/.claude/projects/.../session.jsonl",
#   "cwd": "...",
#   "hook_event_name": "Stop"
# }

set -e

# Read hook input from stdin FIRST (before sourcing anything)
# stdin can only be read once, so we capture it immediately
HOOK_INPUT=$(cat 2>/dev/null || echo "")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"
source "$SCRIPT_DIR/ai-extractor.sh"

# Set the cached hook input so get_stop_summary can use it
HOOK_INPUT_CACHED="$HOOK_INPUT"
HOOK_INPUT_READ=true

# Don't fail on errors - handle gracefully
set +e

debug_log "capture-claude-response.sh triggered"
debug_log "Hook input length: ${#HOOK_INPUT}"

# ============================================================================
# Main Logic
# ============================================================================

main() {
    # Get response using the shared helper (uses cached HOOK_INPUT)
    local response
    response=$(get_stop_summary)

    if [[ -z "$response" ]]; then
        debug_log "No response content to analyze from transcript or env"
        exit 0
    fi

    # Skip very short responses (likely acknowledgments)
    if [[ ${#response} -lt 150 ]]; then
        debug_log "Response too short to analyze (${#response} chars)"
        exit 0
    fi

    # Get current session
    local session_id
    session_id=$(get_current_session_id)

    if [[ -z "$session_id" ]]; then
        # Try to get from hook input
        session_id=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    fi

    if [[ -z "$session_id" ]]; then
        debug_log "No active session, skipping response capture"
        exit 0
    fi

    # Check if vault is enabled
    if ! is_enabled "vault"; then
        debug_log "Vault disabled, skipping response capture"
        exit 0
    fi

    # Classify the response using Haiku
    debug_log "Classifying response (${#response} chars)..."
    local classification
    classification=$(ai_classify_response "$response")

    if [[ -z "$classification" ]]; then
        debug_log "Classification failed, skipping"
        exit 0
    fi

    # Parse classification result
    local should_save
    local reason
    local title

    should_save=$(echo "$classification" | jq -r '.save // false')
    reason=$(echo "$classification" | jq -r '.reason // "unknown"')
    title=$(echo "$classification" | jq -r '.title // "Summary"')

    debug_log "Classification result: save=$should_save, reason=$reason, title=$title"

    if [[ "$should_save" != "true" ]]; then
        debug_log "Response not worth saving: $reason"
        exit 0
    fi

    # Get session note path
    local session_file
    session_file=$(get_session_note_path "$session_id")

    if [[ -z "$session_file" ]]; then
        debug_log "Could not find session note path"
        exit 0
    fi

    # If session note doesn't exist yet, we'll create a minimal one
    if [[ ! -f "$session_file" ]]; then
        debug_log "Creating minimal session note: $session_file"
        local project=$(get_project_name)
        local today=$(get_date)

        mkdir -p "$(dirname "$session_file")"
        cat > "$session_file" << EOF
---
title: "Session: $project"
session_id: "$session_id"
project: "$project"
branch: "$(get_git_branch)"
started: $(get_iso_timestamp)
status: active
tags:
  - "session"
  - "$project"
---

## Summary

*Session in progress...*

## Claude Analysis

EOF
    fi

    # Extract key points from response (truncate if too long)
    local max_save_chars=4000
    local content_to_save="$response"
    if [[ ${#content_to_save} -gt $max_save_chars ]]; then
        content_to_save="${content_to_save:0:$max_save_chars}..."
    fi

    # Format the content nicely
    local formatted_content="$content_to_save"

    # Append to session note
    if append_to_session_note "$title" "$formatted_content" "$session_id"; then
        debug_log "Successfully captured Claude summary: $title"

        # Log activity
        local project=$(get_project_name)
        activity_log "claude_summary" "$title" "session" "$session_id" "$project" "{\"reason\": \"$reason\", \"chars\": ${#response}}"
    else
        debug_log "Failed to append to session note"
    fi
}

# ============================================================================
# Entry Point
# ============================================================================

main

# Always exit successfully - never block the workflow
exit 0
