#!/bin/bash
# Error Memory Plugin - Error Message Normalization
# Dependencies: platform.sh, hash.sh (source them before this file)

# Guard against double-sourcing
[[ -n "$_ERROR_MEMORY_NORMALIZE_SH" ]] && return
_ERROR_MEMORY_NORMALIZE_SH=1

# Normalize an error message for matching
# - Strips file paths (keeps filename only)
# - Replaces UUIDs with {uuid}
# - Replaces line numbers with {line}
# - Replaces specific IDs with {id}
# - Replaces timestamps with {timestamp}
# - Normalizes whitespace
normalize_error() {
    local msg="$1"

    echo "$msg" | \
        # Replace full file paths with just filename
        sed -E 's|/[a-zA-Z0-9_/.-]+/([a-zA-Z0-9_.-]+\.[a-z]+)|\1|g' | \
        # Replace UUIDs (various formats)
        sed -E 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/{uuid}/gi' | \
        # Replace numeric IDs in contexts like "id = 123" or ":id = 123"
        sed -E 's/(id\s*=\s*)[0-9]+/\1{id}/gi' | \
        # Replace line numbers
        sed -E 's/(line\s*)[0-9]+/\1{line}/gi' | \
        sed -E 's/:[0-9]+:/:​{line}:/g' | \
        # Replace port numbers in database errors
        sed -E 's/(Port:\s*)[0-9]+/\1{port}/gi' | \
        # Replace database names that look like tenant DBs
        sed -E 's/Database:\s*tenant[0-9a-f-]+/Database: {tenant_db}/gi' | \
        # Replace timestamps
        sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}[Z]?/{timestamp}/g' | \
        # Replace memory addresses
        sed -E 's/0x[0-9a-f]+/{address}/gi' | \
        # Normalize multiple spaces to single space
        sed -E 's/[[:space:]]+/ /g' | \
        # Trim leading/trailing whitespace
        sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

# Extract error type from message
# Returns: SQLSTATE, TypeError, Exception, Fatal, etc.
extract_error_type() {
    local msg="$1"

    if echo "$msg" | grep -qE "SQLSTATE\[[A-Z0-9]+\]"; then
        echo "SQLSTATE"
    elif echo "$msg" | grep -qi "TypeError"; then
        echo "TypeError"
    elif echo "$msg" | grep -qi "ReferenceError"; then
        echo "ReferenceError"
    elif echo "$msg" | grep -qi "SyntaxError"; then
        echo "SyntaxError"
    elif echo "$msg" | grep -qi "RuntimeException"; then
        echo "RuntimeException"
    elif echo "$msg" | grep -qi "BadMethodCallException"; then
        echo "BadMethodCallException"
    elif echo "$msg" | grep -qi "InvalidArgumentException"; then
        echo "InvalidArgumentException"
    elif echo "$msg" | grep -qi "Fatal error"; then
        echo "Fatal"
    elif echo "$msg" | grep -qi "Exception"; then
        echo "Exception"
    elif echo "$msg" | grep -qE "HTTP[/ ]*(4[0-9]{2}|5[0-9]{2})"; then
        local code
        code=$(echo "$msg" | grep -oE "HTTP[/ ]*(4[0-9]{2}|5[0-9]{2})" | grep -oE "[0-9]{3}" | head -1)
        echo "HTTP_$code"
    elif echo "$msg" | grep -qi "error"; then
        echo "Error"
    else
        echo "Unknown"
    fi
}

# Extract keywords from error message
# Returns: space-separated keywords
extract_keywords() {
    local msg="$1"

    # Convert to lowercase and extract meaningful words
    echo "$msg" | \
        tr '[:upper:]' '[:lower:]' | \
        # Remove special characters but keep words
        sed -E 's/[^a-z0-9]+/ /g' | \
        # Split into words
        tr ' ' '\n' | \
        # Filter out common words and short words
        grep -vE '^(the|and|for|not|but|was|are|has|had|have|this|that|with|from|will|been|were|being|which|their|would|could|should|about|into|than|only|other|also|just|over|such|make|like|when|what|there|can|all|its|more|some|them|these|your|out|very|after|most|our|may|now|even|new|want|because|any|those|each|how|did|get|made|find|way|many|then|still|too|here|must|say|look|come|think|back|see|time|much|good|give|use|her|him|two|first|last|long|great|little|own|old|right|big|high|different|small|large|next|early|young|important|few|public|bad|same|able|to|of|in|is|it|on|at|as|be|by|or|an|if|no|do|so|up|he|we|my|am|go|me|us)$' | \
        # Filter out words shorter than 3 chars
        grep -E '^.{3,}$' | \
        # Remove duplicates
        sort -u | \
        # Limit to top 10 keywords
        head -10 | \
        # Join with spaces
        tr '\n' ' ' | \
        sed 's/ $//'
}

# Create a normalized hash for an error message
# Usage: error_hash "error message"
error_hash() {
    local msg="$1"
    local normalized
    normalized=$(normalize_error "$msg")
    sha256 "$normalized"
}

export -f normalize_error extract_error_type extract_keywords error_hash
