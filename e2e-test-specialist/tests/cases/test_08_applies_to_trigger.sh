#!/usr/bin/env bash
# Verify the applies_to integrity trigger blocks invalid JSON / unknown subjects.
set -euo pipefail

bash "$CLAUDE_PLUGIN_ROOT/scripts/init-db.sh" >/dev/null
source "$CLAUDE_PLUGIN_ROOT/scripts/lib.sh"

# Seed phase + apps + roles so the references are valid subjects.
sqlite3 "$E2E_DB" "
    INSERT INTO phases (id, title, phase_order) VALUES ('P00','p0',0);
    INSERT INTO apps (id, name) VALUES ('APP-001', 'todo'), ('APP-002', 'note');
    INSERT INTO roles (id, name) VALUES ('ROLE-admin', 'admin');
"

# Valid: applies_to references existing subjects.
sqlite3 "$E2E_DB" "
    INSERT INTO tests (id, phase_id, title, test_order, applies_to)
    VALUES ('T-00.01','P00','t', 1, '[\"APP-001\",\"APP-002\"]');
" || { echo "valid applies_to was rejected"; exit 1; }

# Mix of seeded role and synthetic VP-* (only VP- is allowed without a row).
sqlite3 "$E2E_DB" "
    INSERT INTO tests (id, phase_id, title, test_order, applies_to)
    VALUES ('T-00.02','P00','t2', 2, '[\"ROLE-admin\",\"VP-mobile\"]');
" || { echo "seeded role + synthetic VP rejected"; exit 1; }

# Invalid: malformed JSON should be rejected by the trigger.
if sqlite3 "$E2E_DB" "
    INSERT INTO tests (id, phase_id, title, test_order, applies_to)
    VALUES ('T-00.03','P00','bad', 3, 'this is not json');
" 2>/dev/null; then
    echo "malformed JSON was accepted (expected rejection)"
    exit 1
fi

# Invalid: an APP-NNN id that doesn't exist
if sqlite3 "$E2E_DB" "
    INSERT INTO tests (id, phase_id, title, test_order, applies_to)
    VALUES ('T-00.04','P00','bad2', 4, '[\"APP-999\"]');
" 2>/dev/null; then
    echo "unknown APP-id was accepted (expected rejection)"
    exit 1
fi

# Default empty array is allowed (column has NOT NULL DEFAULT '[]').
sqlite3 "$E2E_DB" "
    INSERT INTO tests (id, phase_id, title, test_order)
    VALUES ('T-00.05','P00','plain', 5);
" || { echo "default applies_to rejected"; exit 1; }
