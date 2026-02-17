#!/bin/bash
# Secretary Plugin - Worker & Queue Processing Tests
# Verifies queue processing, dedup, and retry logic
#
# Usage: bash test-worker.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

# ============================================================================
# Dependency Check
# ============================================================================

echo "=== Secretary Plugin - Worker & Queue Tests ==="
echo ""

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

# ============================================================================
# Setup
# ============================================================================

export SECRETARY_DB_DIR="/tmp/secretary-test-worker-$$"
export SECRETARY_DB_PATH="$SECRETARY_DB_DIR/secretary.db"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export SECRETARY_DEBUG="true"
export SECRETARY_DEBUG_LOG="$SECRETARY_DB_DIR/debug.log"

mkdir -p "$SECRETARY_DB_DIR"

sqlite3 "$SECRETARY_DB_PATH" < "$PLUGIN_ROOT/schemas/secretary.sql" 2>/dev/null
sqlite3 "$SECRETARY_DB_PATH" "PRAGMA journal_mode=WAL;" 2>/dev/null

cleanup() {
    rm -rf "$SECRETARY_DB_DIR"
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

assert_gt() {
    local test_name="$1"
    local threshold="$2"
    local actual="$3"

    if [[ "$actual" -gt "$threshold" ]]; then
        echo -e "  ${GREEN}PASS${NC}  $test_name (value: $actual > $threshold)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC}  $test_name (expected > $threshold, got: $actual)"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================================
# Test 1: Queue insertion
# ============================================================================

echo "--- Queue Operations ---"

# Insert test items
sqlite3 "$SECRETARY_DB_PATH" "
INSERT INTO queue (item_type, data, priority, session_id, project, status)
VALUES ('user_prompt', 'I decided to use PostgreSQL instead of MySQL for this project', 5, 'test-session', 'test-project', 'pending');

INSERT INTO queue (item_type, data, priority, session_id, project, status)
VALUES ('tool_output', 'Created new authentication middleware with JWT tokens', 7, 'test-session', 'test-project', 'pending');

INSERT INTO queue (item_type, data, priority, session_id, project, status)
VALUES ('commit', '{\"hash\":\"abc1234\",\"short_hash\":\"abc1234\",\"subject\":\"feat: add auth\",\"author\":\"test\",\"date\":\"2026-02-17\",\"body\":\"\",\"files_changed\":\"src/auth.ts\",\"commit_type\":\"feat\",\"project\":\"test-project\",\"branch\":\"main\"}', 3, 'test-session', 'test-project', 'pending');
" 2>/dev/null

QUEUE_COUNT=$(sqlite3 "$SECRETARY_DB_PATH" "SELECT COUNT(*) FROM queue WHERE status = 'pending'" 2>/dev/null)
assert_eq "Queue items inserted" "3" "$QUEUE_COUNT"

# ============================================================================
# Test 2: Queue processing
# ============================================================================

echo ""
echo "--- Queue Processing ---"

# Create a test session
sqlite3 "$SECRETARY_DB_PATH" "
INSERT INTO sessions (id, project, branch, started_at, status)
VALUES ('test-session', 'test-project', 'main', datetime('now', '-1 hour'), 'active');
INSERT INTO daily_notes (id, date) VALUES ('$(date +%Y-%m-%d)', '$(date +%Y-%m-%d)');
" 2>/dev/null

# Process the queue (with AI disabled for testing)
export SECRETARY_AI_MODEL="none"
bash "$PLUGIN_ROOT/scripts/process-queue.sh" --limit 10 2>/dev/null || true

# Check that items were processed
PROCESSED_COUNT=$(sqlite3 "$SECRETARY_DB_PATH" "SELECT COUNT(*) FROM queue WHERE status IN ('processed', 'processing')" 2>/dev/null)
assert_gt "Queue items processed" 0 "$PROCESSED_COUNT"

# Check commit was logged to activity timeline
COMMIT_ACTIVITIES=$(sqlite3 "$SECRETARY_DB_PATH" "SELECT COUNT(*) FROM activity_timeline WHERE activity_type = 'commit'" 2>/dev/null)
assert_gt "Commit activity logged" 0 "$COMMIT_ACTIVITIES"

# ============================================================================
# Test 3: Session end dedup
# ============================================================================

echo ""
echo "--- Stop/SessionEnd Dedup ---"

sqlite3 "$SECRETARY_DB_PATH" "
INSERT INTO queue (item_type, data, priority, session_id, project, status)
VALUES ('stop', '{\"session_id\":\"dedup-session\",\"project\":\"test\"}', 2, 'dedup-session', 'test', 'pending');

INSERT INTO queue (item_type, data, priority, session_id, project, status)
VALUES ('session_end', '{\"session_id\":\"dedup-session\",\"project\":\"test\"}', 2, 'dedup-session', 'test', 'pending');

INSERT INTO sessions (id, project, started_at, status)
VALUES ('dedup-session', 'test', datetime('now', '-30 minutes'), 'ending');
" 2>/dev/null

bash "$PLUGIN_ROOT/scripts/process-queue.sh" --limit 10 2>/dev/null || true

# Both should be processed, but session closed only once
SESSION_STATUS=$(sqlite3 "$SECRETARY_DB_PATH" "SELECT status FROM sessions WHERE id = 'dedup-session'" 2>/dev/null)
assert_eq "Session properly closed" "completed" "$SESSION_STATUS"

# ============================================================================
# Test 4: Retry logic
# ============================================================================

echo ""
echo "--- Retry Logic ---"

# Insert item with max attempts
sqlite3 "$SECRETARY_DB_PATH" "
INSERT INTO queue (item_type, data, priority, session_id, project, status, attempts)
VALUES ('user_prompt', 'test retry', 5, 'test', 'test', 'pending', 3);
" 2>/dev/null

bash "$PLUGIN_ROOT/scripts/process-queue.sh" --limit 10 2>/dev/null || true

# Item with 3 attempts should not be picked up again (it was already at max)
RETRY_STATUS=$(sqlite3 "$SECRETARY_DB_PATH" "
    SELECT status FROM queue WHERE data = 'test retry' ORDER BY id DESC LIMIT 1
" 2>/dev/null)
assert_eq "Max retries respected" "pending" "$RETRY_STATUS"

# ============================================================================
# Test 5: Queue expiration
# ============================================================================

echo ""
echo "--- Queue Expiration ---"

sqlite3 "$SECRETARY_DB_PATH" "
INSERT INTO queue (item_type, data, priority, status, ttl_hours, created_at)
VALUES ('user_prompt', 'old item', 5, 'pending', 1, datetime('now', '-2 hours'));
" 2>/dev/null

# Run worker which handles expiration
bash "$PLUGIN_ROOT/scripts/worker.sh" 2>/dev/null || true

EXPIRED_COUNT=$(sqlite3 "$SECRETARY_DB_PATH" "SELECT COUNT(*) FROM queue WHERE status = 'expired'" 2>/dev/null)
assert_gt "Expired items found" 0 "$EXPIRED_COUNT"

# ============================================================================
# Results
# ============================================================================

echo ""
echo "=== Results ==="
echo ""
echo -e "  ${GREEN}Passed:${NC} $PASS"
echo -e "  ${RED}Failed:${NC} $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
