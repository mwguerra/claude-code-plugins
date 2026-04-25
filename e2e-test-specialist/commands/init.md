---
description: Initialize the .e2e-testing/ folder with a SQLite database in the current project
allowed-tools: Bash(bash:*), Bash(ls:*), Bash(sqlite3:*), Read(*)
argument-hint: (no arguments)
---

# /e2e-test-specialist:init

Creates `.e2e-testing/` in the current working directory with:

- `e2e-tests.sqlite` — WAL-mode SQLite database, 16 tables + FTS + views
- `config.json` — copied from the plugin's `default-config.json`; safe to edit
- `runs/` — per-run artifact directory (screenshots, logs)
- `logs/activity.log` — append-only activity log

Idempotent: re-running on an initialized project is a no-op.

## What you should know

- The `.e2e-testing/` directory **contains credentials**. The plugin's repo
  `.gitignore` excludes it; if you're adding this plugin to a new project, add
  `.e2e-testing/` to that project's `.gitignore` too.
- Two policy files exist at `${CLAUDE_PLUGIN_ROOT}/scripts/retry-policy.sh` and
  `${CLAUDE_PLUGIN_ROOT}/scripts/directive-check.sh` with TODO blocks. Read
  them once and tune the marked lines to your project's failure modes — that's
  where domain-specific behavior lives.
- The default crash-detection threshold is **1200s** (20 min). Edit
  `.e2e-testing/config.json` → `crash_detection.heartbeat_stale_seconds`. Set
  this above your longest single-step duration; for the PrimeForge ledger
  (apt locks up to 900s) 1200s is appropriate. Lower for faster sites.

## Behavior

Run the init script, which creates the directory tree and applies the schema:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-db.sh"
```

The script reports what it created and prints next steps. If the database
already exists at the current schema version, it exits cleanly without
overwriting anything.

## After init

- If you have an existing markdown ledger:
  `/e2e-test-specialist:import path/to/ledger.md`
- If you don't, generate a plan from the app code:
  `/e2e-test-specialist:plan`
- Either way, then start a run:
  `/e2e-test-specialist:start`
