#!/bin/bash
# Secretary Plugin - Encrypted Memory Database Manager
# SQLCipher (AES-256) when available, plain sqlite3 fallback with warning
#
# Cross-platform: Linux, macOS, Windows/Git Bash
#
# Usage:
#   memory-manager.sh add "title" "content" [category] [project] [tags]
#   memory-manager.sh search "query"
#   memory-manager.sh list [category] [project]
#   memory-manager.sh show <id>
#   memory-manager.sh delete <id>
#   memory-manager.sh export [format]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PLUGIN_ROOT/hooks/scripts/lib/utils.sh"

set +e

# ============================================================================
# SQLCipher Detection & Wrapper
# ============================================================================

SQLCIPHER_AVAILABLE=false
SQLITE_CMD="sqlite3"

if command -v sqlcipher &>/dev/null; then
    SQLCIPHER_AVAILABLE=true
    SQLITE_CMD="sqlcipher"
fi

# Get or create encryption key
get_encryption_key() {
    if [[ -f "$SECRETARY_AUTH_FILE" ]]; then
        jq -r '.encryption_key // empty' "$SECRETARY_AUTH_FILE" 2>/dev/null
        return
    fi
    echo ""
}

# Initialize auth.json with a new key
init_encryption_key() {
    if [[ -f "$SECRETARY_AUTH_FILE" ]]; then
        return 0
    fi

    ensure_dir "$SECRETARY_DB_DIR"

    # Generate 32-byte hex key
    local key
    if command -v openssl &>/dev/null; then
        key=$(openssl rand -hex 32)
    elif [[ -f /dev/urandom ]]; then
        key=$(head -c 32 /dev/urandom | xxd -p | tr -d '\n')
    else
        # Fallback: use date + random
        key=$(echo "$(date +%s%N)$$${RANDOM}${RANDOM}" | sha256sum | cut -d' ' -f1)
    fi

    cat > "$SECRETARY_AUTH_FILE" << EOF
{
  "encryption_key": "$key",
  "key_created_at": "$(get_iso_timestamp)",
  "sqlcipher_available": $SQLCIPHER_AVAILABLE
}
EOF

    # Secure permissions (chmod 600)
    chmod 600 "$SECRETARY_AUTH_FILE" 2>/dev/null || true

    debug_log "Created encryption key: $SECRETARY_AUTH_FILE"
}

# Execute SQL on memory database
# Prepends PRAGMA key if sqlcipher is available
memory_exec() {
    local sql="$1"
    local db="$SECRETARY_MEMORY_DB_PATH"

    ensure_dir "$SECRETARY_DB_DIR"

    # Initialize schema if DB doesn't exist
    if [[ ! -f "$db" ]]; then
        local schema_file="$PLUGIN_ROOT/schemas/memory.sql"
        if [[ -f "$schema_file" ]]; then
            if [[ "$SQLCIPHER_AVAILABLE" == "true" ]]; then
                local key
                key=$(get_encryption_key)
                if [[ -n "$key" ]]; then
                    $SQLITE_CMD "$db" "PRAGMA key='$key'; $(cat "$schema_file")" 2>/dev/null
                else
                    $SQLITE_CMD "$db" < "$schema_file" 2>/dev/null
                fi
            else
                sqlite3 "$db" < "$schema_file" 2>/dev/null
            fi
        fi
    fi

    if [[ "$SQLCIPHER_AVAILABLE" == "true" ]]; then
        local key
        key=$(get_encryption_key)
        if [[ -n "$key" ]]; then
            $SQLITE_CMD "$db" "PRAGMA key='$key'; $sql" 2>/dev/null
        else
            $SQLITE_CMD "$db" "$sql" 2>/dev/null
        fi
    else
        sqlite3 "$db" "$sql" 2>/dev/null
    fi
}

# Execute SQL query on memory database (returns results)
memory_query() {
    local sql="$1"
    local db="$SECRETARY_MEMORY_DB_PATH"

    ensure_dir "$SECRETARY_DB_DIR"

    if [[ ! -f "$db" ]]; then
        memory_exec "SELECT 1" >/dev/null 2>&1  # Initialize
    fi

    if [[ "$SQLCIPHER_AVAILABLE" == "true" ]]; then
        local key
        key=$(get_encryption_key)
        if [[ -n "$key" ]]; then
            $SQLITE_CMD -json "$db" "PRAGMA key='$key'; $sql" 2>/dev/null
        else
            $SQLITE_CMD -json "$db" "$sql" 2>/dev/null
        fi
    else
        sqlite3 -json "$db" "$sql" 2>/dev/null
    fi
}

