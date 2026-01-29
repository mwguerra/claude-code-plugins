#!/bin/bash
# My Workflow Plugin - Vault Git Sync
# Automatically syncs Obsidian vault to GitHub
# Called on SessionStart and SessionEnd events
#
# Features:
# - Initializes git repo if not exists
# - Creates private GitHub repo if not exists
# - Stages, commits, and pushes all changes
# - Handles all errors gracefully (never stops the flow)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hook-utils.sh"

# Don't fail on git/gh errors - handle gracefully
set +e

debug_log "vault-git-sync.sh triggered"

# ============================================================================
# Configuration
# ============================================================================

VAULT_REPO_NAME="obsidian-vault-backup"
VAULT_BRANCH="main"

# ============================================================================
# Helper Functions
# ============================================================================

# Check if git is installed
check_git_installed() {
    if ! command -v git &>/dev/null; then
        debug_log "Git is not installed - skipping vault sync"
        return 1
    fi
    return 0
}

# Check if gh CLI is installed and authenticated
check_gh_installed() {
    if ! command -v gh &>/dev/null; then
        debug_log "GitHub CLI (gh) is not installed - will skip remote operations"
        return 1
    fi

    # Check if authenticated
    if ! gh auth status &>/dev/null; then
        debug_log "GitHub CLI not authenticated - will skip remote operations"
        return 1
    fi

    return 0
}

# Get current GitHub username
get_github_username() {
    gh api user --jq '.login' 2>/dev/null || echo ""
}

# Check if remote repo exists
check_remote_repo_exists() {
    local username="$1"
    local repo_name="$2"

    gh repo view "$username/$repo_name" &>/dev/null
    return $?
}

# Create private GitHub repository
create_github_repo() {
    local repo_name="$1"
    local description="$2"

    debug_log "Creating private GitHub repository: $repo_name"

    if gh repo create "$repo_name" --private --description "$description" --source=. --remote=origin --push 2>/dev/null; then
        debug_log "Successfully created GitHub repository: $repo_name"
        return 0
    else
        debug_log "Failed to create GitHub repository: $repo_name"
        return 1
    fi
}

