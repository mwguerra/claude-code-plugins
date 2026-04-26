---
description: One-shot autonomous run (R34/R35 mode) — setup, start, execute, ultrathink-fix on failures, continue until queue empty
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(ssh:*), Bash(curl:*), Bash(grep:*), Bash(cat:*), Bash(ls:*), Read(*), Write(*), mcp__playwright__*, mcp__plugin_playwright_playwright__*
argument-hint: [<base-url>] [--ledger <path>] [--label "..."] [--phase ...] [--tag ...] [--skip-tag ...] [--max-fix-attempts N] [--max-wall-hours H]
---

# /e2e-test-specialist:autopilot

Run the entire E2E suite end-to-end with **no human in the loop**. Sets
itself up, starts a run, executes every selected test, ultrathinks-and-fixes
genuine failures via the root-cause loop, and exits cleanly when the queue
is empty.

This command is the autonomous wrapper around the existing primitives
(`init`, `import`, `start`, `test`, `resume`). It does not duplicate their
logic — it sequences them.

## Default mode (canonical)

Unless overridden via flags, autopilot runs in **R34/R35 mode**:

- **Scope**: full autonomy — execute every selected test, fix what can be
  fixed in-flight, mark `blocked` what can't, complete the run.
- **Wall-time cap**: ∞ (unlimited). The run takes as long as it takes.
- **Per-test fix budget**: 5 attempts before marking `blocked`.
- **Base URL**: positional `<base-url>` if given, otherwise `APP_URL` from
  the project's `.env`. Errors out only if neither is available.

These defaults reflect the project's R34/R35 operating philosophy: nightly
autonomous runs that triage themselves into a morning report.

## Operating philosophy

- **Never ask the user a question** during the run unless something is
  structurally broken (missing ledger on a fresh DB, no base-url anywhere,
  DB unrecoverable). Everything else is a problem to either fix or escalate
  silently to a memory + bug row and continue.
- **Failures are bugs, not flakes.** On any non-transient failure, drop into
  the Ultrathink Root Cause loop (the agent doc + `commands/test.md` step 7
  define this exactly). Only retry true infrastructure flakes per
  `scripts/retry-policy.sh`.
- **Forward progress is mandatory.** A test that exhausts the fix budget is
  marked `blocked`, a memory + bug captures the state, and the loop moves on
  to the rest of the queue. The run as a whole completes.

## Arguments

| Flag                         | Default                      | Effect                                                                |
|------------------------------|------------------------------|-----------------------------------------------------------------------|
| `<base-url>` (positional)    | `.env` `APP_URL`             | URL the run targets                                                   |
| `--ledger <path>`            | none                         | Markdown ledger to import if DB has 0 phases                          |
| `--label "..."`              | "autopilot R34/R35"          | Free-form label written to the run row                                |
| `--phase P00,P01`            | all                          | Restrict to listed phases (forwarded to `/start`)                     |
| `--tag a,b`                  | all                          | Restrict to tests with any of these tags (forwarded to `/start`)      |
| `--skip-tag x,y`             | none                         | Exclude tests with these tags (forwarded to `/start`)                 |
| `--max-fix-attempts N`       | **5**                        | Per-test fix-loop budget. Exceeded → mark `blocked` and continue.     |
| `--max-wall-hours H`         | **0 (∞)**                    | Wall-clock cap for the whole autopilot run. 0 = unlimited.            |

## Process

### 0. Pre-flight

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"

# Parse args. Optional CLI vars: BASE_URL, LEDGER, LABEL, PHASES, TAGS,
# SKIP_TAGS, MAX_FIX_ATTEMPTS, MAX_WALL_HOURS.

# Base URL resolution: positional arg wins; otherwise read APP_URL from .env.
if [[ -z "${BASE_URL:-}" && -f .env ]]; then
    # Tolerate quoted ("https://x.test") and unquoted (https://x.test) values.
    BASE_URL="$(grep -E '^[[:space:]]*APP_URL[[:space:]]*=' .env \
                  | tail -n1 \
                  | sed -E 's/^[[:space:]]*APP_URL[[:space:]]*=[[:space:]]*//; s/^"//; s/"$//; s/^'"'"'//; s/'"'"'$//')"
fi
[[ -n "${BASE_URL:-}" ]] || e2e_die "autopilot: no <base-url> argument and no APP_URL in .env. Pass a URL or set APP_URL."