# ============================================================================
# Operations
# ============================================================================

ACTION="${1:-}"

case "$ACTION" in

    add)
        TITLE="${2:-}"
        CONTENT="${3:-}"
        CATEGORY="${4:-general}"
        PROJECT="${5:-}"
        TAGS="${6:-}"

        if [[ -z "$TITLE" || -z "$CONTENT" ]]; then
            echo "Usage: memory-manager.sh add \"title\" \"content\" [category] [project] [tags]"
            echo ""
            echo "Categories: credential, api_key, ip_address, phone, secret, note, general"
            exit 1
        fi

        init_encryption_key

        ESCAPED_TITLE=$(sql_escape "$TITLE")
        ESCAPED_CONTENT=$(sql_escape "$CONTENT")
        ESCAPED_PROJECT=$(sql_escape "$PROJECT")

        # Format tags as JSON array
        TAGS_JSON="[]"
        if [[ -n "$TAGS" ]]; then
            TAGS_JSON=$(echo "$TAGS" | tr ',' '\n' | jq -R . | jq -s '.' 2>/dev/null || echo "[]")
        fi

        memory_exec "INSERT INTO memory (title, content, category, tags, project)
                     VALUES ('$ESCAPED_TITLE', '$ESCAPED_CONTENT', '$CATEGORY', '$(sql_escape "$TAGS_JSON")', '$ESCAPED_PROJECT')"

        # Audit log
        memory_exec "INSERT INTO memory_access_log (memory_id, action, details)
                     VALUES (last_insert_rowid(), 'write', 'Created: $ESCAPED_TITLE')"

        echo "Memory entry added: $TITLE ($CATEGORY)"

        if [[ "$SQLCIPHER_AVAILABLE" == "false" ]]; then
            echo ""
            echo "WARNING: SQLCipher is not installed. Memory is stored WITHOUT encryption."
            echo "Install SQLCipher for AES-256 encryption at rest:"
            case "$SECRETARY_OS_TYPE" in
                linux)
                    echo "  Ubuntu/Debian: sudo apt-get install sqlcipher"
                    echo "  Fedora/RHEL:   sudo dnf install sqlcipher"
                    echo "  Arch:          sudo pacman -S sqlcipher"
                    ;;
                macos)
                    echo "  brew install sqlcipher"
                    ;;
                windows)
                    echo "  Download from: https://github.com/niccokunzmann/sqlcipher-windows"
                    ;;
            esac
        fi
        ;;

    search)
        QUERY="${2:-}"
        if [[ -z "$QUERY" ]]; then
            echo "Usage: memory-manager.sh search \"query\""
            exit 1
        fi

        init_encryption_key

        RESULTS=$(memory_query "SELECT m.id, m.title, m.category, m.project, m.created_at
                                FROM memory m
                                JOIN memory_fts ON memory_fts.rowid = m.rowid
                                WHERE memory_fts MATCH '$(sql_escape "$QUERY")'
                                ORDER BY rank LIMIT 20")

        # Audit log
        memory_exec "INSERT INTO memory_access_log (action, details)
                     VALUES ('search', 'Query: $(sql_escape "$QUERY")')"

        if [[ -z "$RESULTS" || "$RESULTS" == "[]" ]]; then
            echo "No results found for: $QUERY"
        else
            echo "$RESULTS" | jq -r '.[] | "[\(.id)] \(.title) (\(.category)) - \(.project // "global") [\(.created_at)]"' 2>/dev/null
        fi
        ;;

    list)
        FILTER_CATEGORY="${2:-}"
        FILTER_PROJECT="${3:-}"

        init_encryption_key

        WHERE_CLAUSE="1=1"
        [[ -n "$FILTER_CATEGORY" ]] && WHERE_CLAUSE="$WHERE_CLAUSE AND category = '$(sql_escape "$FILTER_CATEGORY")'"
        [[ -n "$FILTER_PROJECT" ]] && WHERE_CLAUSE="$WHERE_CLAUSE AND project = '$(sql_escape "$FILTER_PROJECT")'"

        RESULTS=$(memory_query "SELECT id, title, category, project, created_at
                                FROM memory WHERE $WHERE_CLAUSE
                                ORDER BY updated_at DESC LIMIT 50")

        if [[ -z "$RESULTS" || "$RESULTS" == "[]" ]]; then
            echo "No memory entries found."
        else
            echo "$RESULTS" | jq -r '.[] | "[\(.id)] \(.title) (\(.category)) - \(.project // "global")"' 2>/dev/null
        fi
        ;;

    show)
        ID="${2:-}"
        if [[ -z "$ID" ]]; then
            echo "Usage: memory-manager.sh show <id>"
            exit 1
        fi

        init_encryption_key

        RESULT=$(memory_query "SELECT * FROM memory WHERE id = $ID")

        memory_exec "INSERT INTO memory_access_log (memory_id, action, details)
                     VALUES ($ID, 'read', 'Viewed entry $ID')"

        if [[ -z "$RESULT" || "$RESULT" == "[]" ]]; then
            echo "Memory entry #$ID not found."
        else
            echo "$RESULT" | jq '.[0]' 2>/dev/null
        fi
        ;;

    delete)
        ID="${2:-}"
        if [[ -z "$ID" ]]; then
            echo "Usage: memory-manager.sh delete <id>"
            exit 1
        fi

        init_encryption_key

        TITLE=$(memory_query "SELECT title FROM memory WHERE id = $ID" | jq -r '.[0].title // "unknown"' 2>/dev/null)

        memory_exec "DELETE FROM memory WHERE id = $ID"
        memory_exec "INSERT INTO memory_access_log (memory_id, action, details)
                     VALUES ($ID, 'delete', 'Deleted: $TITLE')"

        echo "Memory entry #$ID deleted."
        ;;

    status)
        init_encryption_key

        echo "Secretary Memory Status"
        echo "======================="
        echo ""
        echo "Encryption: $(if [[ "$SQLCIPHER_AVAILABLE" == "true" ]]; then echo "ACTIVE (SQLCipher AES-256)"; else echo "DISABLED (plain sqlite3)"; fi)"
        echo "Database: $SECRETARY_MEMORY_DB_PATH"
        echo "Auth: $SECRETARY_AUTH_FILE"
        echo ""

        if [[ -f "$SECRETARY_MEMORY_DB_PATH" ]]; then
            TOTAL=$(memory_query "SELECT COUNT(*) as count FROM memory" | jq -r '.[0].count // "0"' 2>/dev/null)
            echo "Total entries: $TOTAL"

            # Count by category
            memory_query "SELECT category, COUNT(*) as count FROM memory GROUP BY category ORDER BY count DESC" 2>/dev/null | \
                jq -r '.[] | "  \(.category): \(.count)"' 2>/dev/null
        else
            echo "Database not yet created. Add a memory entry to initialize."
        fi

        if [[ "$SQLCIPHER_AVAILABLE" == "false" ]]; then
            echo ""
            echo "To enable encryption, install SQLCipher:"
            case "$SECRETARY_OS_TYPE" in
                linux)
                    echo "  Ubuntu/Debian: sudo apt-get install sqlcipher"
                    echo "  Fedora/RHEL:   sudo dnf install sqlcipher"
                    echo "  Arch:          sudo pacman -S sqlcipher"
                    ;;
                macos)
                    echo "  brew install sqlcipher"
                    ;;
                windows)
                    echo "  Download from: https://github.com/niccokunzmann/sqlcipher-windows"
                    ;;
            esac
        fi
        ;;

    *)
        echo "Secretary Memory Manager"
        echo ""
        echo "Usage: memory-manager.sh <action> [args...]"
        echo ""
        echo "Actions:"
        echo "  add \"title\" \"content\" [category] [project] [tags]"
        echo "  search \"query\""
        echo "  list [category] [project]"
        echo "  show <id>"
        echo "  delete <id>"
        echo "  status"
        echo ""
        echo "Categories: credential, api_key, ip_address, phone, secret, note, general"
        exit 1
        ;;
esac
