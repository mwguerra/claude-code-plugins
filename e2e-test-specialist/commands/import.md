---
description: Import an existing markdown E2E ledger (directives, credentials, phases, tests, runs) into the database
allowed-tools: Bash(python3:*), Bash(sqlite3:*), Bash(ls:*), Bash(cat:*), Read(*)
argument-hint: <path/to/ledger.md> [--dry-run]
---

# /e2e-test-specialist:import

Parse a markdown ledger and populate the database. Designed to handle real,
hand-written ledger files at scale (51+ phases, ~1000+ steps, multi-year
historical run logs).

## Sections recognized

| H2 heading                                  | Becomes                                |
|---------------------------------------------|----------------------------------------|
| `## Directives`                             | `directives` rows (one per H3)         |
| `## VPS Infrastructure & Credentials`       | `infrastructure` + `credentials` rows  |
| `## Test App Matrix`                        | `apps` rows + extra credentials (PATs) |
| `## Server Distribution Plan`               | `infrastructure` + `credentials` (DO)  |
| `## E2E Test Phases`                        | `phases` + `tests` + `test_steps` + auto-tags |
| `## Test Count Summary`                     | updates `phases.expected_test_count`   |
| `## Test Results Log`                       | historical `test_runs` + `memories`    |
| any other H2                                | preserved as a `memories` row (never silently dropped) |

Per-test auto-tags come from `${CLAUDE_PLUGIN_ROOT}/schemas/tag-taxonomy.json`
(keyword → tag map). Customize that file before importing if you want different
tags on insert.

## Usage

```bash
# Inspect what would be imported, no writes:
/e2e-test-specialist:import path/to/ledger.md --dry-run

# Real import:
/e2e-test-specialist:import path/to/ledger.md
```

## Process

1. Verify `.e2e-testing/e2e-tests.sqlite` exists. If not, tell the user to
   run `/e2e-test-specialist:init` first.
2. Run the importer:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/import-ledger.py" "$1" ${2:+"$2"}
```

3. Print the summary returned by the script. Ask the user to spot-check:
   - "Were all your phases recognized?" (phases count vs. expected)
   - "Any preserved-as-memory sections worth re-parsing?" (the importer never
     drops content; sections it didn't recognize go into the `memories` table
     so the agent can refine later.)
4. If credentials were imported, remind the user that the database is
   gitignored. Never paste credential values back to chat.

## Notes for the agent

- Re-running import on the same file is **idempotent for tests/phases/steps**
  (uses `INSERT OR REPLACE`). It is **additive for credentials/memories**
  (each run appends new rows). Tell the user before re-importing.
- If the user has hand-edited tests in the DB and re-imports, their edits
  may be overwritten. Suggest exporting first via `/e2e-test-specialist:export`
  if available.
- The importer preserves the source markdown in each row's `raw_markdown`
  column. To inspect a phase's source: `sqlite3 .e2e-testing/e2e-tests.sqlite
  "SELECT raw_markdown FROM phases WHERE id='P05';"`.
