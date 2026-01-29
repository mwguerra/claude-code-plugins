#!/bin/bash
# Obsidian Vault Plugin - Utility Functions

CONFIG_FILE="$HOME/.claude/obsidian-vault.json"

# Get vault path from config
get_vault_path() {
    if [[ -f "$CONFIG_FILE" ]]; then
        jq -r '.vaultPath // empty' "$CONFIG_FILE" 2>/dev/null
    fi
}

# Get config value
get_config() {
    local key="$1"
    if [[ -f "$CONFIG_FILE" ]]; then
        jq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null
    fi
}

# Check if vault is configured
check_vault_configured() {
    local vault_path
    vault_path=$(get_vault_path)
    if [[ -z "$vault_path" ]]; then
        echo "ERROR: Vault not configured. Run /obsidian:init first."
        exit 1
    fi
    if [[ ! -d "$vault_path" ]]; then
        echo "ERROR: Vault path does not exist: $vault_path"
        exit 1
    fi
    echo "$vault_path"
}

# Generate slug from text
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-50
}

# Get current date in YYYY-MM-DD format
get_date() {
    date +%Y-%m-%d
}

# Get current datetime
get_datetime() {
    date "+%Y-%m-%d %H:%M"
}

# Create frontmatter for a note
create_frontmatter() {
    local title="$1"
    local description="$2"
    local tags="$3"
    local related="$4"
    local created="${5:-$(get_date)}"
    local updated
    updated=$(get_date)

    echo "---"
    echo "title: \"$title\""
    echo "description: \"$description\""

    # Format tags as YAML array with quoted strings
    if [[ -n "$tags" ]]; then
        local formatted_tags=""
        IFS=',' read -ra TAG_ARRAY <<< "$tags"
        for tag in "${TAG_ARRAY[@]}"; do
            tag=$(echo "$tag" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [[ -n "$tag" ]]; then
                if [[ -n "$formatted_tags" ]]; then
                    formatted_tags="$formatted_tags, \"$tag\""
                else
                    formatted_tags="\"$tag\""
                fi
            fi
        done
        echo "tags: [$formatted_tags]"
    else
        echo "tags: []"
    fi

    # Format related as YAML array with wiki links
    if [[ -n "$related" ]]; then
        local related_formatted
        related_formatted=$(echo "$related" | tr ',' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^/[[/' | sed 's/$/]]/' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
        echo "related: [$related_formatted]"
    else
        echo "related: []"
    fi

    echo "created: $created"
    echo "updated: $updated"
    echo "---"
}

# Update the 'updated' field in existing frontmatter
update_frontmatter_date() {
    local file="$1"
    local today
    today=$(get_date)

    if [[ -f "$file" ]]; then
        sed -i "s/^updated:.*$/updated: $today/" "$file"
    fi
}

# Extract frontmatter value from a file
get_frontmatter_value() {
    local file="$1"
    local key="$2"

    if [[ -f "$file" ]]; then
        sed -n '/^---$/,/^---$/p' "$file" | grep "^$key:" | sed "s/^$key:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
    fi
}

# Add a related link to a file's frontmatter
add_related_link() {
    local file="$1"
    local link="$2"

    if [[ -f "$file" ]]; then
        local current_related
        current_related=$(get_frontmatter_value "$file" "related")

        # Check if link already exists
        if echo "$current_related" | grep -q "\[\[$link\]\]"; then
            return 0
        fi

        # Add the new link
        if [[ "$current_related" == "[]" ]] || [[ -z "$current_related" ]]; then
            sed -i "s/^related:.*$/related: [[$link]]/" "$file"
        else
            # Remove closing bracket, add new link, close bracket
            local new_related
            new_related=$(echo "$current_related" | sed 's/\]$//' | sed "s/$/, [[$link]]/")
            sed -i "s/^related:.*$/related: $new_related]/" "$file"
        fi

        update_frontmatter_date "$file"
    fi
}

# Get project name from git or directory
get_project_name() {
    local dir="${1:-$(pwd)}"

    # Try to get from git remote
    if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
        local remote
        remote=$(git -C "$dir" remote get-url origin 2>/dev/null)
        if [[ -n "$remote" ]]; then
            basename "$remote" .git
            return
        fi
    fi

    # Fall back to directory name
    basename "$dir"
}

# Get current git branch
get_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Get last commit info
get_last_commit() {
    git log -1 --format="%H|%h|%s|%an|%ae" 2>/dev/null
}

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}

# Find note by title (fuzzy)
find_note() {
    local vault_path="$1"
    local query="$2"

    find "$vault_path" -name "*.md" -type f | while read -r file; do
        local title
        title=$(get_frontmatter_value "$file" "title")
        if echo "$title" | grep -qi "$query"; then
            echo "$file"
        fi
    done
}

# Search notes by content
search_notes() {
    local vault_path="$1"
    local query="$2"

    grep -ril "$query" "$vault_path" --include="*.md" 2>/dev/null
}

# Search notes by tag
search_by_tag() {
    local vault_path="$1"
    local tag="$2"

    grep -rl "tags:.*$tag" "$vault_path" --include="*.md" 2>/dev/null
}

# List all unique tags in vault
list_all_tags() {
    local vault_path="$1"

    find "$vault_path" -name "*.md" -type f -exec grep -h "^tags:" {} \; 2>/dev/null | \
        sed 's/tags:[[:space:]]*\[//' | sed 's/\]//' | tr ',' '\n' | \
        sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | \
        sort | uniq -c | sort -rn
}

# Validate frontmatter exists
has_frontmatter() {
    local file="$1"
    head -1 "$file" 2>/dev/null | grep -q "^---$"
}

# Export functions
export -f get_vault_path get_config check_vault_configured slugify get_date get_datetime
export -f create_frontmatter update_frontmatter_date get_frontmatter_value add_related_link
export -f get_project_name get_git_branch get_last_commit ensure_dir
export -f find_note search_notes search_by_tag list_all_tags has_frontmatter
