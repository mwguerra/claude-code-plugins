#!/bin/bash
# Secretary Plugin - Queue Database Tests
# Verifies schema creation, WAL mode, concurrent access safety
#
# Usage: bash test-queue.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

echo "=== Secretary Plugin - Queue & Schema Tests ==="
echo ""

# Dependency check
MISSING=()
if ! command -v sqlite3 &>/dev/null; then MISSING+=("sqlite3"); fi
if ! command -v jq &>/dev/null; then MISSING+=("jq"); fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "${RED}MISSING DEPENDENCIES: ${MISSING[*]}${NC}"
    echo ""
    echo "Install them:"
    case "$(uname -s)" in
        Linux*)
            echo "  Ubuntu/Debian: sudo apt-get install ${MISSING[*]}"
            echo "  Fedora/RHEL:   sudo dnf install ${MISSING[*]}"
            echo "  Arch:          sudo pacman -S ${MISSING[*]}"
            ;;
        Darwin*)
            echo "  brew install ${MISSING[*]}"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "  choco install ${MISSING[*]}"
            ;;
    esac
    exit 1
fi

# Setup
TEST_DB="/tmp/secretary-test-schema-$$.db"

cleanup() {
    rm -f "$TEST_DB" "${TEST_DB}-wal" "${TEST_DB}-shm"
}
trap cleanup EXIT

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}PASS${NC}  $test_name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC}  $test_name (expected: '$expected', got: '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================================
# Test 1: Schema creation
# ============================================================================

echo "--- Schema Creation ---"

sqlite3 "$TEST_DB" < "$PLUGIN_ROOT/schemas/secretary.sql" 2>/dev/null
assert_eq "Schema created" "0" "$?"

# Check all tables exist
TABLES="queue sessions commitments decisions ideas goals patterns knowledge_nodes knowledge_edges activity_timeline daily_notes github_cache external_changes worker_state state schema_version"
for table in $TABLES; do
    EXISTS=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$table'" 2>/dev/null)
    assert_eq "Table: $table exists" "1" "$EXISTS"
done

# Check FTS tables
FTS_TABLES="commitments_fts decisions_fts ideas_fts knowledge_nodes_fts"
for table in $FTS_TABLES; do
    EXISTS=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$table'" 2>/dev/null)
    assert_eq "FTS table: $table exists" "1" "$EXISTS"
done

# ============================================================================
# Test 2: WAL mode
# ============================================================================

echo ""
echo "--- WAL Mode ---"

MODE=$(sqlite3 "$TEST_DB" "PRAGMA journal_mode;" 2>/dev/null)
assert_eq "WAL mode enabled" "wal" "$MODE"

# ============================================================================
# Test 3: State singleton
# ============================================================================

echo ""
echo "--- State Singleton ---"

STATE_COUNT=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM state" 2>/dev/null)
assert_eq "State has 1 row" "1" "$STATE_COUNT"

WORKER_COUNT=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM worker_state" 2>/dev/null)
assert_eq "Worker state has 1 row" "1" "$WORKER_COUNT"

# ============================================================================
# Test 4: ID generation
# ============================================================================

echo ""
echo "--- ID Generation ---"

# Insert commitment and check ID format
sqlite3 "$TEST_DB" "INSERT INTO commitments (id, title, source_type) VALUES ('C-0001', 'Test commitment', 'conversation')" 2>/dev/null
sqlite3 "$TEST_DB" "INSERT INTO commitments (id, title, source_type) VALUES ('C-0002', 'Another commitment', 'conversation')" 2>/dev/null

MAX_NUM=$(sqlite3 "$TEST_DB" "SELECT MAX(CAST(SUBSTR(id, 3) AS INTEGER)) FROM commitments WHERE id LIKE 'C-%'" 2>/dev/null)
assert_eq "ID numbering works" "2" "$MAX_NUM"

# ============================================================================
# Test 5: FTS triggers
# ============================================================================

echo ""
echo "--- FTS Triggers ---"

# Insert a decision
sqlite3 "$TEST_DB" "INSERT INTO decisions (id, title, description) VALUES ('D-0001', 'Use PostgreSQL', 'We decided to use PostgreSQL for better JSON support')" 2>/dev/null

# Search via FTS
FTS_RESULT=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM decisions_fts WHERE decisions_fts MATCH 'PostgreSQL'" 2>/dev/null)
assert_eq "FTS search finds decision" "1" "$FTS_RESULT"

# Update both title and description, then re-search
sqlite3 "$TEST_DB" "UPDATE decisions SET title = 'Use MySQL', description = 'We decided to use MySQL for simplicity' WHERE id = 'D-0001'" 2>/dev/null
FTS_OLD=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM decisions_fts WHERE decisions_fts MATCH 'PostgreSQL'" 2>/dev/null)
FTS_NEW=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM decisions_fts WHERE decisions_fts MATCH 'MySQL'" 2>/dev/null)
assert_eq "FTS updated after change (old removed)" "0" "$FTS_OLD"
assert_eq "FTS updated after change (new added)" "1" "$FTS_NEW"

# ============================================================================
# Test 6: Queue operations
# ============================================================================

echo ""
echo "--- Queue Operations ---"

# Insert items with different priorities
sqlite3 "$TEST_DB" "
INSERT INTO queue (item_type, data, priority, status) VALUES ('user_prompt', 'low priority', 10, 'pending');
INSERT INTO queue (item_type, data, priority, status) VALUES ('commit', 'high priority', 1, 'pending');
INSERT INTO queue (item_type, data, priority, status) VALUES ('tool_output', 'medium priority', 5, 'pending');
" 2>/dev/null

FIRST_ITEM=$(sqlite3 "$TEST_DB" "SELECT item_type FROM queue WHERE status = 'pending' ORDER BY priority ASC, created_at ASC LIMIT 1" 2>/dev/null)
assert_eq "Priority ordering (highest first)" "commit" "$FIRST_ITEM"

QUEUE_TOTAL=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM queue WHERE status = 'pending'" 2>/dev/null)
assert_eq "Queue total pending" "3" "$QUEUE_TOTAL"

# ============================================================================
# Test 7: Foreign keys
# ============================================================================

echo ""
echo "--- Foreign Keys ---"

sqlite3 "$TEST_DB" "PRAGMA foreign_keys = ON;" 2>/dev/null
sqlite3 "$TEST_DB" "INSERT INTO knowledge_nodes (id, name, node_type) VALUES ('N-0001', 'Test Node', 'concept')" 2>/dev/null
sqlite3 "$TEST_DB" "INSERT INTO knowledge_edges (id, source_node_id, target_node_id, relationship) VALUES ('E-0001', 'N-0001', 'N-0001', 'self')" 2>/dev/null

EDGE_EXISTS=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM knowledge_edges" 2>/dev/null)
assert_eq "Knowledge edge created" "1" "$EDGE_EXISTS"

# ============================================================================
# Results
# ============================================================================

echo ""
echo "=== Results ==="
echo ""
echo -e "  ${GREEN}Passed:${NC} $PASS"
echo -e "  ${RED}Failed:${NC} $FAIL"

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
