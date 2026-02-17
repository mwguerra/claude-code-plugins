#!/bin/bash
# Secretary Plugin - Fast Git Commit Detection
# Detects git commit commands and captures metadata quickly

# Source utils if not already loaded
if [[ -z "${SECRETARY_DB_PATH:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/utils.sh"
fi

# ============================================================================
# Git Commit Detection
# ============================================================================

# Check if a command is a git commit (fast regex)
is_git_commit() {
    local input="$1"
    # Match various git commit patterns:
    # git commit -m "...", git commit -am "...", git commit --amend, etc.
    echo "$input" | grep -qE 'git\s+commit(\s|$)' 2>/dev/null
}

# Get commit metadata from git log -1 (fast, local only)
# Returns JSON string with commit info
get_commit_metadata() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "{}"
        return 1
    fi

    local hash short_hash subject author date body files_changed commit_type

    hash=$(git log -1 --format="%H" 2>/dev/null || echo "")
    if [[ -z "$hash" ]]; then
        echo "{}"
        return 1
    fi

    short_hash=$(git log -1 --format="%h" 2>/dev/null)
    subject=$(git log -1 --format="%s" 2>/dev/null)
    author=$(git log -1 --format="%an" 2>/dev/null)
    date=$(git log -1 --format="%ci" 2>/dev/null)
    body=$(git log -1 --format="%b" 2>/dev/null)

    # Get changed files (limit to 20)
    files_changed=$(git diff-tree --no-commit-id --name-status -r "$hash" 2>/dev/null | head -20)

    # Detect conventional commit type
    commit_type="chore"
    if [[ "$subject" =~ ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: ]]; then
        commit_type="${BASH_REMATCH[1]}"
    fi

    local project branch
    project=$(get_project_name)
    branch=$(get_git_branch)

    # Build JSON with jq for proper escaping
    jq -n \
        --arg hash "$hash" \
        --arg short_hash "$short_hash" \
        --arg subject "$subject" \
        --arg author "$author" \
        --arg date "$date" \
        --arg body "$body" \
        --arg files "$files_changed" \
        --arg commit_type "$commit_type" \
        --arg project "$project" \
        --arg branch "$branch" \
        '{
            hash: $hash,
            short_hash: $short_hash,
            subject: $subject,
            author: $author,
            date: $date,
            body: $body,
            files_changed: $files,
            commit_type: $commit_type,
            project: $project,
            branch: $branch
        }'
}

# Get GitHub URL for a commit (if available)
get_commit_github_url() {
    local commit_hash="$1"
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ -z "$remote_url" ]]; then
        return 1
    fi
    # Convert SSH URL to HTTPS
    if [[ "$remote_url" == git@github.com:* ]]; then
        remote_url="https://github.com/${remote_url#git@github.com:}"
    fi
    remote_url="${remote_url%.git}"
    echo "${remote_url}/commit/${commit_hash}"
}

# ============================================================================
# Export Functions
# ============================================================================

export -f is_git_commit get_commit_metadata get_commit_github_url
