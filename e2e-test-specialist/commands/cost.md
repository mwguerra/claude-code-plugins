---
description: Roll up resource_ledger entries for a run — provider, kind, count, estimated cost
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Read(*)
argument-hint: [<run-id>] [--all] [--orphans]
---

# /e2e-test-specialist:cost

Aggregates `resource_ledger` (schema v1.4.0) by provider and resource kind
for one run (default: most recent) or all runs. Use `--orphans` to find
resources that were `created` but never `destroyed` — leaks the autopilot
should clean up.

## Behavior

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

if [[ -n "${ALL:-}" ]]; then
    SCOPE="all runs"
    WHERE="1=1"
elif [[ -z "${RUN_ID:-}" ]]; then
    RUN_ID="$(e2e_query_value 'SELECT id FROM test_runs ORDER BY started_at DESC LIMIT 1;')"
    [[ -n "$RUN_ID" ]] || e2e_die "no runs in DB"
    SCOPE="$RUN_ID"
    WHERE="run_id=$(e2e_sql_quote "$RUN_ID")"
else
    SCOPE="$RUN_ID"
    WHERE="run_id=$(e2e_sql_quote "$RUN_ID")"
fi

e2e_section "Resource activity for $SCOPE"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT provider, resource_kind, action, COUNT(*) AS n,
         SUM(COALESCE(estimated_cost_cents, 0)) AS cents
    FROM resource_ledger
   WHERE $WHERE
   GROUP BY provider, resource_kind, action
   ORDER BY provider, resource_kind, action;
"

e2e_section "Total estimated spend for $SCOPE"
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT printf('%.2f USD', SUM(COALESCE(estimated_cost_cents,0)) / 100.0) AS estimated_total
    FROM resource_ledger
   WHERE $WHERE AND action='created';
"

if [[ -n "${ORPHANS:-}" ]]; then
    e2e_section "Orphan resources (created but never destroyed)"
    sqlite3 -bail -column -header "$E2E_DB" "
      SELECT c.run_id, c.provider, c.resource_id, c.resource_kind, c.label, c.created_at
        FROM resource_ledger c
       WHERE c.action='created'
         AND NOT EXISTS (
             SELECT 1 FROM resource_ledger d
              WHERE d.action='destroyed'
                AND d.provider = c.provider
                AND d.resource_id = c.resource_id
         )
       ORDER BY c.created_at DESC
       LIMIT 50;
    "
fi
```

## Recording entries from autopilot / scripts

The autopilot writes to `resource_ledger` whenever it provisions or tears
down infrastructure under a standing `/authorize` grant. Manual entries:

```sql
INSERT INTO resource_ledger
  (id, run_id, provider, resource_id, resource_kind, label, action, estimated_cost_cents, metadata)
VALUES
  ('rl-' || strftime('%s','now') || '-' || hex(randomblob(2)),
   'R-2027', 'do', '414812345', 'droplet', 'pfdo-r27-app1', 'created', 144,
   json_object('size','s-1vcpu-2gb','region','nyc3','hourly_cents','12'));
```

The `estimated_cost_cents` is whatever you record at create time (typically
`hourly_cents * estimated_hours`). Pair with a teardown entry:

```sql
INSERT INTO resource_ledger
  (id, run_id, provider, resource_id, resource_kind, label, action, metadata)
VALUES (..., 'destroyed', json_object('reason','run-end'));
```

The `--orphans` query is the safety net — anything created but not
destroyed shows up here.
