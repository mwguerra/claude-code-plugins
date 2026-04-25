# e2e-test-specialist

A Claude Code plugin for running large, resumable, database-driven E2E test
suites with full Playwright MCP integration. Built for the long haul: 50+
phases, 1000+ steps, multi-month iterations, "round 35" fatigue.

> **Why a plugin?** Markdown ledgers fall apart at scale: hand-edits collide,
> history grows unbounded, parallel runs are guesswork, crash recovery is
> manual. This plugin moves the plan into SQLite, checkpoints every step
> before it runs, and resumes from the last unfinished step automatically —
> across crashes, computer reboots, and Claude session resets.

## Quickstart

```bash
# 1. Install the plugin into your Claude Code config (per CC plugin docs)

# 2. In a project directory:
/e2e-test-specialist:init                              # one-time

# 3. If you have an existing markdown plan:
/e2e-test-specialist:import path/to/your-ledger.md
# Otherwise, scan the codebase to bootstrap one:
/e2e-test-specialist:plan discover

# 4. Open a run and start working:
/e2e-test-specialist:start https://app.example.test --label "R-001"
/e2e-test-specialist:test --batch 50
# (computer reboots, Claude session ends, etc.)
/e2e-test-specialist:resume                            # picks up exactly where you stopped
/e2e-test-specialist:test                              # continues
```

## What lives where

```
.e2e-testing/                    (gitignored — contains credentials)
├── e2e-tests.sqlite             SQLite DB, WAL mode, schema v1.2
├── config.json                  Tunable: heartbeat, retry, viewports, redaction
├── runs/R-NNN/screenshots/      Per-run artifacts
├── runs/_backups/               Auto-backups before destructive ops
└── logs/activity.log            Append-only event log
```

## Command index

| Lifecycle              | Plan                                | Run                                 | Triage                          |
|------------------------|-------------------------------------|-------------------------------------|---------------------------------|
| `/init`                | `/import` <ledger.md>               | `/start` <base-url>                 | `/bugs` list / open / fix       |
| `/status`              | `/export`                           | `/test` [filters]                   | `/memory` add / list / search   |
| `/repair`              | `/plan` discover / add / update / deprecate / drift | `/resume`           | `/screenshot` (manual)         |
|                        | `/sites` add / update / list        | `/restart`                          | `/report` <run-id>             |
|                        | `/roles` add / link-credential      |                                     | `/tag` list / tests / bulk-tag  |

Detailed help for each command lives in `commands/<name>.md`.

## Core concepts

- **Plan in DB, not in markdown.** Phases → tests → steps + tags + directives
  + credentials + apps + infrastructure + sites + roles all live in SQLite.
  The plan is queryable, diffable, and resilient to Claude resets.
- **Every step is a checkpoint.** `INSERT step_executions(status='in-progress')`
  is committed *before* the action runs. If anything crashes, the row
  survives; `crash-recovery.sh` finds it; `/resume` continues from there.
- **Heartbeat after every tool call.** Stale heartbeat → reaped to `crashed`.
  Long-blocking actions spawn a background watcher so legitimate waits
  (apt locks, image transfers) don't false-positive.
- **Append-only by design.** Tests never silently disappear; they get
  `deprecated_at` set. `step_executions`, `bugs`, `memories`, `screenshots`,
  and `test_runs` are fully append-only.
- **Tags drive selection.** `--tag wireguard` selects across phases. Auto-tags
  apply during `/import` from `schemas/tag-taxonomy.json`; manual tags layer
  on top.
- **Parametrization is first-class.** `tests.applies_to = ["APP-001",
  "SITE-003", "ROLE-admin"]` runs the same procedure once per subject;
  `action_template = "Navigate to https://{{subject.target_domain}}"` renders
  per subject; `step_executions.subject_id` records which one ran.
- **Credentials are redacted at output time.** `/report`, `/export`, and
  `/screenshot` all pass through `e2e_redact` so secrets in the
  `credentials.fields` JSON never leak into ledger files or chat output.

## Running the plugin's self-tests

```bash
bash tests/run-tests.sh
```

11 test cases covering: init layout, schema version, atomic ID allocation,
template rendering, redaction, parallel-write concurrency, session lifecycle
(start/heartbeat/reap), step checkpointing, the `applies_to` integrity
trigger, backup/restore, the SQL-injection linter, and import-fixture
round-trip.

## SQL-injection linter

```bash
bash tests/lint-sql.sh
```

Sweeps every `commands/*.md` and `scripts/*.sh` for risky bash-into-SQL
interpolation patterns. All real interpolations must go through
`e2e_sql_quote`. Numeric / known-internal interpolations need an explicit
`# lint-sql: numeric-safe` or `# lint-sql: internal-safe` pragma comment.

## Tuning points

Two scripts are designed to be edited per project:

- `scripts/retry-policy.sh` — when should a failed step retry? Per error_kind
  + step_kind. Defaults are conservative.
- `scripts/directive-check.sh` — what happens when an action matches a
  blocking directive? Defaults are hard-block + log violation.

The crash-detection threshold is `crash_detection.heartbeat_stale_seconds` in
`config.json`. Set above your longest legitimate single-step duration.

## Schema

`schemas/schema.sql` is the canonical source. Highlights:

- 22 tables: directives, credentials, roles, integrations, infrastructure,
  apps, sites, phases, tests, test_steps, step_assertions, assertion_results,
  test_dependencies, coverage_targets, coverage_hits, directive_violations,
  tags, test_tags, test_runs, step_executions, bugs, screenshots, memories
  (with FTS5), sessions, state.
- 7 views: `v_run_progress`, `v_tests_with_tags`, `v_test_subjects`,
  `v_subjects_resolved`, `v_test_results_by_subject`, `v_flaky_steps`,
  `v_coverage`.
- Migration scripts: `migrate-v1.0-to-v1.1.sh`, `migrate-v1.1-to-v1.2.sh`.
  `/init` detects the existing version and runs the right chain.

## Authoring a markdown ledger

`scripts/import-ledger.py` recognizes these `## H2` sections (any subset):

- `## Directives` — H3 entries become `directives` rows
- `## VPS Infrastructure & Credentials` — infra rows + credentials
- `## Test App Matrix` — apps rows (markdown table; column `app` = name)
- `## Server Distribution Plan` — additional infra + DO tokens
- `## E2E Test Phases` — `### Phase N: Title`, then `**N.M Title**` test
  groups, then numbered-list steps
- `## Test Count Summary` — updates `phases.expected_test_count`
- `## Test Results Log` — historical runs + bugs + memories

Anything else under `## H2` is preserved as a `memories` row so nothing is
silently dropped. See `tests/fixtures/mini-ledger.md` for a minimal example.
