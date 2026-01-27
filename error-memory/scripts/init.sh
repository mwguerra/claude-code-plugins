#!/bin/bash
# Error Memory Plugin - Initialize configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/platform.sh"

CONFIG_DIR="$HOME/.claude/error-memory"
ERRORS_FILE="$CONFIG_DIR/errors.json"
INDEX_FILE="$CONFIG_DIR/index.json"
STATS_FILE="$CONFIG_DIR/stats.json"

# Check dependencies
check_jq

echo "Error Memory Initialization"
echo "============================"
echo ""

# Create config directory
if [[ ! -d "$CONFIG_DIR" ]]; then
    mkdir -p "$CONFIG_DIR"
    echo "Created: $CONFIG_DIR"
else
    echo "Exists:  $CONFIG_DIR"
fi

# Create errors database
if [[ ! -f "$ERRORS_FILE" ]]; then
    cat > "$ERRORS_FILE" << 'EOF'
{
  "version": "1.0.0",
  "errors": []
}
EOF
    echo "Created: errors.json"
else
    echo "Exists:  errors.json"
    error_count=$(jq '.errors | length' "$ERRORS_FILE" 2>/dev/null || echo "0")
    echo "         ($error_count errors stored)"
fi

# Create index
if [[ ! -f "$INDEX_FILE" ]]; then
    cat > "$INDEX_FILE" << 'EOF'
{
  "version": "1.0.0",
  "byHash": {},
  "byNormalized": {},
  "byTag": {}
}
EOF
    echo "Created: index.json"
else
    echo "Exists:  index.json"
fi

# Create stats
if [[ ! -f "$STATS_FILE" ]]; then
    cat > "$STATS_FILE" << 'EOF'
{
  "version": "1.0.0",
  "totalErrors": 0,
  "totalSearches": 0,
  "totalMatches": 0,
  "lastUpdated": null
}
EOF
    echo "Created: stats.json"
else
    echo "Exists:  stats.json"
fi

echo ""
echo "Initialization complete!"
echo ""
echo "Next steps:"
echo "  - Import existing errors: /error:migrate"
echo "  - Search for errors: /error:search <query>"
echo "  - Log a new error: /error:log"
