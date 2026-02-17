#!/bin/bash
# article-stats.sh - Efficient article statistics extraction for article-writer
# Usage: ./article-stats.sh [article_tasks.json path] [--json|--summary|--next|--next5]
#
# This script efficiently extracts statistics from article_tasks.json without loading
# the entire file into memory, saving tokens and context when used by Claude.

set -e

# Handle --help as first argument
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [article_tasks.json path] [mode] [args...]"
    echo ""
    echo "Read-only Modes:"
    echo "  --summary          Full text summary (default)"
    echo "  --json             Full JSON output for programmatic use"
    echo "  --next             Next recommended article"
    echo "  --next5            Next 5 recommended articles"
    echo "  --status           Article counts by status"
    echo "  --area             Article counts by area"
    echo "  --difficulty       Article counts by difficulty"
    echo "  --author           Article counts by author"
    echo "  --effort           Article counts by estimated effort"
    echo "  --remaining        Count of remaining articles"
    echo "  --completion       Completion statistics"
    echo "  --stuck            Show articles stuck in_progress"
    echo ""
    echo "Article Query Modes:"
    echo "  --get <id> [key]   Get article by ID, optionally extract specific key"
    echo "                     Examples: --get 5"
    echo "                               --get 5 title"
    echo "                               --get 5 status"
    echo "                               --get 5 author.id"
    echo "  --ids              List all article IDs"
    echo "  --pending-ids      List pending article IDs"
    echo ""
    echo "Write Modes (modify article_tasks.json):"
    echo "  --set-status <status> <id1> [id2...]  Update status for one or more articles"
    echo "                     Valid statuses: pending, in_progress, draft, review,"
    echo "                                     published, archived"
    echo "                     Examples: --set-status draft 5"
    echo "                               --set-status published 5 6 7"
    echo ""
    echo "  --set-error <id> <message>  Set error_note for an article"
    echo "  --clear-error <id>          Clear error_note for an article"
    echo ""
    echo "  --help, -h         Show this help"
    exit 0
fi

# Default path
ARTICLES_FILE="${1:-.article_writer/article_tasks.json}"
MODE="${2:---summary}"

# Check if article_tasks.json exists
if [[ ! -f "$ARTICLES_FILE" ]]; then
    echo "Error: $ARTICLES_FILE not found" >&2
    echo "Run /article-writer:init first." >&2
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    echo "Install with: brew install jq (macOS) or apt install jq (Linux)" >&2
    exit 1
fi

# Function to get all articles (handles both array and object formats)
get_articles() {
    jq -r '
    if type == "array" then .
    elif .articles then .articles
    else [] end
    ' "$ARTICLES_FILE"
}

# Function to get counts by status
get_status_counts() {
    get_articles | jq -r '
    group_by(.status) |
    map({status: .[0].status, count: length}) |
    sort_by(.status) |
    .[] | "\(.status): \(.count)"
    '
}

# Function to get counts by area
get_area_counts() {
    get_articles | jq -r '
    group_by(.area) |
    map({area: .[0].area, count: length}) |
    sort_by(-.count) |
    .[] | "\(.area): \(.count)"
    '
}

# Function to get counts by difficulty
get_difficulty_counts() {
    get_articles | jq -r '
    group_by(.difficulty) |
    map({difficulty: .[0].difficulty, count: length}) |
    sort_by(.difficulty) |
    .[] | "\(.difficulty): \(.count)"
    '
}

