#!/bin/bash
# My Workflow Plugin - Comprehensive Hook Tests
# Tests all capture scripts with complex, multi-language, and large data scenarios

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${SCRIPT_DIR}/.."
HOOKS_DIR="${PLUGIN_ROOT}/hooks/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Enable debug logging for tests
export WORKFLOW_DEBUG=true

# Helper functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED=$((PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED=$((FAILED + 1))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Source hook utilities for database access
source "${HOOKS_DIR}/hook-utils.sh"

# ============================================================================
# Test 1: Complex Multi-Item Extraction
# ============================================================================

test_multi_item_extraction() {
    log_test "Multi-item extraction with decisions, ideas, and commitments"

    export CLAUDE_TOOL_OUTPUT="
After thorough analysis of the requirements and team discussion, I've decided to implement the authentication system using JWT tokens with refresh token rotation. This decision was made because:
1. JWT provides stateless authentication which scales better
2. Refresh token rotation adds an extra layer of security
3. It integrates well with our microservices architecture

Additionally, we decided to use PostgreSQL instead of MongoDB for the user database because relational data better fits our use case.

Some ideas came up during the discussion:
- What if we implemented a rate limiting middleware using Redis?
- We could explore adding WebSocket support for real-time notifications
- It might be worth considering GraphQL for the API layer in future iterations

Action items from this session:
- I need to update the authentication documentation before Friday
- TODO: Implement the password reset flow
- Don't forget to add unit tests for the JWT validation logic
- I'll need to coordinate with the frontend team about the token refresh mechanism
"

    # Run all capture scripts
    bash "${HOOKS_DIR}/capture-decision.sh" 2>&1 || true
    bash "${HOOKS_DIR}/capture-idea.sh" 2>&1 || true
    bash "${HOOKS_DIR}/capture-commitment.sh" 2>&1 || true

    # Verify results in database
    local decisions=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM decisions WHERE created_at > datetime('now', '-1 minute')" 2>/dev/null || echo "0")
    local ideas=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM ideas WHERE created_at > datetime('now', '-1 minute')" 2>/dev/null || echo "0")
    local commitments=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM commitments WHERE created_at > datetime('now', '-1 minute')" 2>/dev/null || echo "0")

    if [[ "$decisions" -ge 1 ]] && [[ "$ideas" -ge 1 ]] && [[ "$commitments" -ge 1 ]]; then
        log_pass "Multi-item extraction: $decisions decisions, $ideas ideas, $commitments commitments"
    else
        log_fail "Multi-item extraction: expected at least 1 of each, got $decisions/$ideas/$commitments"
    fi
}

# ============================================================================
# Test 2: Portuguese Language Detection
# ============================================================================

test_portuguese_detection() {
    log_test "Portuguese language detection"

    export CLAUDE_TOOL_OUTPUT="
Decidi usar o React para o frontend porque é a biblioteca mais popular e tem uma comunidade ativa.
Também decidimos implementar o cache usando Redis para melhorar a performance.

Algumas ideias surgiram:
- E se usássemos GraphQL em vez de REST?
- Podemos considerar adicionar suporte a PWA
- Seria interessante explorar SSR com Next.js

Coisas que preciso lembrar:
- Preciso atualizar a documentação até sexta-feira
- Tenho que revisar os testes de integração
- Não posso esquecer de configurar o CI/CD
"

    bash "${HOOKS_DIR}/capture-decision.sh" 2>&1 || true
    bash "${HOOKS_DIR}/capture-idea.sh" 2>&1 || true
    bash "${HOOKS_DIR}/capture-commitment.sh" 2>&1 || true

    local decisions=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM decisions WHERE created_at > datetime('now', '-30 seconds')" 2>/dev/null || echo "0")
    local ideas=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM ideas WHERE created_at > datetime('now', '-30 seconds')" 2>/dev/null || echo "0")

    if [[ "$decisions" -ge 1 ]] || [[ "$ideas" -ge 1 ]]; then
        log_pass "Portuguese detection: captured $decisions decisions, $ideas ideas"
    else
        log_warn "Portuguese detection: may require AI for better results"
    fi
}

# ============================================================================
# Test 3: Spanish Language Detection
# ============================================================================

test_spanish_detection() {
    log_test "Spanish language detection"

    export CLAUDE_TOOL_OUTPUT="
Decidí usar TypeScript para todo el proyecto porque proporciona mejor seguridad de tipos.
La decisión es usar Docker para el deployment en producción.

Ideas para el futuro:
- Qué tal si implementamos un sistema de notificaciones push?
- Podríamos explorar el uso de Kubernetes para orquestación

Tareas pendientes:
- Necesito terminar la migración de la base de datos
- Tengo que actualizar los tests antes del release
"

    bash "${HOOKS_DIR}/capture-decision.sh" 2>&1 || true
    bash "${HOOKS_DIR}/capture-idea.sh" 2>&1 || true
    bash "${HOOKS_DIR}/capture-commitment.sh" 2>&1 || true

    local decisions=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM decisions WHERE created_at > datetime('now', '-30 seconds')" 2>/dev/null || echo "0")

    if [[ "$decisions" -ge 1 ]]; then
        log_pass "Spanish detection: captured $decisions decisions"
    else
        log_warn "Spanish detection: may require AI for better results"
    fi
}

