#!/bin/bash
# Error Memory Plugin - Multi-Level Error Matching
# Dependencies: platform.sh, hash.sh, normalize.sh (source them before this file)

# Guard against double-sourcing
[[ -n "$_ERROR_MEMORY_MATCH_SH" ]] && return
_ERROR_MEMORY_MATCH_SH=1

CONFIG_DIR="$HOME/.claude/error-memory"
ERRORS_FILE="$CONFIG_DIR/errors.json"
INDEX_FILE="$CONFIG_DIR/index.json"

# Search for matching errors using multi-level matching
# Returns JSON array of matches with confidence scores
# Usage: search_errors "error message" [max_results]
search_errors() {
    local query="$1"
    local max_results="${2:-5}"

    if [[ ! -f "$ERRORS_FILE" ]]; then
        echo "[]"
        return
    fi

    local query_normalized
    local query_hash
    local query_keywords
    local query_type

    query_normalized=$(normalize_error "$query")
    query_hash=$(sha256 "$query_normalized")
    query_keywords=$(extract_keywords "$query")
    query_type=$(extract_error_type "$query")

    # Create temp file for results
    local results_file
    results_file=$(mktemp)
    echo "[]" > "$results_file"

    # Level 1: Exact normalized hash match (100% confidence)
    local exact_match
    exact_match=$(jq -r --arg hash "$query_hash" '
        .errors[] | select(.error.hash == $hash) | .id
    ' "$ERRORS_FILE" 2>/dev/null | head -1)

    if [[ -n "$exact_match" ]]; then
        add_match "$results_file" "$exact_match" 100 "exact_hash"
    fi

    # Level 2: Similar normalized message (80-99% based on similarity)
    # Compare normalized strings using simple word overlap
    jq -r '.errors[] | "\(.id)|\(.error.normalized)"' "$ERRORS_FILE" 2>/dev/null | \
    while IFS='|' read -r id normalized; do
        [[ "$id" == "$exact_match" ]] && continue

        local similarity
        similarity=$(calculate_similarity "$query_normalized" "$normalized")

        if [[ $similarity -ge 70 ]]; then
            add_match "$results_file" "$id" "$similarity" "normalized_similarity"
        fi
    done

    # Level 3: Error type + keyword match (50-70%)
    if [[ -n "$query_type" ]] && [[ "$query_type" != "Unknown" ]]; then
        jq -r --arg type "$query_type" '
            .errors[] | select(.error.type == $type) | "\(.id)|\(.error.keywords | join(" "))"
        ' "$ERRORS_FILE" 2>/dev/null | \
        while IFS='|' read -r id keywords; do
            # Check if already in results
            if jq -e --arg id "$id" '.[] | select(.id == $id)' "$results_file" &>/dev/null; then
                continue
            fi

            local keyword_score
            keyword_score=$(calculate_keyword_overlap "$query_keywords" "$keywords")

            if [[ $keyword_score -ge 30 ]]; then
                local confidence=$((50 + keyword_score / 3))
                [[ $confidence -gt 70 ]] && confidence=70
                add_match "$results_file" "$id" "$confidence" "type_keywords"
            fi
        done
    fi

    # Level 4: Tag match (30-50%)
    local query_tags
    query_tags=$(echo "$query_keywords" | tr ' ' '\n' | head -5 | tr '\n' ' ')

    for tag in $query_tags; do
        jq -r --arg tag "$tag" '
            .errors[] | select(.tags[] | ascii_downcase | contains($tag | ascii_downcase)) | .id
        ' "$ERRORS_FILE" 2>/dev/null | \
        while read -r id; do
            if ! jq -e --arg id "$id" '.[] | select(.id == $id)' "$results_file" &>/dev/null; then
                add_match "$results_file" "$id" 35 "tag_match"
            fi
        done
    done

    # Sort by confidence and limit results
    jq -r --argjson max "$max_results" '
        sort_by(-.confidence) | .[0:$max]
    ' "$results_file"

    rm -f "$results_file"
}

# Add a match to the results file
add_match() {
    local results_file="$1"
    local id="$2"
    local confidence="$3"
    local match_type="$4"

    # Get error details
    local error_data
    error_data=$(jq --arg id "$id" '.errors[] | select(.id == $id)' "$ERRORS_FILE" 2>/dev/null)

    if [[ -n "$error_data" ]]; then
        local new_result
        new_result=$(echo "$error_data" | jq --argjson conf "$confidence" --arg type "$match_type" '
            {
                id: .id,
                confidence: $conf,
                matchType: $type,
                project: .context.project,
                tags: .tags,
                cause: .analysis.cause,
                solution: .analysis.solution,
                usageCount: (.stats.usageCount // 0)
            }
        ')

        # Add to results if not duplicate
        local current
        current=$(cat "$results_file")
        echo "$current" | jq --argjson new "$new_result" '
            if any(.[]; .id == $new.id) then .
            else . + [$new]
            end
        ' > "$results_file.tmp" && mv "$results_file.tmp" "$results_file"
    fi
}

# Calculate similarity between two strings (0-100)
calculate_similarity() {
    local str1="$1"
    local str2="$2"

    # Convert to word arrays
    local words1 words2
    words1=$(echo "$str1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | sort -u)
    words2=$(echo "$str2" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | sort -u)

    # Count common words
    local common total1 total2
    common=$(comm -12 <(echo "$words1") <(echo "$words2") | wc -l)
    total1=$(echo "$words1" | grep -c '.')
    total2=$(echo "$words2" | grep -c '.')

    # Avoid division by zero
    [[ $total1 -eq 0 ]] || [[ $total2 -eq 0 ]] && echo "0" && return

    # Jaccard similarity * 100
    local union=$((total1 + total2 - common))
    [[ $union -eq 0 ]] && echo "0" && return

    echo $((common * 100 / union))
}

# Calculate keyword overlap percentage
calculate_keyword_overlap() {
    local keywords1="$1"
    local keywords2="$2"

    local count1 count2 matches
    count1=$(echo "$keywords1" | wc -w)
    count2=$(echo "$keywords2" | wc -w)
    matches=0

    for word in $keywords1; do
        if echo "$keywords2" | grep -qiw "$word"; then
            ((matches++))
        fi
    done

    [[ $count1 -eq 0 ]] && echo "0" && return

    echo $((matches * 100 / count1))
}

# Get full error details by ID
get_error() {
    local id="$1"

    if [[ ! -f "$ERRORS_FILE" ]]; then
        echo "{}"
        return 1
    fi

    jq --arg id "$id" '.errors[] | select(.id == $id)' "$ERRORS_FILE" 2>/dev/null
}

# Update usage stats for an error
update_usage() {
    local id="$1"
    local success="${2:-true}"

    if [[ ! -f "$ERRORS_FILE" ]]; then
        return 1
    fi

    local now
    now=$(format_date)

    jq --arg id "$id" --arg now "$now" --argjson success "$success" '
        .errors = [.errors[] |
            if .id == $id then
                .stats.usageCount = ((.stats.usageCount // 0) + 1) |
                .stats.lastUsedAt = $now |
                .stats.successRate = (
                    if $success then
                        (((.stats.successRate // 1) * ((.stats.usageCount // 1) - 1) + 1) / (.stats.usageCount // 1))
                    else
                        (((.stats.successRate // 1) * ((.stats.usageCount // 1) - 1)) / (.stats.usageCount // 1))
                    end
                )
            else .
            end
        ]
    ' "$ERRORS_FILE" > "$ERRORS_FILE.tmp" && mv "$ERRORS_FILE.tmp" "$ERRORS_FILE"
}

export -f search_errors add_match calculate_similarity calculate_keyword_overlap get_error update_usage
