#!/usr/bin/env bash
# Shared helpers for e2e-test-specialist commands.
# Source this from any command:
#   source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
#
# Notes:
#   - All DB operations use sqlite3 with -bail and JSON-safe quoting (single-quote
#     escaping). Never interpolate user input directly into SQL.
#   - Activity log is append-only, ISO-8601 timestamps, single line per event.

set -uo pipefail

E2E_ROOT_DIR="${E2E_ROOT_DIR:-.e2e-testing}"
E2E_DB="${E2E_DB:-${E2E_ROOT_DIR}/e2e-tests.sqlite}"
E2E_LOG="${E2E_LOG:-${E2E_ROOT_DIR}/logs/activity.log}"
E2E_CONFIG="${E2E_CONFIG:-${E2E_ROOT_DIR}/config.json}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

e2e_log() {
    # Args: <level> <component> <message...>
    local level="${1:-INFO}"; shift
    local component="${1:-system}"; shift
    local message="$*"
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    mkdir -p "$(dirname "$E2E_LOG")"
    printf '%s [%s] [%s] %s\n' "$ts" "$level" "$component" "$message" >> "$E2E_LOG"
}

e2e_die() {
    e2e_log ERROR "${E2E_COMPONENT:-cli}" "$*"
    printf 'error: %s\n' "$*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# DB access
# ---------------------------------------------------------------------------

e2e_require_db() {
    [[ -f "$E2E_DB" ]] || e2e_die "no database at $E2E_DB — run /e2e-test-specialist:init first"
}

e2e_query() {
    # Args: <sql>; reads from $E2E_DB; emits JSON lines (one row per line).
    e2e_require_db
    sqlite3 -bail -json "$E2E_DB" "$1"
}

e2e_query_value() {
    # Args: <sql>; emits a single scalar value (unquoted).
    e2e_require_db
    sqlite3 -bail -noheader -separator $'\t' "$E2E_DB" "$1"
}

e2e_exec() {
    # Args: <sql>; executes a write. Caller is responsible for safe interpolation.
    # ".timeout 5000" ensures concurrent writers wait up to 5s for the WAL lock
    # instead of failing immediately with SQLITE_BUSY. Uses the dot-command
    # form (silent) rather than `PRAGMA busy_timeout` which would emit a row.
    e2e_require_db
    sqlite3 -bail -cmd ".timeout 5000" "$E2E_DB" "$1"
}

# Quote a string for safe inclusion in SQL (single-quote escape).
e2e_sql_quote() {
    # Args: <string>
    local s="${1//\'/\'\'}"
    printf "'%s'" "$s"
}

# ---------------------------------------------------------------------------
# ID helpers
# ---------------------------------------------------------------------------

# Generate the next sequential ID for a table+prefix combo.
# Atomic: wraps SELECT MAX + (no insert here, but caller must run subsequent
# INSERT inside the same transaction to avoid races).
# For self-contained atomic alloc-and-insert, prefer e2e_alloc_and_insert below.
e2e_next_id() {
    local table="$1"
    local prefix="$2"
    local n
    n="$(e2e_query_value "
        BEGIN IMMEDIATE;
        SELECT COALESCE(MAX(CAST(SUBSTR(id, ${#prefix}+2) AS INTEGER)), 0) + 1
          FROM ${table} WHERE id LIKE '${prefix}-%';
        COMMIT;
    ")"
    printf '%s-%03d' "$prefix" "$n"
}

# Allocate the next ID and insert the row in a single BEGIN IMMEDIATE transaction.
# Args: <table> <prefix> <columns_csv> <values_sql>
# The values_sql must reference the new id as the literal token '__NEXT_ID__'
# (with surrounding single quotes) — this function replaces it with the
# subquery that resolves to the freshly allocated id. Returns the new id.
#
# Example:
#   e2e_alloc_and_insert directives DIR \
#       "id,title,body,enforcement,active" \
#       "'__NEXT_ID__', $(e2e_sql_quote "$T"), $(e2e_sql_quote "$B"), 'warning', 1"
e2e_alloc_and_insert() {
    local table="$1" prefix="$2" cols="$3" vals="$4"
    e2e_require_db
    # Replace the quoted placeholder with an unquoted subquery; the surrounding
    # single quotes in the caller's values string are intentional sentinels.
    local resolved="${vals//\'__NEXT_ID__\'/(SELECT id FROM next)}"
    sqlite3 -bail -cmd ".timeout 5000" "$E2E_DB" <<SQL
BEGIN IMMEDIATE;
WITH next AS (
    SELECT printf('${prefix}-%03d',
        COALESCE(MAX(CAST(SUBSTR(id, ${#prefix}+2) AS INTEGER)), 0) + 1) AS id
      FROM ${table} WHERE id LIKE '${prefix}-%'
)
INSERT INTO ${table} (${cols})
SELECT ${resolved};
SELECT id FROM ${table} WHERE rowid = last_insert_rowid();
COMMIT;
SQL
}

# Generate a session id: sess-{epoch}-{rand4}
e2e_new_session_id() {
    local r
    r="$(printf '%04x' $((RANDOM)))"
    printf 'sess-%s-%s' "$(date -u +%Y%m%d%H%M%S)" "$r"
}

# Generate the next run id (R-NNN). Atomic alloc-and-insert: caller passes label/url.
e2e_next_run_id() {
    e2e_next_id test_runs R
}

# ---------------------------------------------------------------------------
# Redaction — never let credential values leak into logs / reports
# ---------------------------------------------------------------------------

# Replace any known credential VALUE in a string with [redacted:{name}:{key}].
# Reads stdin, writes to stdout. Delegates to scripts/redact.py so the python
# script can read the caller's stdin (a heredoc would shadow it).
e2e_redact() {
    e2e_require_db
    python3 "${CLAUDE_PLUGIN_ROOT}/scripts/redact.py" "$E2E_DB"
}

# ---------------------------------------------------------------------------
# Directive violation logging
# ---------------------------------------------------------------------------

# Args: <enforcement: blocking|warning|advisory> <action_kind> <description> [user_decision]
e2e_record_violation() {
    local enforcement="$1" action_kind="$2" description="$3" decision="${4:-}"
    e2e_require_db
    local run_id exec_id
    run_id="$(e2e_query_value "SELECT active_run_id FROM state WHERE id=1;")"
    exec_id="$(e2e_query_value "
        SELECT current_execution_id FROM sessions
         WHERE id=(SELECT active_session_id FROM state WHERE id=1);
    ")"
    sqlite3 -bail -cmd ".timeout 5000" "$E2E_DB" <<SQL
BEGIN IMMEDIATE;
WITH next AS (
    SELECT printf('VIO-%04d',
        COALESCE(MAX(CAST(SUBSTR(id, 5) AS INTEGER)), 0) + 1) AS id
      FROM directive_violations WHERE id LIKE 'VIO-%'
)
INSERT INTO directive_violations
    (id, run_id, execution_id, enforcement, action_kind, description, user_decision)
SELECT id,
       NULLIF($(e2e_sql_quote "$run_id"), ''),
       NULLIF($(e2e_sql_quote "$exec_id"), ''),
       $(e2e_sql_quote "$enforcement"),
       $(e2e_sql_quote "$action_kind"),
       $(e2e_sql_quote "$description"),
       NULLIF($(e2e_sql_quote "$decision"), '')
  FROM next;
COMMIT;
SQL
    e2e_log WARN directives "violation: $enforcement | $action_kind | $description"
}

# ---------------------------------------------------------------------------
# Config access (no jq dependency; use python3, which is on stock macOS).
# ---------------------------------------------------------------------------

e2e_config_get() {
    # Args: <dotted.path> [default]
    local path="$1"
    local default="${2:-}"
    local cfg="$E2E_CONFIG"
    [[ -f "$cfg" ]] || cfg="${CLAUDE_PLUGIN_ROOT}/schemas/default-config.json"
    python3 - "$cfg" "$path" "$default" <<'PY'
import json, sys
cfg_path, dotted, default = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(cfg_path) as f:
        data = json.load(f)
    for part in dotted.split('.'):
        data = data[part]
    print(data if not isinstance(data, (dict, list)) else json.dumps(data))
except (KeyError, FileNotFoundError, json.JSONDecodeError):
    print(default)
PY
}

# ---------------------------------------------------------------------------
# Session lifecycle (heartbeat-based)
# ---------------------------------------------------------------------------

# Start a new session for a given run.
# Args: <run_id>
# Echoes the new session id.
e2e_session_start() {
    local run_id="$1"
    local sid
    sid="$(e2e_new_session_id)"
    local host
    host="$(hostname 2>/dev/null || echo unknown)"
    e2e_exec "
        INSERT INTO sessions (id, run_id, status, process_info)
        VALUES ($(e2e_sql_quote "$sid"), $(e2e_sql_quote "$run_id"), 'active', $(e2e_sql_quote "$host"));
        UPDATE state SET active_session_id = $(e2e_sql_quote "$sid"),
                         active_run_id     = $(e2e_sql_quote "$run_id"),
                         last_update       = datetime('now')
         WHERE id=1;
    "
    e2e_log INFO session "started $sid for run=$run_id"
    printf '%s' "$sid"
}

# Update heartbeat on the active session. Cheap; call after every browser/SSH/API tool call.
e2e_heartbeat() {
    local sid
    sid="$(e2e_query_value "SELECT active_session_id FROM state WHERE id=1;")"
    [[ -n "$sid" ]] || return 0
    e2e_exec "UPDATE sessions SET last_heartbeat = datetime('now')
               WHERE id = $(e2e_sql_quote "$sid") AND status='active';"
}

# Mark stale active sessions as crashed. Returns number marked.
e2e_reap_stale_sessions() {
    local stale
    stale="$(e2e_config_get crash_detection.heartbeat_stale_seconds 1200)"
    local n
    n="$(e2e_query_value "
        SELECT COUNT(*) FROM sessions
         WHERE status='active'
           AND (julianday('now') - julianday(last_heartbeat)) * 86400 > ${stale};
    ")"
    if [[ "${n:-0}" -gt 0 ]]; then
        e2e_exec "
            UPDATE sessions
               SET status='crashed', ended_at=datetime('now')
             WHERE status='active'
               AND (julianday('now') - julianday(last_heartbeat)) * 86400 > ${stale};
        "
        e2e_log WARN session "reaped ${n} stale session(s)"
    fi
    printf '%s' "${n:-0}"
}

# Set current pointer (test/step/execution) for the active session.
# Args: <test_id> <step_id> <execution_id>
e2e_session_set_pointer() {
    local sid
    sid="$(e2e_query_value "SELECT active_session_id FROM state WHERE id=1;")"
    [[ -n "$sid" ]] || return 0
    e2e_exec "
        UPDATE sessions
           SET current_test_id      = $(e2e_sql_quote "$1"),
               current_step_id      = $(e2e_sql_quote "$2"),
               current_execution_id = $(e2e_sql_quote "$3"),
               last_heartbeat       = datetime('now')
         WHERE id = $(e2e_sql_quote "$sid");
    "
}

e2e_session_end() {
    # Args: <status: completed|paused|aborted>
    local final_status="${1:-completed}"
    case "$final_status" in
        completed|paused|aborted) ;;
        *) e2e_die "invalid session status: $final_status" ;;
    esac
    local sid
    sid="$(e2e_query_value "SELECT active_session_id FROM state WHERE id=1;")"
    [[ -n "$sid" ]] || return 0
    e2e_exec "
        UPDATE sessions
           SET status   = $(e2e_sql_quote "$final_status"),
               ended_at = datetime('now')
         WHERE id = $(e2e_sql_quote "$sid");
        UPDATE state    SET active_session_id=NULL, last_update=datetime('now') WHERE id=1;
    "
    e2e_log INFO session "ended $sid status=$final_status"
}

# ---------------------------------------------------------------------------
# Step execution lifecycle
# ---------------------------------------------------------------------------

# Begin a step execution; emits the new execution id.
# Args: <run_id> <test_id> <step_id> [retry_attempt] [subject_id]
e2e_step_begin() {
    local run_id="$1" test_id="$2" step_id="$3" retry="${4:-0}" subject="${5:-}"
    # Force retry to integer to keep numeric interpolation safe.
    retry=$((retry + 0))
    local subject_part="${subject:-NOSUBJ}"
    local exec_id="EX-${run_id}-${step_id}-${subject_part}-${retry}"
    e2e_exec "
        INSERT OR REPLACE INTO step_executions
            (id, run_id, test_id, step_id, subject_id, retry_attempt, status, started_at)
        VALUES
            ($(e2e_sql_quote "$exec_id"), $(e2e_sql_quote "$run_id"), $(e2e_sql_quote "$test_id"),
             $(e2e_sql_quote "$step_id"),
             NULLIF($(e2e_sql_quote "$subject"), ''),
             $retry, 'in-progress', datetime('now'));
    "
    e2e_session_set_pointer "$test_id" "$step_id" "$exec_id"
    e2e_log INFO step "begin $exec_id (subject=${subject:-none})"
    printf '%s' "$exec_id"
}

# End a step execution with terminal status.
# Args: <execution_id> <status: passed|failed|skipped|blocked> <actual_result> [error_message] [evidence_snapshot] [bug_id]
e2e_step_end() {
    local exec_id="$1" status="$2" actual="${3:-}" err="${4:-}" evidence="${5:-}" bug="${6:-}"
    case "$status" in
        passed|failed|skipped|blocked) ;;
        *) e2e_die "invalid step status: $status" ;;
    esac
    e2e_exec "
        UPDATE step_executions
           SET status            = $(e2e_sql_quote "$status"),
               completed_at      = datetime('now'),
               duration_ms       = CAST((julianday('now') - julianday(started_at)) * 86400 * 1000 AS INTEGER),
               actual_result     = $(e2e_sql_quote "$actual"),
               error_message     = $(e2e_sql_quote "$err"),
               evidence_snapshot = $(e2e_sql_quote "$evidence"),
               bug_id            = NULLIF($(e2e_sql_quote "$bug"), '')
         WHERE id = $(e2e_sql_quote "$exec_id");
    "
    e2e_heartbeat
    e2e_log INFO step "end   $exec_id status=$status"
}

# ---------------------------------------------------------------------------
# Pretty-printing helpers (no external deps)
# ---------------------------------------------------------------------------

e2e_section() {
    printf '\n\033[1;36m== %s ==\033[0m\n' "$*"
}

e2e_kv() {
    printf '  %-22s %s\n' "$1" "$2"
}