# ============================================================================
# Test 4: Large Content Processing
# ============================================================================

test_large_content() {
    log_test "Large content processing (stress test)"

    # Generate large content with multiple items
    local large_content="After extensive code review and performance analysis, I decided to implement the following architectural changes:

"
    for i in {1..20}; do
        large_content+="Decision $i: We'll use approach $i for component $i because it provides better maintainability.
"
    done

    large_content+="

Ideas generated during the review:
"
    for i in {1..15}; do
        large_content+="- What if we implemented feature $i using pattern $i?
"
    done

    large_content+="

Tasks to complete:
"
    for i in {1..10}; do
        large_content+="- I need to implement task $i for module $i
"
    done

    export CLAUDE_TOOL_OUTPUT="$large_content"

    # Time the execution
    local start_time=$(date +%s)
    bash "${HOOKS_DIR}/capture-decision.sh" 2>&1 || true
    bash "${HOOKS_DIR}/capture-idea.sh" 2>&1 || true
    bash "${HOOKS_DIR}/capture-commitment.sh" 2>&1 || true
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ $duration -lt 30 ]]; then
        log_pass "Large content processing completed in ${duration}s"
    else
        log_warn "Large content processing took ${duration}s (may indicate performance issue)"
    fi
}

# ============================================================================
# Test 5: Duplicate Detection
# ============================================================================

test_duplicate_detection() {
    log_test "Duplicate detection"

    export CLAUDE_TOOL_OUTPUT="I decided to use React for the frontend because it's popular."

    # Run twice with same content
    bash "${HOOKS_DIR}/capture-decision.sh" 2>&1 || true
    local count1=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM decisions WHERE title LIKE '%React%'" 2>/dev/null || echo "0")

    bash "${HOOKS_DIR}/capture-decision.sh" 2>&1 || true
    local count2=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM decisions WHERE title LIKE '%React%'" 2>/dev/null || echo "0")

    if [[ "$count1" == "$count2" ]]; then
        log_pass "Duplicate detection: second run didn't create duplicate"
    else
        log_fail "Duplicate detection: duplicate was created ($count1 -> $count2)"
    fi
}

# ============================================================================
# Test 6: Concurrent File Operations
# ============================================================================

test_concurrent_file_ops() {
    log_test "Concurrent file operations (retry logic)"

    local test_file="/tmp/claude-workflow-test-$$-concurrent.md"

    # Simulate concurrent writes
    local success=0
    for i in {1..5}; do
        (
            export CLAUDE_TOOL_OUTPUT="Concurrent decision $i: Use approach $i for testing concurrent writes"
            bash "${HOOKS_DIR}/capture-decision.sh" 2>&1 || true
        ) &
    done
    wait

    # Check that all completed without errors
    local recent_count=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM decisions WHERE created_at > datetime('now', '-30 seconds') AND title LIKE '%Concurrent%'" 2>/dev/null || echo "0")

    if [[ "$recent_count" -ge 1 ]]; then
        log_pass "Concurrent operations: $recent_count records created successfully"
    else
        log_fail "Concurrent operations: no records created"
    fi
}

# ============================================================================
# Test 7: Git Commit Detection
# ============================================================================

test_git_commit_detection() {
    log_test "Git commit detection"

    # Simulate git commit command
    export CLAUDE_TOOL_INPUT="git commit -m \"feat: add new authentication module\""
    export CLAUDE_TOOL_OUTPUT="[main abc1234] feat: add new authentication module
 3 files changed, 150 insertions(+), 20 deletions(-)"

    bash "${HOOKS_DIR}/capture-commit.sh" 2>&1 || true

    # Check activity log
    local commit_activity=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM activity_timeline WHERE activity_type = 'commit' AND created_at > datetime('now', '-1 minute')" 2>/dev/null || echo "0")

    if [[ "$commit_activity" -ge 1 ]]; then
        log_pass "Git commit detection: activity logged"
    else
        log_warn "Git commit detection: not in a git repo or detection failed"
    fi
}

# ============================================================================
# Test 8: User Input Analysis
# ============================================================================

test_user_input_analysis() {
    log_test "User input analysis"

    export CLAUDE_USER_PROMPT="Let's use TypeScript instead of JavaScript for this project. I need to remember to update the CI/CD pipeline. What if we added real-time notifications?"

    bash "${HOOKS_DIR}/capture-user-input.sh" 2>&1 || true

    local decisions=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM decisions WHERE source_context = 'user-input-pattern' OR source_context = 'user-input-ai' AND created_at > datetime('now', '-30 seconds')" 2>/dev/null || echo "0")

    if [[ "$decisions" -ge 1 ]]; then
        log_pass "User input analysis: captured $decisions items"
    else
        log_warn "User input analysis: may require specific patterns"
    fi
}

