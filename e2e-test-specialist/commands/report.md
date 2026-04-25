---
description: Generate a markdown run report — back-compat with the Test Results Log format
allowed-tools: Bash(bash:*), Bash(sqlite3:*), Bash(python3:*), Read(*), Write(*)
argument-hint: [<run-id>] [--out path/to/report.md] [--with-evidence]
---

# /e2e-test-specialist:report

Generate a self-contained markdown report for a run. Defaults to the active
run; pass `<run-id>` to report on a previous one.

The output mirrors the original Test Results Log format
(`### YYYY-MM-DD — R-NNN — Title`, then **Context**, **Final state**,
**Phases**, **Bugs**, **Memories**) so the report can be appended directly
into a project's external markdown ledger.

## Process

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh"
e2e_require_db

RUN_ID="${1:-$(e2e_query_value 'SELECT active_run_id FROM state WHERE id=1;')}"
[[ -n "$RUN_ID" ]] || e2e_die "no run id given and no active run"

OUT="${OUT:-$E2E_ROOT_DIR/runs/$RUN_ID/report.md}"
mkdir -p "$(dirname "$OUT")"

python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build-report.py" "$RUN_ID" \
    | e2e_redact > "$OUT"

echo "Report written: $OUT"
```

The companion script `scripts/build-report.py` queries:

- `test_runs` for header + context
- `v_run_progress` for the summary line
- `v_test_results_by_subject` for per-test pass/fail (per-subject when parametrized)
- `bugs WHERE discovered_in_run = ?` — full bug list with status
- `directive_violations WHERE run_id = ?` — flagged actions
- `screenshots WHERE run_id = ?` — paths + labels
- `memories WHERE related_run_id = ?` — captured during the run
- `step_executions WHERE run_id = ? AND status = 'failed'` — failure detail (with `--with-evidence`)

## Redaction

The report passes through `e2e_redact` before write — credential values
(tokens, passwords) stored in `credentials.fields` are replaced with
`[redacted:{name}:{field}]` markers. Skip the redaction step at your own
risk; never paste a non-redacted report into chat or a public ledger.

## Output structure

```markdown
### 2026-04-22 — R-032 — Clean-VPS Full Run + 3-Instance LB

**Status**: completed | base_url: https://seee.com.br | duration: 2h 14m

**Summary**: 283/283 tests touched; 1141 step-executions, 1131 passed,
8 failed (2 critical bugs), 2 skipped.

**Per-phase**: (markdown table from v_run_progress per phase)

**Bugs**:
1. [BUG-014] critical — LB topology includes source as backend (open)
2. [BUG-015] critical — Off-by-one count drops Nth worker (fixed in commit ...)

**Directive violations**: 0

**Memories captured**:
- M-021 — "DO token lacks Domains scope; use nip.io"

**Failure details** (with --with-evidence):
- T-42.07 step S-42.07.005 — actual: ..., expected: ...
```
