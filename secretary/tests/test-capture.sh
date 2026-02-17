#!/bin/bash
# Secretary Plugin - Hook Performance Tests
# Verifies that capture.sh completes in < 100ms for all events
#
# Usage: bash test-capture.sh
# Cross-platform: Linux, macOS, Windows/Git Bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
CAPTURE_SCRIPT="$PLUGIN_ROOT/hooks/scripts/capture.sh"

# Colors (if terminal supports them)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

# ============================================================================
# Dependency Check
# ============================================================================

echo "=== Secretary Plugin - Capture Performance Tests ==="
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
# Test Helper
# ============================================================================

# Use a temporary DB for testing
export SECRETARY_DB_DIR="/tmp/secretary-test-$$"
export SECRETARY_DB_PATH="$SECRETARY_DB_DIR/secretary.db"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

mkdir -p "$SECRETARY_DB_DIR"

# Initialize test DB
sqlite3 "$SECRETARY_DB_PATH" < "$PLUGIN_ROOT/schemas/secretary.sql" 2>/dev/null
sqlite3 "$SECRETARY_DB_PATH" "PRAGMA journal_mode=WAL;" 2>/dev/null

cleanup() {
    rm -rf "$SECRETARY_DB_DIR"
}
trap cleanup EXIT

run_test() {
    local test_name="$1"
    local event_type="$2"
    local max_ms="$3"
    local env_vars="$4"

    # Time the execution
    local start end elapsed_ms

    if command -v gdate &>/dev/null; then
        # macOS with coreutils
        start=$(gdate +%s%N)
        eval "$env_vars" bash "$CAPTURE_SCRIPT" "$event_type" </dev/null >/dev/null 2>&1 || true
        end=$(gdate +%s%N)
        elapsed_ms=$(( (end - start) / 1000000 ))
    elif date +%s%N | grep -qv 'N'; then
        # Linux (supports nanoseconds)
        start=$(date +%s%N)
        eval "$env_vars" bash "$CAPTURE_SCRIPT" "$event_type" </dev/null >/dev/null 2>&1 || true
        end=$(date +%s%N)
        elapsed_ms=$(( (end - start) / 1000000 ))
    else
        # Fallback: use time command
        local time_output
        time_output=$( { time eval "$env_vars" bash "$CAPTURE_SCRIPT" "$event_type" </dev/null >/dev/null 2>&1; } 2>&1 || true )
        elapsed_ms=$(echo "$time_output" | grep real | awk '{print $2}' | sed 's/[ms]//g' | awk -F. '{print $1*1000+$2}' 2>/dev/null || echo "999")
    fi

    if [[ $elapsed_ms -le $max_ms ]]; then
        echo -e "  ${GREEN}PASS${NC}  $test_name: ${elapsed_ms}ms (limit: ${max_ms}ms)"
        PASS=$((PASS + 1))
    elif [[ $elapsed_ms -le $((max_ms * 2)) ]]; then
        echo -e "  ${YELLOW}WARN${NC}  $test_name: ${elapsed_ms}ms (limit: ${max_ms}ms)"
        WARN=$((WARN + 1))
    else
        echo -e "  ${RED}FAIL${NC}  $test_name: ${elapsed_ms}ms (limit: ${max_ms}ms)"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================================
# Tests
# ============================================================================

echo "Testing capture.sh performance (target: < 100ms per event)"
echo ""

# Test user_prompt (with short prompt - should skip)
run_test "user_prompt (short, skip)" "user_prompt" 100 'CLAUDE_USER_PROMPT="hi"'

# Test user_prompt (with real prompt)
run_test "user_prompt (normal)" "user_prompt" 100 'CLAUDE_USER_PROMPT="Please help me implement a new feature for the authentication system"'

# Test post_tool_bash (non-commit)
run_test "post_tool_bash (non-commit)" "post_tool_bash" 100 'CLAUDE_TOOL_INPUT="ls -la" CLAUDE_TOOL_OUTPUT="total 42\ndrwxr-xr-x 5 user group 4096 Feb 17 test"'

# Test post_tool_bash (short output, skip)
run_test "post_tool_bash (short, skip)" "post_tool_bash" 100 'CLAUDE_TOOL_INPUT="echo hi" CLAUDE_TOOL_OUTPUT="hi"'

# Test post_tool_edit
run_test "post_tool_edit" "post_tool_edit" 100 'CLAUDE_TOOL_OUTPUT="Successfully edited /home/user/project/src/auth.ts: replaced 5 lines with 10 lines"'

# Test post_tool_write
run_test "post_tool_write" "post_tool_write" 100 'CLAUDE_TOOL_OUTPUT="Successfully wrote /home/user/project/src/new-file.ts (42 lines)"'

# Test post_tool_task
run_test "post_tool_task" "post_tool_task" 100 'CLAUDE_TOOL_OUTPUT="Agent completed: found 5 matching files across the codebase with authentication patterns"'

# Test subagent_stop
run_test "subagent_stop" "subagent_stop" 100 'CLAUDE_TOOL_OUTPUT="The analysis agent completed: found 3 potential security issues in the codebase."'

# Test subagent_stop (short, skip)
run_test "subagent_stop (short, skip)" "subagent_stop" 100 'CLAUDE_TOOL_OUTPUT="Done."'

# Test stop
echo '{"transcript_path": "/tmp/test-transcript.jsonl"}' | run_test "stop" "stop" 100 ''

# Test session_end
echo '{"transcript_path": "/tmp/test-transcript.jsonl"}' | run_test "session_end" "session_end" 100 ''

# Test session_end (dedup - after stop)
echo '{"transcript_path": "/tmp/test-transcript.jsonl"}' | run_test "session_end (dedup)" "session_end" 100 ''

# Test unknown event
run_test "unknown event" "unknown_event" 100 ''

echo ""
echo "=== Test Database Check ==="
echo ""

# Verify queue has items
QUEUE_COUNT=$(sqlite3 "$SECRETARY_DB_PATH" "SELECT COUNT(*) FROM queue" 2>/dev/null)
echo "Queue items created: $QUEUE_COUNT"

QUEUE_BY_TYPE=$(sqlite3 "$SECRETARY_DB_PATH" "SELECT item_type, COUNT(*) FROM queue GROUP BY item_type" 2>/dev/null)
echo "By type: $QUEUE_BY_TYPE"

echo ""
echo "=== Results ==="
echo ""
echo -e "  ${GREEN}Passed:${NC}  $PASS"
echo -e "  ${YELLOW}Warnings:${NC} $WARN"
echo -e "  ${RED}Failed:${NC}  $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}Some tests failed! Hooks may cause noticeable latency.${NC}"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "${YELLOW}Some tests are slow but within tolerance.${NC}"
    exit 0
else
    echo -e "${GREEN}All tests passed! Hooks are fast.${NC}"
    exit 0
fi
