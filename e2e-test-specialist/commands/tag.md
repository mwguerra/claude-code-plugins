---
description: Manage tags — list tags, list tests with a tag, add/remove tags on tests
allowed-tools: Bash(bash:*), Bash(sqlite3:*), AskUserQuestion, Read(*)
argument-hint: [list | tests <tag> | add <test-id> <tag>[,tag...] | remove <test-id> <tag>] [--auto-only]
---

# /e2e-test-specialist:tag

Tags are first-class for navigating a 1000+ test suite.
Auto-tags are applied during `/import` from
`${CLAUDE_PLUGIN_ROOT}/schemas/tag-taxonomy.json`. Manual tags layer on top.

## Subcommands

### `list` (default)

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

sqlite3 -bail -column -header "$E2E_DB" "
  SELECT t.name,
         CASE t.auto WHEN 1 THEN 'auto' ELSE 'manual' END AS source,
         COUNT(tt.test_id) AS test_count
    FROM tags t
    LEFT JOIN test_tags tt ON tt.tag_name = t.name
   WHERE (:auto_only = 0 OR t.auto = 1)
   GROUP BY t.name
   ORDER BY test_count DESC, t.name;
"
```

### `tests <tag>`

List all tests with a given tag:

```bash
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT t.id, t.phase_id,
         substr(t.title, 1, 50) AS title,
         t.test_kind,
         CASE t.deprecated_at WHEN NULL THEN 'active' ELSE 'deprecated' END AS state
    FROM tests t
    JOIN test_tags tt ON tt.test_id = t.id
   WHERE tt.tag_name = $(e2e_sql_quote "$1")
   ORDER BY t.test_order;
"
```

### `add <test-id> <tag>[,<tag>...]`

```bash
for tag in $(echo "$2" | tr , ' '); do
    e2e_exec "INSERT OR IGNORE INTO tags (name, auto) VALUES ($(e2e_sql_quote "$tag"), 0);"
    e2e_exec "INSERT OR IGNORE INTO test_tags (test_id, tag_name)
              VALUES ($(e2e_sql_quote "$1"), $(e2e_sql_quote "$tag"));"
done
e2e_log INFO tag "added [$2] to $1"
```

### `remove <test-id> <tag>`

```bash
e2e_exec "DELETE FROM test_tags WHERE test_id=$(e2e_sql_quote "$1") AND tag_name=$(e2e_sql_quote "$2");"
```

### `bulk-tag --tag <new-tag> --where <SQL predicate>`

Power feature. Apply a tag to every test matching a predicate:

```bash
e2e_exec "
  INSERT OR IGNORE INTO tags (name, auto) VALUES ($(e2e_sql_quote "$NEW_TAG"), 0);
  INSERT OR IGNORE INTO test_tags (test_id, tag_name)
  SELECT id, $(e2e_sql_quote "$NEW_TAG") FROM tests WHERE $WHERE;
"
```

Common patterns:
- `--where "phase_id = 'P25'"` — tag everything in Phase 25 (LB)
- `--where "raw_markdown LIKE '%WireGuard%'"` — tag everything mentioning WG
- `--where "test_kind = 'browser' AND is_critical = 1"` — tag critical browser tests

## Notes

- Tags are cheap; over-tagging is fine. Under-tagging hurts: a test you can't
  find is a test you can't update.
- Auto tags can be re-applied by re-running `/import` (which uses the current
  taxonomy). Manual tags are preserved across re-imports.
- For run filtering, `/start --tag X` works on the union of auto + manual
  tags.