# Function to get counts by author
get_author_counts() {
    get_articles | jq -r '
    map(.author.id // "(default)") |
    group_by(.) |
    map({author: .[0], count: length}) |
    sort_by(-.count) |
    .[] | "\(.author): \(.count)"
    '
}

# Function to get counts by estimated effort
get_effort_counts() {
    get_articles | jq -r '
    group_by(.estimated_effort) |
    map({effort: .[0].estimated_effort, count: length}) |
    sort_by(.effort) |
    .[] | "\(.effort): \(.count)"
    '
}

# Function to get remaining articles (not published/archived)
get_remaining_articles() {
    get_articles | jq -r '
    map(select(.status != "published" and .status != "archived")) |
    length
    '
}

# Function to get total articles
get_total_articles() {
    get_articles | jq -r 'length'
}

# Function to get completion stats
get_completion_stats() {
    get_articles | jq -r '
    {
      total: length,
      published: [.[] | select(.status == "published")] | length,
      draft: [.[] | select(.status == "draft")] | length,
      review: [.[] | select(.status == "review")] | length,
      in_progress: [.[] | select(.status == "in_progress")] | length,
      pending: [.[] | select(.status == "pending")] | length,
      archived: [.[] | select(.status == "archived")] | length,
      remaining: [.[] | select(.status != "published" and .status != "archived")] | length
    } |
    "Total: \(.total)\nPublished: \(.published)\nDraft: \(.draft)\nReview: \(.review)\nIn Progress: \(.in_progress)\nPending: \(.pending)\nArchived: \(.archived)\nRemaining: \(.remaining)\nCompletion: \(if .total > 0 then ((.published / .total * 100) | floor) else 0 end)%"
    '
}

# Function to get stuck articles (in_progress status)
get_stuck_articles() {
    get_articles | jq -r '
    [.[] | select(.status == "in_progress")] |
    if length == 0 then
      "No articles stuck in_progress"
    else
      .[] | "ID: \(.id)\nTitle: \(.title)\nArea: \(.area)\nAuthor: \(.author.id // "(default)")\nError: \(.error_note // "none")\n---"
    end
    '
}

# Function to find next recommended article
# Priority: pending status, then by ID (lower first)
get_next_article() {
    get_articles | jq -r '
    # Find pending articles
    [.[] | select(.status == "pending")] |

    # Sort by ID (numeric, ascending)
    sort_by(.id) |

    # Get first article
    .[0] // null |

    if . == null then
      "No pending articles found"
    else
      "ID: \(.id)\nTitle: \(.title)\nArea: \(.area)\nDifficulty: \(.difficulty)\nContent Type: \(.content_type)\nEffort: \(.estimated_effort)\nAuthor: \(.author.name // .author.id // "(default)")\nLanguages: \(.author.languages // ["default"] | join(", "))"
    end
    '
}

# Function to find next 5 recommended articles
get_next5_articles() {
    get_articles | jq -r '
    # Find pending articles
    [.[] | select(.status == "pending")] |

    # Sort by ID
    sort_by(.id) |

    # Get first 5
    .[0:5] |

    if length == 0 then
      "No pending articles found"
    else
      to_entries |
      map("\(.key + 1). [ID \(.value.id)] \(.value.title) (\(.value.area), \(.value.difficulty))") |
      join("\n")
    end
    '
}

# Function to get an article by ID
get_article_by_id() {
    local article_id="$1"
    local key="$2"

    if [[ -z "$article_id" ]]; then
        echo "Error: Article ID required" >&2
        exit 1
    fi

    local result
    result=$(get_articles | jq --argjson id "$article_id" '
    .[] | select(.id == $id)
    ')

    if [[ -z "$result" ]] || [[ "$result" == "null" ]]; then
        echo "Error: Article '$article_id' not found" >&2
        exit 1
    fi

    if [[ -z "$key" ]]; then
        echo "$result" | jq '.'
    else
        # Handle nested keys like "author.id"
        echo "$result" | jq -r --arg key "$key" 'getpath($key | split("."))'
    fi
}

# Function to get all article IDs
get_all_ids() {
    get_articles | jq -r '.[].id' | sort -n
}

# Function to get pending article IDs
get_pending_ids() {
    get_articles | jq -r '[.[] | select(.status == "pending") | .id] | sort | .[]'
}

# Function to update article status by ID (modifies article_tasks.json)
set_article_status() {
    local new_status="$1"
    shift
    local article_ids=("$@")

    # Validate status
    local valid_statuses="pending in_progress draft review published archived"
    if ! echo "$valid_statuses" | grep -qw "$new_status"; then
        echo "Error: Invalid status '$new_status'" >&2
        echo "Valid statuses: $valid_statuses" >&2
        exit 1
    fi

    if [[ ${#article_ids[@]} -eq 0 ]]; then
        echo "Error: At least one article ID required" >&2
        exit 1
    fi

    # Convert article IDs array to JSON array (as numbers)
    local ids_json
    ids_json=$(printf '%s\n' "${article_ids[@]}" | jq -R 'tonumber' | jq -s .)

    # Create backup
    cp "$ARTICLES_FILE" "${ARTICLES_FILE}.bak"

    # Update articles
    local updated
    updated=$(jq --arg status "$new_status" --argjson ids "$ids_json" '
    def update_status:
      if .id as $aid | $ids | index($aid) != null then
        .status = $status |
        .updated_at = (now | todate) |
        if $status == "published" then
          .published_at = (now | todate)
        elif $status == "draft" then
          .written_at = (now | todate)
        elif $status == "in_progress" and (.written_at == null) then
          .
        else
          .
        end
      else
        .
      end;

    if type == "array" then
      [.[] | update_status]
    else
      .articles = [.articles[] | update_status] |
      .metadata.last_updated = (now | todate)
    end
    ' "$ARTICLES_FILE")

    # Validate the result is valid JSON
    if ! echo "$updated" | jq empty 2>/dev/null; then
        echo "Error: Failed to update articles (invalid JSON produced)" >&2
        mv "${ARTICLES_FILE}.bak" "$ARTICLES_FILE"
        exit 1
    fi

    # Write the updated file
    echo "$updated" > "$ARTICLES_FILE"

    # Verify the IDs were found and updated
    local updated_count
    updated_count=$(get_articles | jq --arg status "$new_status" --argjson ids "$ids_json" '
    [.[] | select(.id as $aid | $ids | index($aid) != null) | select(.status == $status)] | length
    ')

    local requested_count=${#article_ids[@]}

    if [[ "$updated_count" -eq "$requested_count" ]]; then
        echo "Successfully updated $updated_count article(s) to status '$new_status':"
        for id in "${article_ids[@]}"; do
            echo "  - ID $id"
        done
        rm -f "${ARTICLES_FILE}.bak"
    else
        echo "Warning: Requested $requested_count article(s), but only $updated_count were updated" >&2
        echo "Some article IDs may not exist. Check your IDs and try again." >&2
        rm -f "${ARTICLES_FILE}.bak"
    fi
}

# Function to set error note for an article
set_article_error() {
    local article_id="$1"
    local error_message="$2"

    if [[ -z "$article_id" ]] || [[ -z "$error_message" ]]; then
        echo "Error: Article ID and error message required" >&2
        exit 1
    fi

    # Create backup
    cp "$ARTICLES_FILE" "${ARTICLES_FILE}.bak"

    # Update article
    local updated
    updated=$(jq --argjson id "$article_id" --arg error "$error_message" '
    def update_error:
      if .id == $id then
        .error_note = $error |
        .updated_at = (now | todate)
      else
        .
      end;

    if type == "array" then
      [.[] | update_error]
    else
      .articles = [.articles[] | update_error] |
      .metadata.last_updated = (now | todate)
    end
    ' "$ARTICLES_FILE")

    # Validate and write
    if ! echo "$updated" | jq empty 2>/dev/null; then
        echo "Error: Failed to update article (invalid JSON produced)" >&2
        mv "${ARTICLES_FILE}.bak" "$ARTICLES_FILE"
        exit 1
    fi

    echo "$updated" > "$ARTICLES_FILE"
    rm -f "${ARTICLES_FILE}.bak"
    echo "Set error_note for article ID $article_id"
}

# Function to clear error note for an article
clear_article_error() {
    local article_id="$1"

    if [[ -z "$article_id" ]]; then
        echo "Error: Article ID required" >&2
        exit 1
    fi

    # Create backup
    cp "$ARTICLES_FILE" "${ARTICLES_FILE}.bak"

    # Update article
    local updated
    updated=$(jq --argjson id "$article_id" '
    def clear_error:
      if .id == $id then
        .error_note = null |
        .updated_at = (now | todate)
      else
        .
      end;

    if type == "array" then
      [.[] | clear_error]
    else
      .articles = [.articles[] | clear_error] |
      .metadata.last_updated = (now | todate)
    end
    ' "$ARTICLES_FILE")

    # Validate and write
    if ! echo "$updated" | jq empty 2>/dev/null; then
        echo "Error: Failed to update article (invalid JSON produced)" >&2
        mv "${ARTICLES_FILE}.bak" "$ARTICLES_FILE"
        exit 1
    fi

    echo "$updated" > "$ARTICLES_FILE"
    rm -f "${ARTICLES_FILE}.bak"
    echo "Cleared error_note for article ID $article_id"
}

# Function to output full JSON stats
get_json_stats() {
    get_articles | jq '
    # Store all articles first
    . as $all |

    # Find pending articles sorted by ID
    [.[] | select(.status == "pending")] | sort_by(.id) as $pending |

    {
      summary: {
        total: ($all | length),
        published: ([$all[] | select(.status == "published")] | length),
        draft: ([$all[] | select(.status == "draft")] | length),
        review: ([$all[] | select(.status == "review")] | length),
        in_progress: ([$all[] | select(.status == "in_progress")] | length),
        pending: ([$all[] | select(.status == "pending")] | length),
        archived: ([$all[] | select(.status == "archived")] | length),
        remaining: ([$all[] | select(.status != "published" and .status != "archived")] | length),
        completion_percent: (if ($all | length) > 0 then (([$all[] | select(.status == "published")] | length) / ($all | length) * 100 | floor) else 0 end)
      },
      by_status: (
        $all | group_by(.status // "unknown") |
        map({key: (.[0].status // "unknown"), value: length}) |
        from_entries
      ),
      by_area: (
        $all | group_by(.area // "unset") |
        map({key: (.[0].area // "unset"), value: length}) |
        sort_by(-.value) |
        from_entries
      ),
      by_difficulty: (
        $all | group_by(.difficulty // "unset") |
        map({key: (.[0].difficulty // "unset"), value: length}) |
        from_entries
      ),
      by_author: (
        $all | group_by(.author.id // "(default)") |
        map({key: (.[0].author.id // "(default)"), value: length}) |
        from_entries
      ),
      by_effort: (
        $all | group_by(.estimated_effort // "unset") |
        map({key: (.[0].estimated_effort // "unset"), value: length}) |
        from_entries
      ),
      stuck_articles: (
        [$all[] | select(.status == "in_progress") | {id: .id, title: .title, error: .error_note}]
      ),
      next_article: ($pending[0] // null | if . then {id: .id, title: .title, area: .area, difficulty: .difficulty, author: (.author.id // "(default)")} else null end),
      next_5_articles: ([$pending[0:5][] | {id: .id, title: .title, area: .area, difficulty: .difficulty}])
    }
    '
}

# Main logic based on mode
case "$MODE" in
    --json)
        get_json_stats
        ;;
    --summary)
        echo "=== Article Queue Statistics ==="
        echo ""
        get_completion_stats
        echo ""
        echo "--- By Status ---"
        get_status_counts
        echo ""
        echo "--- By Area ---"
        get_area_counts
        echo ""
        echo "--- By Difficulty ---"
        get_difficulty_counts
        echo ""
        echo "--- By Author ---"
        get_author_counts
        ;;
    --next)
        echo "=== Next Recommended Article ==="
        get_next_article
        ;;
    --next5)
        echo "=== Next 5 Recommended Articles ==="
        get_next5_articles
        ;;
    --status)
        get_status_counts
        ;;
    --area)
        get_area_counts
        ;;
    --difficulty)
        get_difficulty_counts
        ;;
    --author)
        get_author_counts
        ;;
    --effort)
        get_effort_counts
        ;;
    --remaining)
        echo "Remaining articles: $(get_remaining_articles)"
        ;;
    --completion)
        get_completion_stats
        ;;
    --stuck)
        echo "=== Articles Stuck in Progress ==="
        get_stuck_articles
        ;;
    --ids)
        get_all_ids
        ;;
    --pending-ids)
        get_pending_ids
        ;;
    --get)
        # Get article by ID: --get <id> [key]
        ARTICLE_ID="${3:-}"
        KEY="${4:-}"
        get_article_by_id "$ARTICLE_ID" "$KEY"
        ;;
    --set-status)
        # Set status: --set-status <status> <id1> [id2...]
        NEW_STATUS="${3:-}"
        shift 3 2>/dev/null || { echo "Error: --set-status requires status and at least one article ID" >&2; exit 1; }
        set_article_status "$NEW_STATUS" "$@"
        ;;
    --set-error)
        # Set error: --set-error <id> <message>
        ARTICLE_ID="${3:-}"
        ERROR_MSG="${4:-}"
        set_article_error "$ARTICLE_ID" "$ERROR_MSG"
        ;;
    --clear-error)
        # Clear error: --clear-error <id>
        ARTICLE_ID="${3:-}"
        clear_article_error "$ARTICLE_ID"
        ;;
    --help|-h)
        echo "Usage: $0 [article_tasks.json path] [mode] [args...]"
        echo ""
        echo "Read-only Modes:"
        echo "  --summary          Full text summary (default)"
        echo "  --json             Full JSON output for programmatic use"
        echo "  --next             Next recommended article"
        echo "  --next5            Next 5 recommended articles"
        echo "  --status           Article counts by status"
        echo "  --area             Article counts by area"
        echo "  --difficulty       Article counts by difficulty"
        echo "  --author           Article counts by author"
        echo "  --effort           Article counts by estimated effort"
        echo "  --remaining        Count of remaining articles"
        echo "  --completion       Completion statistics"
        echo "  --stuck            Show articles stuck in_progress"
        echo ""
        echo "Article Query Modes:"
        echo "  --get <id> [key]   Get article by ID, optionally extract specific key"
        echo "  --ids              List all article IDs"
        echo "  --pending-ids      List pending article IDs"
        echo ""
        echo "Write Modes:"
        echo "  --set-status <status> <id1> [id2...]  Update status for articles"
        echo "  --set-error <id> <message>            Set error_note"
        echo "  --clear-error <id>                    Clear error_note"
        echo ""
        echo "  --help, -h         Show this help"
        ;;
    *)
        echo "Unknown mode: $MODE"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
