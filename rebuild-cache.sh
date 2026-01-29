#!/bin/bash
# Rebuild mwguerra-marketplace cache for Claude Code
# This script clears the plugin cache and reinstalls from the local repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_NAME="mwguerra-marketplace"
CLAUDE_PLUGINS_DIR="$HOME/.claude/plugins"
MARKETPLACE_DIR="$CLAUDE_PLUGINS_DIR/marketplaces/$MARKETPLACE_NAME"
CACHE_DIR="$CLAUDE_PLUGINS_DIR/cache/$MARKETPLACE_NAME"

echo "=== Rebuilding $MARKETPLACE_NAME cache ==="
echo ""
echo "Source:      $SCRIPT_DIR"
echo "Marketplace: $MARKETPLACE_DIR"
echo "Cache:       $CACHE_DIR"
echo ""

# Confirm action
if [[ "${1:-}" != "-y" && "${1:-}" != "--yes" ]]; then
    read -p "This will clear and rebuild the plugin cache. Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Step 1: Clear the cache directory
echo "[1/4] Clearing cache directory..."
if [[ -d "$CACHE_DIR" ]]; then
    rm -rf "$CACHE_DIR"
    echo "      Removed: $CACHE_DIR"
else
    echo "      Cache directory not found (skipped)"
fi

# Step 2: Clear the marketplace directory
echo "[2/4] Clearing marketplace directory..."
if [[ -d "$MARKETPLACE_DIR" ]]; then
    rm -rf "$MARKETPLACE_DIR"
    echo "      Removed: $MARKETPLACE_DIR"
else
    echo "      Marketplace directory not found (skipped)"
fi

# Step 3: Copy fresh files from local repository
echo "[3/4] Copying fresh files from repository..."
mkdir -p "$MARKETPLACE_DIR"

# Copy all plugin directories and the marketplace.json
for item in "$SCRIPT_DIR"/*; do
    name=$(basename "$item")
    # Skip non-plugin items
    if [[ "$name" == "rebuild-cache.sh" ]] || \
       [[ "$name" == "CLAUDE.md" ]] || \
       [[ "$name" == "README.md" ]] || \
       [[ "$name" == "LICENSE" ]] || \
       [[ "$name" == ".git" ]] || \
       [[ "$name" == ".gitignore" ]] || \
       [[ "$name" == "node_modules" ]]; then
        continue
    fi

    if [[ -d "$item" ]]; then
        cp -r "$item" "$MARKETPLACE_DIR/"
        echo "      Copied: $name/"
    elif [[ -f "$item" ]]; then
        cp "$item" "$MARKETPLACE_DIR/"
        echo "      Copied: $name"
    fi
done

# Step 4: Update known_marketplaces.json timestamp
echo "[4/4] Updating marketplace timestamp..."
KNOWN_MARKETPLACES="$CLAUDE_PLUGINS_DIR/known_marketplaces.json"
if [[ -f "$KNOWN_MARKETPLACES" ]] && command -v jq &>/dev/null; then
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    jq --arg ts "$TIMESTAMP" \
       ".\"$MARKETPLACE_NAME\".lastUpdated = \$ts" \
       "$KNOWN_MARKETPLACES" > "${KNOWN_MARKETPLACES}.tmp" && \
    mv "${KNOWN_MARKETPLACES}.tmp" "$KNOWN_MARKETPLACES"
    echo "      Updated timestamp: $TIMESTAMP"
else
    echo "      Skipped (jq not available or file missing)"
fi

echo ""
echo "=== Cache rebuild complete ==="
echo ""
echo "Note: Restart Claude Code for changes to take effect."
