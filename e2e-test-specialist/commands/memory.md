---
description: Add, list, and search project-level memories (decisions, gotchas, lessons learned)
allowed-tools: Bash(bash:*), Bash(sqlite3:*), AskUserQuestion, Read(*)
argument-hint: [add | list | search <query>] [--kind ...] [--tag ...]
---

# /e2e-test-specialist:memory

Persistent knowledge layer for E2E runs. Memories survive across runs and
crashes; they are the institutional ledger that makes round 35 less painful
than round 5.

## What goes here

| Kind            | Use for                                                                        |
|-----------------|--------------------------------------------------------------------------------|
| `decision`      | "We chose nip.io because the DO token lacks Domains scope"                      |
| `workaround`    | "Filament radio Livewire defaults reset on hydrate — re-click before save"      |
| `gotcha`        | "LE rate limit hit on *.foo.com.br — wait until next window or use staging"     |
| `convention`    | "Site domains follow {appname}.{wildcard}; never deviate"                        |
| `environment`   | "WG mesh IPs assigned per server are 10.100.43.X"                               |
| `lesson-learned`| "Phase 4 should run after Phase 2 fully ready, not in parallel"                  |
| `bug-pattern`   | "419 Page Expired → CSRF mismatch → reset session"                               |
| `credential-note` | "DO API token rotates every 90d — set calendar reminder"                       |
| `other`         | Catch-all                                                                       |

## Subcommands

### `add`

Use `AskUserQuestion` to collect:

- title
- kind (from list above)
- importance (1–5; default 3)
- body (multiline)
- why_important (one sentence — what would go wrong without this?)
- related run / test / bug (optional)
- tags (comma-separated; freely chosen)

Insert:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
MID="$(e2e_next_id memories M)"
e2e_exec "
  INSERT INTO memories (id, title, kind, body, why_important, importance,
                        related_run_id, related_test_id, related_bug_id, tags, status)
  VALUES (
    '$MID',
    $(e2e_sql_quote "$TITLE"),
    $(e2e_sql_quote "$KIND"),
    $(e2e_sql_quote "$BODY"),
    $(e2e_sql_quote "$WHY"),
    $IMPORTANCE,
    NULLIF($(e2e_sql_quote "$RUN_ID"), ''),
    NULLIF($(e2e_sql_quote "$TEST_ID"), ''),
    NULLIF($(e2e_sql_quote "$BUG_ID"), ''),
    $(e2e_sql_quote "$TAGS_JSON"),
    'active'
  );
"
```

### `list`

Default: most recent 30 active memories, optionally filtered by `--kind` /
`--tag`.

```bash
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT id, kind, importance,
         substr(title,1,60) AS title,
         use_count,
         created_at
    FROM memories
   WHERE status = 'active'
     AND (:kind IS NULL OR kind = :kind)
     AND (:tag  IS NULL OR EXISTS(SELECT 1 FROM json_each(tags) j WHERE j.value = :tag))
   ORDER BY importance DESC, created_at DESC
   LIMIT 30;
"
```

### `search <query>`

FTS5 search across title + body + tags:

```bash
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT m.id, m.kind, m.importance, substr(m.title,1,60) AS title
    FROM memories m
    JOIN memories_fts f ON f.rowid = m.rowid
   WHERE memories_fts MATCH $(e2e_sql_quote "$QUERY")
     AND m.status = 'active'
   ORDER BY rank
   LIMIT 20;
"
```

When the agent uses a memory (loads it as context for a step), it should
update use stats:

```sql
UPDATE memories
   SET use_count = use_count + 1, last_used_at = datetime('now')
 WHERE id IN (...);
```

## Notes for the agent

- During a run, **load the top memories at the start of each test** —
  importance ≥ 3 active memories matching the test's tags. This is the
  "directives flow into action" loop.
- When a step finds a new gotcha, capture it immediately; don't batch.
  Memories are cheap to add and expensive to lose.
