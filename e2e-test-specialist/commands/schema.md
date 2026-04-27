---
description: Print canonical column lists, view definitions, and useful query templates for the plugin's schema
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Read(*)
argument-hint: [<table-or-view>] [--all]
---

# /e2e-test-specialist:schema

Authoritative source for "what columns does X have?" Use this instead of
guessing column names. The agent has been known to invent
`sessions.paused_at`, `step_executions.executed_at`, `tests.run_id`,
`tests.status` — none of those exist. This command emits the truth.

## Usage

| Form                       | Effect                                                   |
|----------------------------|----------------------------------------------------------|
| (no args)                  | List all tables + views + their row counts               |
| `<name>`                   | Full column list, indices, sample rows for that name     |
| `--all`                    | Full schema dump (tables + views + indices)              |

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

if [[ -n "${ALL:-}" ]]; then
    sqlite3 -bail "$E2E_DB" ".schema"
    exit 0
fi

if [[ -z "${NAME:-}" ]]; then
    e2e_section "Tables"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT m.name AS table_name, COUNT(c.name) AS col_count
        FROM sqlite_master m
        LEFT JOIN pragma_table_info(m.name) c ON 1=1
       WHERE m.type='table' AND m.name NOT LIKE 'sqlite_%'
                                 AND m.name NOT LIKE '%_fts%'
                                 AND m.name NOT LIKE '%_config'
       GROUP BY m.name
       ORDER BY m.name;
    "

    e2e_section "Views"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT name FROM sqlite_master WHERE type='view' ORDER BY name;
    "

    e2e_section "Tip"
    echo "Drill into one:  /e2e-test-specialist:schema <table-or-view>"
    echo "Full dump:       /e2e-test-specialist:schema --all"
    exit 0
fi

# Specific object
KIND="$(e2e_query_value "SELECT type FROM sqlite_master WHERE name=$(e2e_sql_quote "$NAME");")"
[[ -n "$KIND" ]] || e2e_die "no such table or view: $NAME"

e2e_section "$KIND: $NAME"
sqlite3 -bail "$E2E_DB" "SELECT sql FROM sqlite_master WHERE name=$(e2e_sql_quote "$NAME");"

if [[ "$KIND" == "table" ]]; then
    e2e_section "Columns (PRAGMA table_info)"
    sqlite3 -bail -column -header "$E2E_DB" "PRAGMA table_info($(e2e_sql_quote "$NAME"));"

    e2e_section "Indices"
    sqlite3 -bail -column -header "$E2E_DB" "PRAGMA index_list($(e2e_sql_quote "$NAME"));"

    e2e_section "Foreign keys"
    sqlite3 -bail -column -header "$E2E_DB" "PRAGMA foreign_key_list($(e2e_sql_quote "$NAME"));"

    e2e_section "Row count"
    sqlite3 -bail -column -header "$E2E_DB" "SELECT COUNT(*) AS rows FROM \"$NAME\";"

    e2e_section "Sample rows (first 3)"
    sqlite3 -bail -column -header "$E2E_DB" "SELECT * FROM \"$NAME\" LIMIT 3;"
fi

e2e_section "Useful diagnostic commands for this object"
case "$NAME" in
    sessions)         echo "  /e2e-test-specialist:sessions" ;;
    step_executions)  echo "  /e2e-test-specialist:failures   (failed/skipped/blocked)" ;;
    tests|test_steps) echo "  /e2e-test-specialist:pending    (what's left)" ;;
    bugs)             echo "  /e2e-test-specialist:bugs" ;;
    memories)         echo "  /e2e-test-specialist:memory" ;;
    test_runs)        echo "  /e2e-test-specialist:diff <run-a> <run-b>" ;;
    lifecycle_hooks)  echo "  /e2e-test-specialist:before-all --list" ;;
    notifications)    echo "  /e2e-test-specialist:notify --list" ;;
    resource_ledger)  echo "  /e2e-test-specialist:cost" ;;
    *)                echo "  (no shortcut — use /e2e-test-specialist:status for overview)" ;;
esac
```