# Initialize git repository in vault
init_git_repo() {
    local vault_path="$1"

    if [[ -d "$vault_path/.git" ]]; then
        debug_log "Git repository already initialized in vault"
        return 0
    fi

    debug_log "Initializing git repository in vault: $vault_path"

    cd "$vault_path" || return 1

    # Initialize repo
    git init -b "$VAULT_BRANCH" 2>/dev/null || git init 2>/dev/null

    # Set initial branch to main if git init didn't use -b
    git branch -M "$VAULT_BRANCH" 2>/dev/null || true

    # Create .gitignore for Obsidian
    if [[ ! -f ".gitignore" ]]; then
        cat > ".gitignore" << 'GITIGNORE'
# Obsidian
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/plugins/*/data.json
.trash/

# OS files
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.bak
*~
GITIGNORE
        debug_log "Created .gitignore for Obsidian vault"
    fi

    debug_log "Git repository initialized successfully"
    return 0
}

# Configure git remote
configure_git_remote() {
    local vault_path="$1"
    local username="$2"
    local repo_name="$3"

    cd "$vault_path" || return 1

    local remote_url="https://github.com/$username/$repo_name.git"

    # Check if remote exists
    if git remote get-url origin &>/dev/null; then
        # Update existing remote
        git remote set-url origin "$remote_url" 2>/dev/null
    else
        # Add new remote
        git remote add origin "$remote_url" 2>/dev/null
    fi

    debug_log "Git remote configured: $remote_url"
    return 0
}

# Stage and commit changes
commit_changes() {
    local vault_path="$1"
    local commit_message="$2"

    cd "$vault_path" || return 1

    # Check if there are any changes
    if git status --porcelain 2>/dev/null | grep -q .; then
        # Stage all changes
        git add -A 2>/dev/null

        # Commit with message
        if git commit -m "$commit_message" 2>/dev/null; then
            debug_log "Committed changes: $commit_message"
            return 0
        else
            debug_log "No changes to commit or commit failed"
            return 1
        fi
    else
        debug_log "No changes to commit"
        return 1
    fi
}

# Push changes to remote
push_changes() {
    local vault_path="$1"

    cd "$vault_path" || return 1

    # Try to push, set upstream if needed
    if git push -u origin "$VAULT_BRANCH" 2>/dev/null; then
        debug_log "Successfully pushed changes to GitHub"
        return 0
    else
        debug_log "Failed to push changes (might be no remote or network issue)"
        return 1
    fi
}

# Pull latest changes (merge strategy)
pull_changes() {
    local vault_path="$1"

    cd "$vault_path" || return 1

    # Try to pull with rebase to keep history clean
    if git pull --rebase origin "$VAULT_BRANCH" 2>/dev/null; then
        debug_log "Successfully pulled latest changes"
        return 0
    else
        # If rebase fails, try merge
        git rebase --abort 2>/dev/null || true
        if git pull origin "$VAULT_BRANCH" 2>/dev/null; then
            debug_log "Pulled changes with merge"
            return 0
        fi
        debug_log "Failed to pull changes (might be first push or network issue)"
        return 1
    fi
}

# ============================================================================
# Main Sync Function
# ============================================================================

sync_vault_to_git() {
    local event_type="${1:-session}"  # session_start or session_end

    # Check if vault is enabled
    if ! is_enabled "vault"; then
        debug_log "Vault integration disabled - skipping git sync"
        return 0
    fi

    # Get vault path
    local vault_path
    vault_path=$(check_vault)

    if [[ -z "$vault_path" || ! -d "$vault_path" ]]; then
        debug_log "Vault path not configured or doesn't exist - skipping git sync"
        return 0
    fi

    # Check git is installed
    if ! check_git_installed; then
        return 0
    fi

    debug_log "Starting vault git sync for event: $event_type"

    # Initialize git repo if needed
    if ! init_git_repo "$vault_path"; then
        debug_log "Failed to initialize git repo - continuing anyway"
    fi

    # Check if gh is available for remote operations
    local gh_available=false
    local username=""

    if check_gh_installed; then
        gh_available=true
        username=$(get_github_username)

        if [[ -n "$username" ]]; then
            debug_log "GitHub authenticated as: $username"

            # Check/create remote repo
            if ! check_remote_repo_exists "$username" "$VAULT_REPO_NAME"; then
                debug_log "Remote repository doesn't exist, creating..."
                cd "$vault_path"
                if ! create_github_repo "$VAULT_REPO_NAME" "Obsidian vault backup - auto-synced by my-workflow plugin"; then
                    debug_log "Could not create remote repo - will continue with local commits"
                    gh_available=false
                fi
            else
                # Configure remote if repo exists
                configure_git_remote "$vault_path" "$username" "$VAULT_REPO_NAME"
            fi
        else
            debug_log "Could not get GitHub username"
            gh_available=false
        fi
    fi

    # Pull latest changes first (if remote is configured)
    if [[ "$gh_available" == "true" ]]; then
        pull_changes "$vault_path" || true
    fi

    # Generate commit message based on event
    local commit_message
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local project=$(get_project_name 2>/dev/null || echo "unknown")

    case "$event_type" in
        "session_start")
            commit_message="Session start: $project at $timestamp"
            ;;
        "session_end")
            commit_message="Session end: $project at $timestamp"
            ;;
        *)
            commit_message="Auto-sync: $timestamp"
            ;;
    esac

    # Commit any changes
    if commit_changes "$vault_path" "$commit_message"; then
        # Push if remote is available
        if [[ "$gh_available" == "true" ]]; then
            push_changes "$vault_path" || true
        fi
    fi

    debug_log "Vault git sync completed for event: $event_type"
    return 0
}

# ============================================================================
# Main Entry Point
# ============================================================================

# Determine event type from environment or argument
EVENT_TYPE="${1:-}"

if [[ -z "$EVENT_TYPE" ]]; then
    # Try to determine from hook context
    if [[ -n "${CLAUDE_SESSION_START:-}" ]]; then
        EVENT_TYPE="session_start"
    elif [[ -n "${CLAUDE_SESSION_END:-}" ]]; then
        EVENT_TYPE="session_end"
    else
        EVENT_TYPE="auto"
    fi
fi

# Run the sync
sync_vault_to_git "$EVENT_TYPE"

# Always exit successfully - never block the workflow
exit 0