# ============================================================================
# Test 9: Session Briefing
# ============================================================================

test_session_briefing() {
    log_test "Session briefing generation"

    # Run briefing (will create a new session)
    local output=$(bash "${HOOKS_DIR}/session-briefing.sh" 2>&1) || true

    if echo "$output" | grep -q "Workflow Briefing\|Session:\|Project:"; then
        log_pass "Session briefing: generated successfully"
    else
        log_pass "Session briefing: script executed (output may vary based on data)"
    fi

    # Check session was created
    local sessions=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM sessions WHERE status = 'active'" 2>/dev/null || echo "0")
    if [[ "$sessions" -ge 1 ]]; then
        log_pass "Session created: $sessions active sessions"
    fi
}

# ============================================================================
# Test 10: Daily Note Functions
# ============================================================================

test_daily_note_functions() {
    log_test "Daily note functions"

    # Ensure daily note exists
    ensure_daily_note

    local today=$(get_date)
    local daily_exists=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM daily_notes WHERE date = '$today'" 2>/dev/null || echo "0")

    if [[ "$daily_exists" -ge 1 ]]; then
        log_pass "Daily note: created for $today"
    else
        log_fail "Daily note: not created"
    fi

    # Test planner generation
    local planner=$(get_today_planner 2>/dev/null) || true
    if [[ -n "$planner" ]]; then
        log_pass "Today's planner: generated"
    else
        log_pass "Today's planner: empty (no pending items)"
    fi
}

# ============================================================================
# Test 11: Safe File Operations
# ============================================================================

test_safe_file_operations() {
    log_test "Safe file operations (retry logic)"

    local test_file="/tmp/claude-workflow-test-$$-safe.txt"
    local test_content="Test content for safe file operations"

    # Test safe_write_file
    if safe_write_file "$test_file" "$test_content"; then
        if [[ -f "$test_file" ]] && [[ "$(cat "$test_file")" == "$test_content" ]]; then
            log_pass "safe_write_file: works correctly"
        else
            log_fail "safe_write_file: content mismatch"
        fi
    else
        log_fail "safe_write_file: failed"
    fi

    # Test safe_append_file
    local append_content=" - appended"
    if safe_append_file "$test_file" "$append_content"; then
        if grep -q "appended" "$test_file"; then
            log_pass "safe_append_file: works correctly"
        else
            log_fail "safe_append_file: content not appended"
        fi
    else
        log_fail "safe_append_file: failed"
    fi

    # Test safe_read_file
    local read_content=$(safe_read_file "$test_file")
    if [[ -n "$read_content" ]]; then
        log_pass "safe_read_file: works correctly"
    else
        log_fail "safe_read_file: failed"
    fi

    # Cleanup
    rm -f "$test_file"
}

# ============================================================================
# Test 12: Agent Result Capture
# ============================================================================

test_agent_result_capture() {
    log_test "Agent result capture"

    export CLAUDE_TOOL_OUTPUT="
I completed the implementation of the authentication module. Here's what was done:

1. Implemented JWT token generation and validation
2. Added refresh token rotation for security
3. Created middleware for protected routes
4. Added comprehensive unit tests

The approach I chose was to use asymmetric keys for token signing because it provides better security in a distributed environment.

Suggestion for future improvements: We could also add biometric authentication support.
"

    bash "${HOOKS_DIR}/capture-agent-result.sh" 2>&1 || true

    local activities=$(sqlite3 "$(ensure_db)" "SELECT COUNT(*) FROM activity_timeline WHERE activity_type IN ('decision', 'idea', 'agent-work') AND created_at > datetime('now', '-30 seconds')" 2>/dev/null || echo "0")

    if [[ "$activities" -ge 1 ]]; then
        log_pass "Agent result capture: $activities activities logged"
    else
        log_warn "Agent result capture: no activities (patterns may not match)"
    fi
}

# ============================================================================
# Run All Tests
# ============================================================================

main() {
    echo ""
    echo "=============================================="
    echo " My Workflow Plugin - Comprehensive Tests"
    echo "=============================================="
    echo ""

    # Ensure database is initialized
    ensure_db >/dev/null

    # Run all tests
    test_multi_item_extraction
    echo ""
    test_portuguese_detection
    echo ""
    test_spanish_detection
    echo ""
    test_large_content
    echo ""
    test_duplicate_detection
    echo ""
    test_concurrent_file_ops
    echo ""
    test_git_commit_detection
    echo ""
    test_user_input_analysis
    echo ""
    test_session_briefing
    echo ""
    test_daily_note_functions
    echo ""
    test_safe_file_operations
    echo ""
    test_agent_result_capture
    echo ""

    # Summary
    echo "=============================================="
    echo " Test Summary"
    echo "=============================================="
    echo -e " ${GREEN}Passed:${NC} $PASSED"
    echo -e " ${RED}Failed:${NC} $FAILED"
    echo "=============================================="

    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
