-- e2e-test-specialist schema v1.4.0
-- WAL + foreign keys are required for crash-safe checkpoints.

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- ============================================================================
-- Schema versioning
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_version (
    version    TEXT PRIMARY KEY,
    applied_at TEXT DEFAULT (datetime('now'))
);
INSERT OR IGNORE INTO schema_version (version) VALUES ('1.4.0');

-- ============================================================================
-- Directives — non-negotiable rules harvested from the source ledger
-- ============================================================================

CREATE TABLE IF NOT EXISTS directives (
    id          TEXT PRIMARY KEY,
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    category    TEXT,                       -- file-rules, safety, ux-standard, ops, etc.
    enforcement TEXT NOT NULL DEFAULT 'warning'
        CHECK (enforcement IN ('blocking','warning','advisory')),
    active      INTEGER NOT NULL DEFAULT 1,
    source      TEXT,                       -- file path, section heading, or 'user'
    created_at  TEXT DEFAULT (datetime('now')),
    updated_at  TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_directives_active ON directives(active, enforcement);

-- ============================================================================
-- Lifecycle hooks — instructions the autopilot reads & follows at run boundaries
--   phase = 'pre-run'  → executed before the first test of an autopilot run
--   phase = 'post-run' → executed after the run reaches a terminal status
-- Multiple hooks per phase are allowed; ordered by order_idx ascending.
-- enforcement: 'blocking' aborts the run if the hook fails; 'advisory' logs only.
-- ============================================================================

CREATE TABLE IF NOT EXISTS lifecycle_hooks (
    id           TEXT PRIMARY KEY,
    phase        TEXT NOT NULL CHECK (phase IN ('pre-run','post-run')),
    title        TEXT NOT NULL,
    body         TEXT NOT NULL,
    enforcement  TEXT NOT NULL DEFAULT 'advisory'
                 CHECK (enforcement IN ('blocking','advisory')),
    active       INTEGER NOT NULL DEFAULT 1,
    order_idx    INTEGER NOT NULL DEFAULT 100,
    source       TEXT,
    created_at   TEXT DEFAULT (datetime('now')),
    updated_at   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_lifecycle_hooks_active
    ON lifecycle_hooks(phase, active, order_idx);

-- ============================================================================
-- Test coverage links (v1.4.0) — cross-run-coverage citations
--   "Test T-04.03 is covered by T-15.07 across runs" — let the autopilot's
--   skip discipline honor cross-run coverage as a first-class signal instead
--   of free-text memory. valid_until_run NULL means "until explicitly revoked".
-- ============================================================================

CREATE TABLE IF NOT EXISTS test_coverage_links (
    id                TEXT PRIMARY KEY,
    covered_test_id   TEXT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    covering_test_id  TEXT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    rationale         TEXT,
    declared_in_run   TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    valid_from_run    TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    valid_until_run   TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    active            INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    created_at        TEXT DEFAULT (datetime('now')),
    updated_at        TEXT DEFAULT (datetime('now')),
    UNIQUE (covered_test_id, covering_test_id)
);

CREATE INDEX IF NOT EXISTS idx_coverage_links_covered
    ON test_coverage_links(covered_test_id, active);
CREATE INDEX IF NOT EXISTS idx_coverage_links_covering
    ON test_coverage_links(covering_test_id, active);

-- ============================================================================
-- Notifications (v1.4.0) — outbound dispatch queue
--   Filled by autopilot at notable events (run done, blocking hook failed,
--   critical-tag failure, wall-time hit, cascade detected). Drained by
--   scripts/notify.sh which fires webhooks / OS notifications / file writes
--   per the user's config. status='pending' rows are unsent.
-- ============================================================================

CREATE TABLE IF NOT EXISTS notifications (
    id           TEXT PRIMARY KEY,
    kind         TEXT NOT NULL CHECK (kind IN (
        'run-completed','run-failed','hook-blocking-failed',
        'critical-failure','wall-time-hit','cascade-detected',
        'kill-switch-triggered','manual'
    )),
    severity     TEXT NOT NULL DEFAULT 'info'
                 CHECK (severity IN ('info','warning','critical')),
    title        TEXT NOT NULL,
    body         TEXT,
    related_run  TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    related_test TEXT REFERENCES tests(id) ON DELETE SET NULL,
    related_bug  TEXT REFERENCES bugs(id) ON DELETE SET NULL,
    status       TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','sent','failed','suppressed')),
    sent_at      TEXT,
    target       TEXT,                                  -- webhook url / file path / channel name
    created_at   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_notifications_status
    ON notifications(status, severity, created_at);

-- ============================================================================
-- Resource ledger (v1.4.0) — autopilot-driven cost / resource accounting
--   When the autopilot provisions Forge servers / DO droplets / etc. under a
--   standing authorization, it logs each create/destroy here. /cost rolls up.
-- ============================================================================

CREATE TABLE IF NOT EXISTS resource_ledger (
    id           TEXT PRIMARY KEY,
    run_id       TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    provider     TEXT NOT NULL,                       -- 'do', 'forge', 'aws', etc.
    resource_id  TEXT NOT NULL,                       -- provider-side id
    resource_kind TEXT NOT NULL,                      -- 'droplet', 'server', 'lb', etc.
    label        TEXT,                                -- 'pfdo-r36-app1'
    action       TEXT NOT NULL CHECK (action IN ('created','destroyed','tagged','noted')),
    estimated_cost_cents INTEGER,                     -- NULL if unknown
    metadata     TEXT NOT NULL DEFAULT '{}',          -- JSON: size, region, hourly rate
    created_at   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_resource_run ON resource_ledger(run_id, action);
CREATE INDEX IF NOT EXISTS idx_resource_lookup ON resource_ledger(provider, resource_id, action);

-- ============================================================================
-- Credentials — sensitive data (gitignored DB, never logged in plaintext)
-- ============================================================================

CREATE TABLE IF NOT EXISTS credentials (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL UNIQUE,
    kind         TEXT NOT NULL
        CHECK (kind IN ('ssh','api-token','pat','composer','username-password','env-var','other')),
    fields       TEXT NOT NULL DEFAULT '{}', -- JSON
    expires_at   TEXT,
    notes        TEXT,
    last_used_at TEXT,
    created_at   TEXT DEFAULT (datetime('now')),
    updated_at   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_credentials_kind ON credentials(kind);

-- ============================================================================
-- Roles (v1.2.0) — first-class user identities for role-based testing
-- ============================================================================

CREATE TABLE IF NOT EXISTS roles (
    id            TEXT PRIMARY KEY,                -- 'ROLE-admin','ROLE-tenant'
    name          TEXT NOT NULL UNIQUE,
    permissions   TEXT NOT NULL DEFAULT '[]',      -- JSON array of permission slugs
    credential_id TEXT REFERENCES credentials(id) ON DELETE SET NULL,  -- login creds
    panel         TEXT,                             -- which UI panel this role accesses
    notes         TEXT,
    created_at    TEXT DEFAULT (datetime('now')),
    updated_at    TEXT DEFAULT (datetime('now'))
);

-- ============================================================================
-- Integrations (v1.2.0) — external systems (Forge, Linear, GitHub Actions, etc.)
-- ============================================================================

CREATE TABLE IF NOT EXISTS integrations (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    kind            TEXT NOT NULL,                  -- 'forge','linear','slack','github-actions',...
    base_url        TEXT,
    credential_id   TEXT REFERENCES credentials(id) ON DELETE SET NULL,
    last_synced_at  TEXT,
    last_error      TEXT,
    metadata        TEXT NOT NULL DEFAULT '{}',
    created_at      TEXT DEFAULT (datetime('now')),
    updated_at      TEXT DEFAULT (datetime('now'))
);

-- ============================================================================
-- Infrastructure — servers, droplets, load balancers, dev machines
-- ============================================================================

CREATE TABLE IF NOT EXISTS infrastructure (
    id               TEXT PRIMARY KEY,
    name             TEXT NOT NULL UNIQUE,
    kind             TEXT NOT NULL
        CHECK (kind IN ('control-plane','app-server','all-in-one','load-balancer','do-droplet','custom','dev-machine','panel','worker','other')),
    ip               TEXT,
    ssh_port         INTEGER DEFAULT 22,
    wildcard_domain  TEXT,
    wireguard_ip     TEXT,
    region           TEXT,
    size             TEXT,
    credential_id    TEXT REFERENCES credentials(id) ON DELETE SET NULL,
    metadata         TEXT NOT NULL DEFAULT '{}',  -- JSON: deploy_dir, panel_url, db_creds, etc.
    created_at       TEXT DEFAULT (datetime('now')),
    updated_at       TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_infrastructure_kind ON infrastructure(kind);

-- ============================================================================
-- Apps — test subjects (Test App Matrix from the ledger)
-- ============================================================================

CREATE TABLE IF NOT EXISTS apps (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    app_type        TEXT,                   -- laravel, php-classic, express, nextjs, static
    description     TEXT,
    repo_url        TEXT,
    is_private      INTEGER NOT NULL DEFAULT 0,
    services        TEXT NOT NULL DEFAULT '{}',  -- JSON: {db:'pg', redis:true, horizon:true, reverb:true, scheduler:false, s3:true}
    target_infra_id TEXT REFERENCES infrastructure(id) ON DELETE SET NULL,  -- v1.0 default deployment (deprecated; use sites)
    target_domain   TEXT,                                                    -- v1.0 default domain (deprecated; use sites)
    metadata        TEXT NOT NULL DEFAULT '{}',
    created_at      TEXT DEFAULT (datetime('now')),
    updated_at      TEXT DEFAULT (datetime('now'))
);

-- ============================================================================
-- Sites (v1.2.0) — deployed instances of apps on infrastructure
--   Same app may be deployed to multiple infras (e.g., todo on Worker 1 AND
--   todo on do-sydney). Each is a distinct site with its own domain + service
--   overrides. Tests parametrize over SITE-NNN ids when they target a specific
--   deployment.
-- ============================================================================

CREATE TABLE IF NOT EXISTS sites (
    id                TEXT PRIMARY KEY,                              -- 'SITE-001'
    app_id            TEXT NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    infra_id          TEXT NOT NULL REFERENCES infrastructure(id) ON DELETE CASCADE,
    domain            TEXT NOT NULL,
    services_override TEXT NOT NULL DEFAULT '{}',   -- merges over apps.services
    status            TEXT NOT NULL DEFAULT 'planned'
        CHECK (status IN ('planned','provisioning','live','degraded','decommissioned')),
    deployed_at       TEXT,
    metadata          TEXT NOT NULL DEFAULT '{}',
    created_at        TEXT DEFAULT (datetime('now')),
    updated_at        TEXT DEFAULT (datetime('now')),
    UNIQUE (app_id, infra_id)
);

CREATE INDEX IF NOT EXISTS idx_sites_status ON sites(status);
CREATE INDEX IF NOT EXISTS idx_sites_app ON sites(app_id);
CREATE INDEX IF NOT EXISTS idx_sites_infra ON sites(infra_id);

-- ============================================================================
-- Phases — top-level groupings of tests (P00..PNN)
-- ============================================================================

CREATE TABLE IF NOT EXISTS phases (
    id                   TEXT PRIMARY KEY,           -- 'P00','P01',...
    title                TEXT NOT NULL,
    description          TEXT,
    phase_order          INTEGER NOT NULL,
    expected_test_count  INTEGER,
    raw_markdown         TEXT,                       -- preserved for re-parse / agent inspection
    created_at           TEXT DEFAULT (datetime('now')),
    updated_at           TEXT DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_phases_order ON phases(phase_order);

-- ============================================================================
-- Tests — individual scenarios (T-{phase}.{seq})
-- ============================================================================

CREATE TABLE IF NOT EXISTS tests (
    id                          TEXT PRIMARY KEY,
    phase_id                    TEXT NOT NULL REFERENCES phases(id) ON DELETE CASCADE,
    title                       TEXT NOT NULL,
    description                 TEXT,
    actor                       TEXT,                 -- 'U1 (Super Admin)' / 'operator' / 'agent'
    preconditions               TEXT,
    postconditions              TEXT,
    test_kind                   TEXT
        CHECK (test_kind IN ('browser','ssh','api','cli','mixed','manual','observation','stress','disaster-recovery')),
    estimated_duration_seconds  INTEGER,
    test_order                  INTEGER NOT NULL,
    is_critical                 INTEGER NOT NULL DEFAULT 1,
    deprecated_at               TEXT,                 -- soft delete (honors append-only directive)
    deprecated_reason           TEXT,
    raw_markdown                TEXT,
    -- v1.1.0: parametrization. JSON array of subject identifiers — empty = single execution.
    -- Each ID is opaque; resolution maps to apps/infrastructure rows or to inline objects.
    -- Example: ["APP-001","APP-002","APP-003"] — same procedure runs once per app.
    applies_to                  TEXT NOT NULL DEFAULT '[]',
    created_at                  TEXT DEFAULT (datetime('now')),
    updated_at                  TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_tests_phase ON tests(phase_id, test_order);
CREATE INDEX IF NOT EXISTS idx_tests_active ON tests(deprecated_at);
CREATE INDEX IF NOT EXISTS idx_tests_kind ON tests(test_kind);

-- ============================================================================
-- Test steps — individual actions within a test
-- ============================================================================

CREATE TABLE IF NOT EXISTS test_steps (
    id                TEXT PRIMARY KEY,
    test_id           TEXT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    step_order        INTEGER NOT NULL,
    action            TEXT NOT NULL,                       -- imperative ("Navigate to /admin/login")
    expected          TEXT,                                -- observable outcome
    is_critical       INTEGER NOT NULL DEFAULT 1,          -- failure aborts test if 1
    notes             TEXT,
    -- v1.1.0: parametrization templates. When the parent test has applies_to non-empty,
    -- the executor renders these per subject using {{subject.field.path}} placeholders.
    -- If templates are NULL, the action/expected are used verbatim for every subject.
    action_template   TEXT,
    expected_template TEXT,
    -- v1.4.0: idempotency declaration. 1 = re-running yields the same result (default,
    -- safe assumption for read-only checks). 0 = mutates state — fix-loop should rebuild
    -- preceding setup steps before retry, or surface "manual cleanup needed" first.
    idempotent        INTEGER NOT NULL DEFAULT 1 CHECK (idempotent IN (0,1)),
    created_at        TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_steps_test ON test_steps(test_id, step_order);

-- ============================================================================
-- Step assertions (v1.2.0) — multi-assertion support
--   A step may have multiple structured assertions (visible / console-clean /
--   network-ok / status-code / text-match). Each assertion has its own pass/fail.
--   The legacy test_steps.expected text remains as a free-form catch-all for
--   tests imported before assertions were structured.
-- ============================================================================

CREATE TABLE IF NOT EXISTS step_assertions (
    id              TEXT PRIMARY KEY,
    step_id         TEXT NOT NULL REFERENCES test_steps(id) ON DELETE CASCADE,
    kind            TEXT NOT NULL CHECK (kind IN (
        'visible','hidden','text-match','text-not-match',
        'status-code','console-clean','console-error',
        'network-ok','network-error','element-count',
        'value-equals','value-contains','custom'
    )),
    selector        TEXT,                            -- CSS / XPath / endpoint / regex
    expected_value  TEXT,
    is_critical     INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_assertions_step ON step_assertions(step_id);

CREATE TABLE IF NOT EXISTS assertion_results (
    execution_id    TEXT NOT NULL REFERENCES step_executions(id) ON DELETE CASCADE,
    assertion_id    TEXT NOT NULL REFERENCES step_assertions(id) ON DELETE CASCADE,
    passed          INTEGER NOT NULL,
    actual_value    TEXT,
    error_message   TEXT,
    captured_at     TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (execution_id, assertion_id)
);

CREATE INDEX IF NOT EXISTS idx_assertion_results_pass ON assertion_results(passed);

-- ============================================================================
-- Test dependencies (v1.2.0) — express ordering constraints
--   hard: depends_on must have passed in the active run before this test runs
--   soft: warning if depends_on hasn't passed; not blocking
--   informational: agent should consider context; no policy effect
-- ============================================================================

CREATE TABLE IF NOT EXISTS test_dependencies (
    test_id         TEXT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    depends_on      TEXT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    kind            TEXT NOT NULL DEFAULT 'soft'
        CHECK (kind IN ('hard','soft','informational')),
    notes           TEXT,
    PRIMARY KEY (test_id, depends_on)
);

-- ============================================================================
-- Coverage targets (v1.2.0) — what surface needs to be exercised
--   Populated from "Section 0: Navigation Coverage Audit" or manually via
--   /plan add-coverage-target. coverage_hits records when a step exercised one.
-- ============================================================================

CREATE TABLE IF NOT EXISTS coverage_targets (
    id          TEXT PRIMARY KEY,
    kind        TEXT NOT NULL CHECK (kind IN ('menu-item','action','link','route','feature','custom')),
    label       TEXT NOT NULL,
    url_path    TEXT,
    visible_to  TEXT NOT NULL DEFAULT '[]',   -- JSON: role IDs that should access
    notes       TEXT,
    created_at  TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_coverage_targets_kind ON coverage_targets(kind);

CREATE TABLE IF NOT EXISTS coverage_hits (
    target_id     TEXT NOT NULL REFERENCES coverage_targets(id) ON DELETE CASCADE,
    execution_id  TEXT NOT NULL REFERENCES step_executions(id) ON DELETE CASCADE,
    captured_at   TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (target_id, execution_id)
);

-- ============================================================================
-- Directive violations (v1.2.0) — audit log when actions are blocked/warned
-- ============================================================================

CREATE TABLE IF NOT EXISTS directive_violations (
    id             TEXT PRIMARY KEY,
    run_id         TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    execution_id   TEXT REFERENCES step_executions(id) ON DELETE SET NULL,
    directive_id   TEXT REFERENCES directives(id) ON DELETE SET NULL,
    enforcement    TEXT NOT NULL CHECK (enforcement IN ('blocking','warning','advisory')),
    action_kind    TEXT NOT NULL,
    description    TEXT NOT NULL,
    user_decision  TEXT,                             -- 'aborted','overridden','continued'
    created_at     TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_violations_run ON directive_violations(run_id, created_at);

-- ============================================================================
-- Tags (normalized)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tags (
    name        TEXT PRIMARY KEY,
    description TEXT,
    color       TEXT,
    auto        INTEGER NOT NULL DEFAULT 0,           -- 1 if generated by importer's taxonomy
    created_at  TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS test_tags (
    test_id   TEXT NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    tag_name  TEXT NOT NULL REFERENCES tags(name) ON DELETE CASCADE,
    PRIMARY KEY (test_id, tag_name)
);

CREATE INDEX IF NOT EXISTS idx_test_tags_tag ON test_tags(tag_name);

-- ============================================================================
-- Test runs — a "round" (R-001, R-032, etc.)
-- ============================================================================

CREATE TABLE IF NOT EXISTS test_runs (
    id              TEXT PRIMARY KEY,
    label           TEXT,
    base_url        TEXT,
    started_at      TEXT DEFAULT (datetime('now')),
    ended_at        TEXT,
    status          TEXT NOT NULL DEFAULT 'in-progress'
        CHECK (status IN ('planned','in-progress','paused','completed','aborted')),  -- v1.2: + planned
    target_phases   TEXT NOT NULL DEFAULT '[]',     -- JSON [] = all
    target_tags     TEXT NOT NULL DEFAULT '[]',     -- JSON [] = unrestricted
    skip_tags       TEXT NOT NULL DEFAULT '[]',     -- JSON
    context         TEXT,                            -- markdown summary at start
    final_state     TEXT,                            -- markdown summary at end
    metrics         TEXT NOT NULL DEFAULT '{}',     -- JSON: counts, durations, coverage
    created_at      TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_runs_status ON test_runs(status, started_at);

-- ============================================================================
-- Step executions — checkpoint records (one per step × run × retry)
-- ============================================================================

CREATE TABLE IF NOT EXISTS step_executions (
    id                   TEXT PRIMARY KEY,
    run_id               TEXT NOT NULL REFERENCES test_runs(id) ON DELETE CASCADE,
    test_id              TEXT NOT NULL REFERENCES tests(id),
    step_id              TEXT NOT NULL REFERENCES test_steps(id),
    -- v1.1.0: which subject this execution targeted. NULL when the test has no applies_to.
    subject_id           TEXT,
    retry_attempt        INTEGER NOT NULL DEFAULT 0,
    status               TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','in-progress','passed','failed','skipped','blocked')),
    started_at           TEXT,
    completed_at         TEXT,
    duration_ms          INTEGER,
    actual_result        TEXT,
    error_message        TEXT,
    evidence_snapshot    TEXT,                       -- excerpt of browser_snapshot or SSH output
    bug_id               TEXT REFERENCES bugs(id) ON DELETE SET NULL,  -- v1.2: real FK (was soft)
    metrics              TEXT NOT NULL DEFAULT '{}', -- v1.2: JSON measurements (RPS, latency, count, ...)
    notes                TEXT,
    -- v1.4.0: structured skip rationale for legible aggregation.
    skip_reason          TEXT
        CHECK (skip_reason IS NULL OR skip_reason IN
            ('needs-infra','cross-run-coverage','future-impl','no-authorization',
             'dependency-failed','manual-decision','flake-quarantine')),
    -- v1.4.0: denormalized fix-attempt counter. Maintained by /test and /fix-failures.
    fix_attempt_index    INTEGER NOT NULL DEFAULT 0,
    created_at           TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_exec_run ON step_executions(run_id, status);
CREATE INDEX IF NOT EXISTS idx_exec_step ON step_executions(step_id, run_id);
CREATE INDEX IF NOT EXISTS idx_exec_test ON step_executions(test_id, run_id);
CREATE INDEX IF NOT EXISTS idx_exec_skip ON step_executions(run_id, skip_reason)
    WHERE skip_reason IS NOT NULL;

-- ============================================================================
-- Bugs
-- ============================================================================

CREATE TABLE IF NOT EXISTS bugs (
    id                  TEXT PRIMARY KEY,
    discovered_in_run   TEXT NOT NULL REFERENCES test_runs(id),
    discovered_at       TEXT DEFAULT (datetime('now')),
    severity            TEXT CHECK (severity IN ('critical','high','medium','low')),
    title               TEXT NOT NULL,
    description         TEXT,
    error_message       TEXT,
    root_cause          TEXT,
    fix_applied         TEXT,
    fix_commit_sha      TEXT,
    retested_at         TEXT,
    retest_result       TEXT CHECK (retest_result IN ('fixed','persists','not-retested')),
    status              TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open','fixed','wontfix','duplicate')),
    related_step_id     TEXT REFERENCES test_steps(id) ON DELETE SET NULL,
    tags                TEXT NOT NULL DEFAULT '[]',
    -- v1.4.0: denormalized JSON array of test_ids this bug currently blocks.
    -- Maintained by /test step 7 (root-cause loop) and /fix-failures.
    affected_tests      TEXT NOT NULL DEFAULT '[]',
    created_at          TEXT DEFAULT (datetime('now')),
    updated_at          TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_bugs_status ON bugs(status, severity);
CREATE INDEX IF NOT EXISTS idx_bugs_run ON bugs(discovered_in_run);

-- ============================================================================
-- Screenshots — linked to executions (and runs as fallback)
-- ============================================================================

CREATE TABLE IF NOT EXISTS screenshots (
    id            TEXT PRIMARY KEY,
    execution_id  TEXT REFERENCES step_executions(id) ON DELETE SET NULL,
    run_id        TEXT NOT NULL REFERENCES test_runs(id) ON DELETE CASCADE,
    path          TEXT NOT NULL,
    label         TEXT,
    captured_at   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_screenshots_exec ON screenshots(execution_id);

-- ============================================================================
-- Memories (with FTS5 search)
-- ============================================================================

CREATE TABLE IF NOT EXISTS memories (
    id                TEXT PRIMARY KEY,
    title             TEXT NOT NULL,
    kind              TEXT NOT NULL
        CHECK (kind IN ('decision','workaround','gotcha','convention','environment','lesson-learned','bug-pattern','credential-note','other')),
    body              TEXT NOT NULL,
    why_important     TEXT,
    importance        INTEGER NOT NULL DEFAULT 3 CHECK (importance BETWEEN 1 AND 5),
    related_run_id    TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    related_test_id   TEXT REFERENCES tests(id) ON DELETE SET NULL,
    related_bug_id    TEXT REFERENCES bugs(id) ON DELETE SET NULL,
    tags              TEXT NOT NULL DEFAULT '[]',
    status            TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','superseded','deprecated')),
    use_count         INTEGER NOT NULL DEFAULT 0,
    last_used_at      TEXT,
    created_at        TEXT DEFAULT (datetime('now')),
    updated_at        TEXT DEFAULT (datetime('now'))
);

CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
    title, body, tags, content='memories', content_rowid='rowid'
);

CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
    INSERT INTO memories_fts(rowid, title, body, tags)
    VALUES (NEW.rowid, NEW.title, NEW.body, NEW.tags);
END;

CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, title, body, tags)
    VALUES('delete', OLD.rowid, OLD.title, OLD.body, OLD.tags);
END;

CREATE TRIGGER IF NOT EXISTS memories_au AFTER UPDATE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, title, body, tags)
    VALUES('delete', OLD.rowid, OLD.title, OLD.body, OLD.tags);
    INSERT INTO memories_fts(rowid, title, body, tags)
    VALUES (NEW.rowid, NEW.title, NEW.body, NEW.tags);
END;

-- ============================================================================
-- Sessions — Claude session tracking with heartbeat (crash detection)
-- ============================================================================

CREATE TABLE IF NOT EXISTS sessions (
    id                    TEXT PRIMARY KEY,
    run_id                TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    started_at            TEXT DEFAULT (datetime('now')),
    last_heartbeat        TEXT DEFAULT (datetime('now')),
    ended_at              TEXT,
    status                TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','paused','completed','crashed','aborted')),
    current_test_id       TEXT REFERENCES tests(id) ON DELETE SET NULL,
    current_step_id       TEXT REFERENCES test_steps(id) ON DELETE SET NULL,
    current_execution_id  TEXT REFERENCES step_executions(id) ON DELETE SET NULL,
    process_info          TEXT,                  -- hostname / agent id hint
    notes                 TEXT,
    created_at            TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status, last_heartbeat);

-- ============================================================================
-- State (single-row pointer)
-- ============================================================================

CREATE TABLE IF NOT EXISTS state (
    id                       INTEGER PRIMARY KEY CHECK (id = 1),
    active_session_id        TEXT REFERENCES sessions(id) ON DELETE SET NULL,
    active_run_id            TEXT REFERENCES test_runs(id) ON DELETE SET NULL,
    base_url                 TEXT,
    detected_environment     TEXT NOT NULL DEFAULT '{}',
    last_update              TEXT DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO state (id) VALUES (1);

-- ============================================================================
-- Convenience views
-- ============================================================================

-- Current progress for the active run
CREATE VIEW IF NOT EXISTS v_run_progress AS
SELECT
    r.id            AS run_id,
    r.label         AS label,
    r.status        AS run_status,
    COUNT(DISTINCT e.test_id)                                  AS tests_touched,
    SUM(CASE WHEN e.status = 'passed'  THEN 1 ELSE 0 END)      AS steps_passed,
    SUM(CASE WHEN e.status = 'failed'  THEN 1 ELSE 0 END)      AS steps_failed,
    SUM(CASE WHEN e.status = 'skipped' THEN 1 ELSE 0 END)      AS steps_skipped,
    SUM(CASE WHEN e.status = 'blocked' THEN 1 ELSE 0 END)      AS steps_blocked,
    SUM(CASE WHEN e.status = 'in-progress' THEN 1 ELSE 0 END)  AS steps_in_progress
FROM test_runs r
LEFT JOIN step_executions e ON e.run_id = r.id
GROUP BY r.id;

-- Tests with their tags as a comma-separated list (for quick CLI display)
CREATE VIEW IF NOT EXISTS v_tests_with_tags AS
SELECT
    t.id, t.phase_id, t.title, t.test_kind, t.actor, t.is_critical, t.deprecated_at,
    GROUP_CONCAT(tt.tag_name, ',') AS tags
FROM tests t
LEFT JOIN test_tags tt ON tt.test_id = t.id
GROUP BY t.id;

-- ============================================================================
-- Parametrization (v1.1.0): subject expansion for "for each X" tests
-- ============================================================================

-- Materialized cross-product: every (test, subject) pair the executor must run.
-- For tests with empty applies_to, emits a single row with subject_id = NULL.
-- For tests with applies_to = ["APP-001","APP-002"], emits 2 rows.
CREATE VIEW IF NOT EXISTS v_test_subjects AS
SELECT
    t.id        AS test_id,
    t.phase_id  AS phase_id,
    t.test_order,
    NULL        AS subject_id
FROM tests t
WHERE t.deprecated_at IS NULL
  AND (json_array_length(COALESCE(NULLIF(t.applies_to, ''), '[]')) = 0)
UNION ALL
SELECT
    t.id        AS test_id,
    t.phase_id  AS phase_id,
    t.test_order,
    j.value     AS subject_id
FROM tests t, json_each(t.applies_to) j
WHERE t.deprecated_at IS NULL
  AND json_array_length(t.applies_to) > 0;

-- Resolved subject context (looks up by ID prefix into the right table).
-- Returns one row per known subject ID with `fields` JSON ready for templating.
CREATE VIEW IF NOT EXISTS v_subjects_resolved AS
  SELECT
    a.id                                        AS id,
    'app'                                       AS kind,
    a.name                                      AS name,
    json_object(
      'id',            a.id,
      'name',          a.name,
      'app_type',      a.app_type,
      'target_domain', a.target_domain,
      'services',      json(a.services),
      'metadata',      json(a.metadata)
    )                                           AS fields
    FROM apps a
UNION ALL
  SELECT
    i.id, 'infrastructure', i.name,
    json_object(
      'id',              i.id,
      'name',            i.name,
      'kind',            i.kind,
      'ip',              i.ip,
      'ssh_port',        i.ssh_port,
      'wildcard_domain', i.wildcard_domain,
      'wireguard_ip',    i.wireguard_ip,
      'metadata',        json(i.metadata)
    )
    FROM infrastructure i
UNION ALL
  SELECT
    s.id, 'site', s.domain,
    json_object(
      'id',                s.id,
      'name',              s.domain,
      'domain',            s.domain,
      'app_id',            s.app_id,
      'infra_id',          s.infra_id,
      'status',            s.status,
      'services_override', json(s.services_override),
      'metadata',          json(s.metadata)
    )
    FROM sites s
UNION ALL
  SELECT
    r.id, 'role', r.name,
    json_object(
      'id',          r.id,
      'name',        r.name,
      'permissions', json(r.permissions),
      'panel',       r.panel
    )
    FROM roles r;

-- ============================================================================
-- v1.2 views: per-subject results, flaky steps, coverage report
-- ============================================================================

-- Roll up per-subject status for the active run.
CREATE VIEW IF NOT EXISTS v_test_results_by_subject AS
SELECT
    e.run_id,
    e.test_id,
    COALESCE(e.subject_id, '_none_')                                           AS subject_id,
    SUM(CASE WHEN e.status = 'passed'      THEN 1 ELSE 0 END)                  AS steps_passed,
    SUM(CASE WHEN e.status = 'failed'      THEN 1 ELSE 0 END)                  AS steps_failed,
    SUM(CASE WHEN e.status = 'skipped'     THEN 1 ELSE 0 END)                  AS steps_skipped,
    SUM(CASE WHEN e.status = 'blocked'     THEN 1 ELSE 0 END)                  AS steps_blocked,
    SUM(CASE WHEN e.status = 'in-progress' THEN 1 ELSE 0 END)                  AS steps_in_progress,
    MIN(e.started_at)                                                           AS started_at,
    MAX(e.completed_at)                                                         AS completed_at
FROM step_executions e
GROUP BY e.run_id, e.test_id, COALESCE(e.subject_id, '_none_');

-- A step is "flaky" if it has at least one passed result and at least one
-- failed result across all runs (regardless of retries).
CREATE VIEW IF NOT EXISTS v_flaky_steps AS
SELECT
    e.step_id,
    e.test_id,
    SUM(CASE WHEN e.status = 'passed' THEN 1 ELSE 0 END) AS pass_count,
    SUM(CASE WHEN e.status = 'failed' THEN 1 ELSE 0 END) AS fail_count,
    COUNT(DISTINCT e.run_id)                              AS run_count,
    MAX(e.completed_at)                                   AS last_seen
FROM step_executions e
GROUP BY e.step_id, e.test_id
HAVING pass_count > 0 AND fail_count > 0;

-- Coverage summary: target → first hit time, hit count, hitting tests
CREATE VIEW IF NOT EXISTS v_coverage AS
SELECT
    ct.id,
    ct.kind,
    ct.label,
    ct.url_path,
    COUNT(ch.execution_id)                       AS hit_count,
    MIN(ch.captured_at)                          AS first_hit_at,
    MAX(ch.captured_at)                          AS last_hit_at,
    GROUP_CONCAT(DISTINCT e.test_id)             AS hitting_tests
FROM coverage_targets ct
LEFT JOIN coverage_hits ch     ON ch.target_id = ct.id
LEFT JOIN step_executions e    ON e.id = ch.execution_id
GROUP BY ct.id;

-- v1.4.0 — skip rationale rollup: count distinct skipped tests per run, per reason.
-- Lets /skipped --explain answer "record what /authorize to recover N tests".
CREATE VIEW IF NOT EXISTS v_skip_rollup AS
SELECT
    e.run_id,
    COALESCE(e.skip_reason, 'unspecified') AS skip_reason,
    COUNT(DISTINCT e.test_id)              AS test_count,
    COUNT(*)                                AS step_count,
    GROUP_CONCAT(DISTINCT e.test_id)        AS test_ids
FROM step_executions e
WHERE e.status = 'skipped'
GROUP BY e.run_id, COALESCE(e.skip_reason, 'unspecified');

-- v1.4.0 — latest-status-per-step view, used by /diff and dependency enforcement.
-- For each (run, step) pair, returns the most-recent execution row.
CREATE VIEW IF NOT EXISTS v_latest_step_status AS
SELECT run_id, step_id, test_id, status, error_message, completed_at, started_at,
       skip_reason, fix_attempt_index, retry_attempt
FROM step_executions
WHERE id IN (
    SELECT id FROM step_executions
    GROUP BY run_id, step_id
    HAVING MAX(created_at)
);

-- v1.4.0 — latest-status-per-test view, used by /diff to compare runs at the test level.
CREATE VIEW IF NOT EXISTS v_latest_test_status AS
SELECT
    run_id,
    test_id,
    CASE
        WHEN SUM(CASE WHEN status='failed' THEN 1 ELSE 0 END)  > 0 THEN 'failed'
        WHEN SUM(CASE WHEN status='blocked' THEN 1 ELSE 0 END) > 0 THEN 'blocked'
        WHEN SUM(CASE WHEN status='skipped' THEN 1 ELSE 0 END) > 0
             AND SUM(CASE WHEN status='passed' THEN 1 ELSE 0 END) = 0 THEN 'skipped'
        WHEN SUM(CASE WHEN status='in-progress' THEN 1 ELSE 0 END) > 0 THEN 'in-progress'
        WHEN SUM(CASE WHEN status='passed' THEN 1 ELSE 0 END) > 0 THEN 'passed'
        ELSE 'pending'
    END AS test_status,
    COUNT(*) AS execution_count
FROM v_latest_step_status
GROUP BY run_id, test_id;

-- ============================================================================
-- v1.2 triggers: protect data integrity that CHECK constraints can't express
-- ============================================================================

-- Enforce: every ID in tests.applies_to must resolve to a known subject.
-- Triggered on insert/update of tests.applies_to.
CREATE TRIGGER IF NOT EXISTS trg_tests_applies_to_validate_insert
AFTER INSERT ON tests
WHEN json_array_length(NEW.applies_to) > 0
BEGIN
    SELECT CASE WHEN EXISTS(
        SELECT 1 FROM json_each(NEW.applies_to) j
        WHERE j.value NOT IN (SELECT id FROM v_subjects_resolved)
          AND j.value NOT LIKE 'VP-%'    -- viewports synthesized from config
    ) THEN RAISE(ABORT, 'tests.applies_to references unknown subject id') END;
END;

CREATE TRIGGER IF NOT EXISTS trg_tests_applies_to_validate_update
AFTER UPDATE OF applies_to ON tests
WHEN json_array_length(NEW.applies_to) > 0
BEGIN
    SELECT CASE WHEN EXISTS(
        SELECT 1 FROM json_each(NEW.applies_to) j
        WHERE j.value NOT IN (SELECT id FROM v_subjects_resolved)
          AND j.value NOT LIKE 'VP-%'
    ) THEN RAISE(ABORT, 'tests.applies_to references unknown subject id') END;
END;