LABEL="${LABEL:-autopilot R34/R35 $(date -u +%Y-%m-%dT%H:%M:%SZ)}"
MAX_FIX_ATTEMPTS="${MAX_FIX_ATTEMPTS:-5}"
MAX_WALL_HOURS="${MAX_WALL_HOURS:-0}"
AUTOPILOT_STARTED_AT="$(date +%s)"
```

### 1. Setup — init if needed

If `.e2e-testing/e2e-tests.sqlite` does not exist, run init. Idempotent
no-op if already initialized.

```bash
if [[ ! -f .e2e-testing/e2e-tests.sqlite ]]; then
    bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-db.sh"
fi
e2e_require_db
```

### 2. Setup — import if DB is empty

```bash
PHASE_COUNT="$(e2e_query_value 'SELECT COUNT(*) FROM phases;')"
if [[ "$PHASE_COUNT" -eq 0 ]]; then
    [[ -n "$LEDGER" && -f "$LEDGER" ]] \
        || e2e_die "autopilot: DB has 0 phases and no --ledger <path> provided. This is a structural problem — pass --ledger pointing at your e2e-testing.md."
    python3 "${CLAUDE_PLUGIN_ROOT}/scripts/import-ledger.py" "$LEDGER"
    PHASE_COUNT="$(e2e_query_value 'SELECT COUNT(*) FROM phases;')"
    [[ "$PHASE_COUNT" -gt 0 ]] || e2e_die "autopilot: import produced 0 phases. Check the ledger."
fi
```

### 3. Recover or start a run

Reap stale sessions. If a prior `in-progress` run exists, **resume it**
(autopilot never wastes prior work without permission). If none, start a
new one.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/crash-recovery.sh" > /tmp/e2e-recovery.json

ACTIVE_RUN="$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')"
if [[ -z "$ACTIVE_RUN" ]]; then
    # Build the /start invocation. Forward the phase/tag filters.
    START_ARGS=("$BASE_URL" --label "$LABEL")
    [[ -n "$PHASES"    ]] && START_ARGS+=(--phase "$PHASES")
    [[ -n "$TAGS"      ]] && START_ARGS+=(--tag "$TAGS")
    [[ -n "$SKIP_TAGS" ]] && START_ARGS+=(--skip-tag "$SKIP_TAGS")

    # Invoke /e2e-test-specialist:start with these args (the slash-command
    # subroutine, not a separate process — it shares state via the DB).
    # See commands/start.md.
    # → Result: state.active_run_id is now set; an active session exists.
    ACTIVE_RUN="$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')"
fi
[[ -n "$ACTIVE_RUN" ]] || e2e_die "autopilot: failed to obtain an active run after start"
e2e_log "autopilot run = $ACTIVE_RUN"
```

### 3.5. Pre-run briefing (READ EVERY RUN — load before deciding skip-vs-drive)

Before executing the first test, the autopilot loads the **pre-run briefing**
— three sources that together encode every standing instruction the agent
must respect during this run. The briefing is the agent's authorization
context, project policy, and procedural prelude in one place.

**Load all three, in order, into the agent's working context:**

```bash
# (1) Active blocking/warning directives (the file-rules, safety, ux-standard)
DIRECTIVES="$(e2e_query "
  SELECT id, title, enforcement, body
    FROM directives
   WHERE active=1 AND enforcement IN ('blocking','warning')
   ORDER BY enforcement DESC, id ASC;
")"

# (2) Active high-importance memories that grant authorization or codify policy.
#     Imported ledger directives + /authorize entries + manually-saved standing grants.
AUTHS="$(e2e_query "
  SELECT id, title, importance, body, tags
    FROM memories
   WHERE status='active'
     AND importance >= 4
     AND (tags LIKE '%\"authorization\"%'
          OR tags LIKE '%\"standing-grant\"%'
          OR tags LIKE '%\"directive\"%'
          OR tags LIKE '%\"policy\"%')
   ORDER BY importance DESC, updated_at DESC;
")"

# (3) Active pre-run lifecycle hooks (procedural — clean-slate verification,
#     env warm-up, snapshots, credential rotation, etc.).
HOOKS="$(e2e_query "
  SELECT id, title, body, enforcement
    FROM lifecycle_hooks
   WHERE phase='pre-run' AND active=1
   ORDER BY order_idx ASC, id ASC;
")"
```

