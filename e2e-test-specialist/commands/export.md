---
description: Export the full DB to a markdown ledger — round-trip with /import
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(python3:*), Read(*), Write(*)
argument-hint: [--out path/to/ledger.md] [--include-history] [--no-redact]
---

# /e2e-test-specialist:export

Round-trip the entire plan back to markdown — directives, infrastructure,
credentials, apps, sites, phases (with tests + steps), test count summary,
and (optionally) historical runs. The output is byte-compatible with what
`/import` would re-ingest.

## Use cases

- Sharing the plan with someone who doesn't have the DB
- Committing a snapshot to git (after redaction)
- Migrating the plan to another project
- Diffing the plan against an upstream markdown ledger

## Process

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

OUT="${OUT:-$E2E_ROOT_DIR/exports/$(date -u +%Y%m%dT%H%M%SZ)-ledger.md}"
mkdir -p "$(dirname "$OUT")"

python3 "${CLAUDE_PLUGIN_ROOT}/scripts/export-ledger.py" \
    ${INCLUDE_HISTORY:+--include-history} \
    | { if [[ "${NO_REDACT:-0}" == 1 ]]; then cat; else e2e_redact; fi; } \
    > "$OUT"

echo "Exported: $OUT"
```

## Redaction default

By default the output passes through `e2e_redact` so credential values are
masked. Pass `--no-redact` ONLY if you intend to keep the export private
(local file, encrypted backup) — never commit a non-redacted export to git.

## Round-trip semantics

After export → re-import:
- Directives, apps, infrastructure, phases, tests, steps: idempotent (INSERT OR REPLACE).
- Credentials and memories: **additive** (new IDs each time). Run
  `/plan dedupe-creds` after re-import if needed.
- Historical runs: included only with `--include-history`. Without it,
  the export is a "plan-only" snapshot.
