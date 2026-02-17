#!/bin/bash
# Secretary Plugin - Vault Git Sync
# Commits and pushes Obsidian vault changes to GitHub
# Called by worker.sh only (never inline from hooks)
#
# Cross-platform: Linux, macOS, Windows/Git Bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PLUGIN_ROOT/hooks/scripts/lib/utils.sh"

set +e

EVENT_TYPE="${1:-worker}"

if ! is_enabled "vault"; then
    exit 0
fi

VAULT_PATH=$(check_vault)
if [[ -z "$VAULT_PATH" || ! -d "$VAULT_PATH" ]]; then
    exit 0
fi

if ! command -v git &>/dev/null; then
    debug_log "Git not installed - skipping vault git sync"
    exit 0
fi

VAULT_REPO_NAME="obsidian-vault-backup"
VAULT_BRANCH="main"

debug_log "vault-git-sync.sh triggered ($EVENT_TYPE)"

# ============================================================================
# Initialize git repo if needed
# ============================================================================

if [[ ! -d "$VAULT_PATH/.git" ]]; then
    cd "$VAULT_PATH" || exit 0
    git init -b "$VAULT_BRANCH" 2>/dev/null || git init 2>/dev/null
    git branch -M "$VAULT_BRANCH" 2>/dev/null || true

    if [[ ! -f ".gitignore" ]]; then
        cat > ".gitignore" << 'GITIGNORE'
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/plugins/*/data.json
.trash/
.DS_Store
Thumbs.db
*.tmp
*.bak
*~
GITIGNORE
    fi
    debug_log "Initialized git repo in vault"
fi

# ============================================================================
# Configure remote (if gh is available)
# ============================================================================

GH_AVAILABLE=false

if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    GH_AVAILABLE=true
    USERNAME=$(gh api user --jq '.login' 2>/dev/null || echo "")

    if [[ -n "$USERNAME" ]]; then
        cd "$VAULT_PATH" || exit 0

        if ! gh repo view "$USERNAME/$VAULT_REPO_NAME" &>/dev/null 2>&1; then
            gh repo create "$VAULT_REPO_NAME" --private --description "Obsidian vault backup - auto-synced by secretary plugin" --source=. --remote=origin --push 2>/dev/null || {
                GH_AVAILABLE=false
                debug_log "Could not create remote repo"
            }
        else
            REMOTE_URL="https://github.com/$USERNAME/$VAULT_REPO_NAME.git"
            if git -C "$VAULT_PATH" remote get-url origin &>/dev/null; then
                git -C "$VAULT_PATH" remote set-url origin "$REMOTE_URL" 2>/dev/null
            else
                git -C "$VAULT_PATH" remote add origin "$REMOTE_URL" 2>/dev/null
            fi
        fi
    else
        GH_AVAILABLE=false
    fi
fi

# ============================================================================
# Pull latest (if remote available)
# ============================================================================

if [[ "$GH_AVAILABLE" == "true" ]]; then
    cd "$VAULT_PATH" || exit 0
    git pull --rebase origin "$VAULT_BRANCH" 2>/dev/null || {
        git rebase --abort 2>/dev/null || true
        git pull origin "$VAULT_BRANCH" 2>/dev/null || true
    }
fi

# ============================================================================
# Commit changes
# ============================================================================

cd "$VAULT_PATH" || exit 0

if git status --porcelain 2>/dev/null | grep -q .; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    PROJECT=$(get_project_name 2>/dev/null || echo "unknown")
    COMMIT_MSG="Secretary sync: $PROJECT at $TIMESTAMP"

    git add -A 2>/dev/null
    if git commit -m "$COMMIT_MSG" 2>/dev/null; then
        debug_log "Committed vault changes: $COMMIT_MSG"

        if [[ "$GH_AVAILABLE" == "true" ]]; then
            git push -u origin "$VAULT_BRANCH" 2>/dev/null || {
                debug_log "Failed to push vault (network issue?)"
            }
        fi
    fi
else
    debug_log "No vault changes to commit"
fi

debug_log "vault-git-sync.sh completed"
exit 0