**The agent then:**

1. **Reads DIRECTIVES** as non-negotiable rules (blocking = halts the run on
   violation; warning = log + continue but flag in run summary).
2. **Reads AUTHS** as the run's authorization context. Every authorization
   memory grants permission to take actions the autopilot would otherwise
   need to ask about (e.g. provisioning Forge servers, creating DO droplets,
   modifying production-ish state inside test scope). The agent treats
   these as durable user decisions — never re-asks.
3. **Executes HOOKS** in `order_idx` ASC, then `id` ASC:
   - hook completes → log + continue
   - `enforcement='blocking'` failure → write a memory and `e2e_die`
     (active run stays `in-progress` for later `/resume`)
   - `enforcement='advisory'` failure → write a memory and continue

If any of the three queries returns zero rows, the corresponding sub-step
is a silent no-op — all three are opt-in.

### 3.6. Skip discipline (NON-NEGOTIABLE)

A test is **skipped** only when ALL of the following are true:

- The test requires infrastructure or external resources that don't exist.
- **No** authorization memory in the briefing grants permission to create
  them.
- **No** pre-run hook in the briefing provides a procedure to create them.
- The test plan itself explicitly tags the test as `cross-run-coverage` or
  `future-impl` (i.e. the ledger acknowledges it can't run in isolation).

**Forbidden reasons to skip:**

- "Needs manual approval" → check AUTHS first; if a `standing-grant`
  authorization tag covers this scope, drive live.
- "Would create real resources" → if AUTHS authorizes provisioning, drive
  live. The autopilot's no-prompt rule means there is no "ask the user"
  fallback.
- "Other tests will cover this" → cross-run coverage is a deliberate
  ledger-level decision, not a runtime shortcut. Only honor it when the
  test plan itself says so.

If the agent finds itself about to skip outside these rules, it MUST first
re-read the AUTHS list and the test's tags, then either drive live or write
a memory (kind='lesson-learned', importance=4, tag `skip-rationale`) and
mark the test `blocked` with a clear note. **Do not silently skip.**

### 3.7. Failures must be fixed (default policy)

Per the Ultrathink Root Cause directive, every failure becomes a fix-loop
target. If the run completes with `failed` step_executions remaining (i.e.
fix budget exhausted on some tests), autopilot's completion step prints a
hint to run `/e2e-test-specialist:fix-failures` to revisit them with a
fresh evidence cycle. Production bugs surfaced by E2E are first-class work
— they don't get filed-and-forgotten.

### 4. The autonomous loop

Repeat until the run reaches a terminal state.

```text
loop:
    1. Invoke /e2e-test-specialist:test --batch 9999
       (executes pending steps sequentially with checkpoints; pauses on
        critical failure; returns when queue empty OR session paused)

    2. Read run + session state:
         RUN_STATUS    = SELECT status FROM test_runs WHERE id = ACTIVE_RUN
         SESS_STATUS   = SELECT status FROM sessions  WHERE id = active_session
         PENDING_COUNT = SELECT COUNT(*) pending steps in this run

    3. Branch:
         a. RUN_STATUS == 'completed'           → exit loop, go to step 5
         b. PENDING_COUNT == 0                  → mark run completed, exit loop
         c. SESS_STATUS == 'paused' (failure)   → enter fix-loop (4a)
         d. anything else (crash, broken sess)  → /resume and continue loop

    4a. Fix-loop for the paused step:
         - Identify the failing test_id and the failing step_id.
         - FIX_ATTEMPTS = COUNT(*) FROM step_executions
                          WHERE test_id = X AND status='failed'
         - If FIX_ATTEMPTS >= MAX_FIX_ATTEMPTS:
              → mark test as blocked (UPDATE tests SET status='blocked')
              → write a memory (kind='bug-followup', importance=5) explaining
                 the budget exhaustion and the last error
              → write a bug row if none exists yet for this test+run
              → /resume (queue advances past this test)
              → continue main loop
         - Otherwise, execute the Ultrathink Root Cause loop EXACTLY as
           defined in agents/e2e-test-agent.md and commands/test.md step 7:
              i.   Capture evidence (artifacts, console, network, DB state)
              ii.  Form a hypothesis about the root cause
              iii. Verify the hypothesis against source code / DB / logs
              iv.  Apply the smallest correct fix in the project source
              v.   Add a regression test or assertion proving the fix
              vi.  Redeploy / restart the affected service if needed
              vii. /e2e-test-specialist:resume to re-run from the failed step
         - On a passing re-run → continue main loop.
         - On another failure → loop back to 4a (FIX_ATTEMPTS will increment).

    5. Wall-time guard (checked between every iteration):
         - If MAX_WALL_HOURS > 0 and (now - AUTOPILOT_STARTED_AT) >= MAX_WALL_HOURS*3600:
              → leave the run in 'in-progress', mark the session 'paused' with
                reason='wall-time-exceeded', exit loop with a clear log entry.
              → A subsequent /e2e-test-specialist:resume picks up where we left off.
```

The agent executes this loop directly — it is not a bash function. Every
iteration MUST re-read DB state (do not cache between iterations); the DB
is the source of truth.

### 5. Completion

When the loop exits with `RUN_STATUS = 'completed'`:

```bash
# v_run_progress is defined in schema.sql.
sqlite3 -bail -column -header "$E2E_DB" "
  SELECT run_id,
         steps_passed, steps_failed, steps_blocked, steps_skipped,
         tests_total, tests_passed, tests_failed, tests_blocked,
         duration_minutes
    FROM v_run_progress
   WHERE run_id = $(e2e_sql_quote "$ACTIVE_RUN");
"

# Capture a memory of the run's outcome (autopilot-summary kind).
e2e_exec "
  INSERT INTO memories (id, kind, title, body, importance, tags, created_at)
  VALUES ('M-autopilot-' || strftime('%s','now'),
          'environment',
          'Autopilot run $ACTIVE_RUN summary',
          (SELECT printf('passed=%d failed=%d blocked=%d skipped=%d duration=%dmin',
                         steps_passed, steps_failed, steps_blocked, steps_skipped,
                         duration_minutes)
             FROM v_run_progress WHERE run_id = $(e2e_sql_quote "$ACTIVE_RUN")),
          3,
          json_array('autopilot','run-summary'),
          datetime('now'));
"
```

### 5.5. Post-run lifecycle hooks

After the summary is written, read every active `post-run` hook from
`lifecycle_hooks` (in `order_idx` ascending) and follow its `body`. These
hooks encode project-specific cleanup/handoff (snapshot DB, push report,
notify Slack, archive screenshots, restore baseline state, etc.).

```bash
HOOKS="$(e2e_query "
  SELECT id, title, body, enforcement
    FROM lifecycle_hooks
   WHERE phase='post-run' AND active=1
   ORDER BY order_idx ASC, id ASC;
")"
```

Same execution semantics as pre-run hooks (step 3.5): blocking failures
abort with a memory; advisory failures log + memory and continue. Post-run
hooks run AFTER the run is marked `completed`, so they cannot affect the
run's status — they are purely for side effects on external systems.

If `lifecycle_hooks` returns zero rows, this step is a silent no-op.

Then print the standard suggestions, including a re-attempt hint when
failures remain:

```bash
FAILED_COUNT="$(e2e_query_value "
  SELECT COUNT(*) FROM step_executions
   WHERE run_id = $(e2e_sql_quote "$ACTIVE_RUN") AND status = 'failed';
")"
SKIPPED_COUNT="$(e2e_query_value "
  SELECT COUNT(*) FROM step_executions
   WHERE run_id = $(e2e_sql_quote "$ACTIVE_RUN") AND status = 'skipped';
")"
```

```
Autopilot run $ACTIVE_RUN complete.

Generate full report:    /e2e-test-specialist:report
Triage open bugs:        /e2e-test-specialist:bugs
Capture lessons:         /e2e-test-specialist:memory
Export back to ledger:   /e2e-test-specialist:export

To start the next round:  /e2e-test-specialist:autopilot --label "next round"
```

If `FAILED_COUNT > 0`, also print:

```
$FAILED_COUNT failed step(s) remain. Re-attempt with the ultrathink fix
loop using:
  /e2e-test-specialist:fix-failures
```

If `SKIPPED_COUNT > 0`, also print:

```
$SKIPPED_COUNT skipped step(s). Review skip rationale memories and
consider whether an /authorize entry would have allowed driving live:
  /e2e-test-specialist:authorize --list
  /e2e-test-specialist:failures --status skipped
```

Autopilot does **not** auto-restart. A completed run is a checkpoint. If you
want a fresh round, invoke `/e2e-test-specialist:autopilot` again — the
setup steps will detect the existing DB, skip init/import, and `/start`
will allocate the next R-NNN.

## Stop conditions — TUNABLE

Autopilot's "should I keep going?" answer is encoded in step 4. The defaults
above (MAX_FIX_ATTEMPTS=5, MAX_WALL_HOURS=∞, blocked tests don't halt the
queue) reflect a **forward-progress bias**: the run completes even if some
tests can't be fixed in-flight, leaving evidence in `bugs` + `memories` for
later triage.

Tune via the CLI flags. If you want different *behavior* (not just different
limits) — e.g., halt-the-world on the first assertion failure, or pause for
human review on bugs of a particular kind — edit step 4 of this file. That
is the project-policy contribution point. Three honest knobs you might want:

1. **Hard halt on tagged tests.** "Any failure on a `security` or
   `disaster-recovery` test halts the loop and pages a human." → add a
   pre-check in 4a that consults the test's tags.
2. **Backoff between fix attempts.** "After the 2nd consecutive fix failure
   on the same test, sleep 5 minutes before retrying." → add a sleep guarded
   by FIX_ATTEMPTS in 4a.
3. **Bug deduplication.** "Don't open a new bug if an open bug already
   exists for the same test+root_cause." → guard the bug INSERT with a
   SELECT in 4a.

These are policy decisions, not infrastructure. The defaults assume a
nightly autonomous run that you triage in the morning.

## What autopilot will NOT do

- Will not modify production data without going through the same E2E paths
  the test plan defines.
- Will not skip a failing test silently. Every failure becomes a `bug` row
  and (after budget exhaustion) a memory.
- Will not auto-restart a completed run. The next round is one explicit
  invocation away.
- Will not bypass directives. `scripts/directive-check.sh` runs at every
  step, same as the regular `/test` command.
- Will not call `AskUserQuestion` during the loop. The only prompts come
  from genuinely unrecoverable structural problems in step 0–2 (missing
  base-url, missing ledger on empty DB, db unwritable).

## Crash safety

Autopilot inherits all of `/test`'s crash-safety guarantees because it
delegates to it. If autopilot itself dies (terminal closed, machine
rebooted), re-invoking `/e2e-test-specialist:autopilot` with the same args
will:
- Detect the existing DB → skip init.
- Detect non-zero phases → skip import.
- Detect `in-progress` run → resume it via `/test`.
- Pick up at the last checkpointed step.

No flags or env vars carry over between invocations except what's stored in
the DB. The DB IS the autopilot's memory.

## Managing lifecycle hooks

Pre-run and post-run hooks live in the `lifecycle_hooks` table (schema
v1.3.0+). They are opt-in: an empty table means autopilot skips steps 3.5
and 5.5 silently.

**Insert a hook directly via SQL:**

```sql
-- Pre-run: verify the VPS is in a clean slate before starting any test.
INSERT INTO lifecycle_hooks (id, phase, title, body, enforcement, order_idx)
VALUES (
  'lh-pre-clean-slate',
  'pre-run',
  'Verify VPS clean slate (Phase 0)',
  'SSH to wopr.test and run `panel-status --json`. If any sites or droplets
   exist from a prior run, abort: the operator must run Phase 0 manually.
   Reason: tests assume a virgin VPS — partial state poisons later phases.',
  'blocking',
  10
);

-- Post-run: snapshot the DB for nightly comparison.
INSERT INTO lifecycle_hooks (id, phase, title, body, enforcement, order_idx)
VALUES (
  'lh-post-snapshot',
  'post-run',
  'Snapshot DB to _backups/post-run-<timestamp>.sqlite',
  'Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/backup-db.sh post-run`. The
   backup feeds the nightly diff report.',
  'advisory',
  10
);
```

**List active hooks:**

```sql
SELECT id, phase, title, enforcement, order_idx
  FROM lifecycle_hooks
 WHERE active=1
 ORDER BY phase, order_idx;
```

**Disable a hook without deleting:**

```sql
UPDATE lifecycle_hooks SET active=0, updated_at=datetime('now') WHERE id='lh-pre-clean-slate';
```

The `body` is free-form markdown — write it as if briefing a teammate who
has full repo access. The agent reads the body and executes it as part of
the autopilot run.
