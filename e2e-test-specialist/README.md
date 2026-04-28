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
├── e2e-tests.sqlite             SQLite DB, WAL mode, schema v1.4
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

`schemas/schema.sql` is the canonical source. Highlights (v1.4.0):

- **27 tables** — all v1.2 tables plus `lifecycle_hooks` (v1.3), and
  `test_coverage_links`, `notifications`, `resource_ledger` (v1.4).
- **10 views** — v1.2's seven plus `v_skip_rollup`, `v_latest_step_status`,
  `v_latest_test_status` (all v1.4).
- **Migration scripts**: `migrate-v1.0-to-v1.1.sh` → `migrate-v1.1-to-v1.2.sh`
  → `migrate-v1.2-to-v1.3.sh` → `migrate-v1.3-to-v1.4.sh`. `/init` detects the
  existing version and runs the right chain.

### Plugin / schema compat matrix

| Plugin version | Schema version | Notable additions                                                                  |
|----------------|----------------|------------------------------------------------------------------------------------|
| 2.0.0          | 1.2.0          | First DB-backed release                                                            |
| 2.1.0          | 1.2.0          | Hardened `/test` step 7 (ultrathink fix loop)                                       |
| 2.2.0          | 1.3.0          | `lifecycle_hooks` table; `/before-all`, `/after-all`; R34/R35 default mode         |
| 2.3.0          | 1.3.0          | `/sessions`, `/failures`, `/pending`, schema cheat sheet                            |
| 2.4.0          | 1.3.0          | `/before-all`, `/after-all` upsert wrappers                                         |
| 2.5.0          | 1.3.0          | Pre-run briefing, `/authorize`, `/fix-failures`, strict skip discipline            |
| 2.6.0          | 1.4.0          | `skip_reason`, `fix_attempt_index`, `idempotent`, `affected_tests`; `test_coverage_links` / `notifications` / `resource_ledger` tables; `/doctor`, `/schema`, `/diff`, `/recommend`, `/skipped`, `/cost`, `/notify`, `/wizard`; cascade circuit breaker + kill switch + `--dry-run` in autopilot |
| **2.7.0**      | **1.4.0**      | `/reset` — execute after-all teardown + reset run pointer (default), `--clear-history` (catalog kept, run history wiped), or `--hard --ledger <path>` (full re-init + re-import) |

Older plugin versions can run against older schemas, but newer commands
(e.g. `/skipped`) require the schema upgrade. `/init` migrates safely.

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
