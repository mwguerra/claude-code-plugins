#!/usr/bin/env python3
"""Build a markdown run report from .e2e-testing/e2e-tests.sqlite.

Usage:
    python3 build-report.py <run-id> [--db PATH] [--with-evidence]
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime


def fmt_dur(seconds: float | None) -> str:
    if not seconds:
        return "—"
    s = int(seconds)
    h, rem = divmod(s, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h}h {m}m"
    if m:
        return f"{m}m {s}s"
    return f"{s}s"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("run_id")
    p.add_argument("--db", default=os.environ.get("E2E_DB", ".e2e-testing/e2e-tests.sqlite"))
    p.add_argument("--with-evidence", action="store_true")
    args = p.parse_args()

    if not os.path.exists(args.db):
        print(f"error: db not found: {args.db}", file=sys.stderr)
        return 2
    conn = sqlite3.connect(args.db)
    conn.row_factory = sqlite3.Row

    run = conn.execute("SELECT * FROM test_runs WHERE id = ?", (args.run_id,)).fetchone()
    if not run:
        print(f"error: run not found: {args.run_id}", file=sys.stderr)
        return 2

    progress = conn.execute("SELECT * FROM v_run_progress WHERE run_id = ?", (args.run_id,)).fetchone()
    out: list[str] = []

    date = (run["started_at"] or "")[:10] or datetime.utcnow().strftime("%Y-%m-%d")
    out.append(f"### {date} — {run['id']} — {run['label'] or '(no label)'}")
    out.append("")
    out.append(f"**Status**: {run['status']} | base_url: {run['base_url'] or '—'}")
    if progress:
        passed = progress["steps_passed"] or 0
        failed = progress["steps_failed"] or 0
        skipped = progress["steps_skipped"] or 0
        in_prog = progress["steps_in_progress"] or 0
        touched = progress["tests_touched"] or 0
        out.append(f"**Summary**: {touched} tests touched; "
                   f"{passed} steps passed, {failed} failed, {skipped} skipped, {in_prog} in-progress.")
    out.append("")

    if run["context"]:
        out.append("**Context**:")
        out.append("")
        out.append(run["context"])
        out.append("")

    # Per-phase progress
    out.append("**Per-phase**:")
    out.append("")
    out.append("| Phase | Title | Passed | Failed | Skipped | Blocked |")
    out.append("|-------|-------|-------:|-------:|--------:|--------:|")
    rows = conn.execute("""
        SELECT p.id, p.title,
               SUM(CASE WHEN e.status = 'passed'  THEN 1 ELSE 0 END) AS passed,
               SUM(CASE WHEN e.status = 'failed'  THEN 1 ELSE 0 END) AS failed,
               SUM(CASE WHEN e.status = 'skipped' THEN 1 ELSE 0 END) AS skipped,
               SUM(CASE WHEN e.status = 'blocked' THEN 1 ELSE 0 END) AS blocked
          FROM phases p
          LEFT JOIN tests t ON t.phase_id = p.id
          LEFT JOIN step_executions e ON e.test_id = t.id AND e.run_id = ?
         GROUP BY p.id
        HAVING (passed + failed + skipped + blocked) > 0
         ORDER BY p.phase_order
    """, (args.run_id,)).fetchall()
    for r in rows:
        out.append(f"| {r['id']} | {r['title'][:40]} | {r['passed'] or 0} | {r['failed'] or 0} | {r['skipped'] or 0} | {r['blocked'] or 0} |")
    out.append("")

    # Bugs
    bugs = conn.execute(
        "SELECT id, severity, status, title, root_cause, fix_applied "
        "FROM bugs WHERE discovered_in_run = ? ORDER BY severity, id",
        (args.run_id,)).fetchall()
    out.append(f"**Bugs** ({len(bugs)}):")
    out.append("")
    for b in bugs:
        out.append(f"1. [{b['id']}] {b['severity']} — {b['title']} ({b['status']})")
        if b["root_cause"]:
            out.append(f"   - root cause: {b['root_cause'][:200]}")
        if b["fix_applied"]:
            out.append(f"   - fix: {b['fix_applied'][:200]}")
    if not bugs:
        out.append("_None._")
    out.append("")

    # Directive violations
    viols = conn.execute(
        "SELECT id, enforcement, action_kind, description "
        "FROM directive_violations WHERE run_id = ? ORDER BY created_at",
        (args.run_id,)).fetchall()
    if viols:
        out.append(f"**Directive violations** ({len(viols)}):")
        out.append("")
        for v in viols:
            out.append(f"- [{v['id']}] {v['enforcement']} — {v['action_kind']}: {v['description'][:200]}")
        out.append("")

    # Memories captured
    mems = conn.execute(
        "SELECT id, kind, title FROM memories WHERE related_run_id = ? ORDER BY id",
        (args.run_id,)).fetchall()
    if mems:
        out.append(f"**Memories captured** ({len(mems)}):")
        out.append("")
        for m in mems:
            out.append(f"- [{m['id']}] {m['kind']} — {m['title']}")
        out.append("")

    # Failure details (verbose)
    if args.with_evidence:
        fails = conn.execute("""
            SELECT e.id, e.test_id, e.step_id, e.subject_id,
                   e.actual_result, e.error_message, e.evidence_snapshot
              FROM step_executions e
             WHERE e.run_id = ? AND e.status = 'failed'
             ORDER BY e.started_at
             LIMIT 50
        """, (args.run_id,)).fetchall()
        if fails:
            out.append("**Failure details**:")
            out.append("")
            for f in fails:
                subject = f"  ({f['subject_id']})" if f["subject_id"] else ""
                out.append(f"- {f['test_id']}/{f['step_id']}{subject}")
                if f["error_message"]:
                    out.append(f"  - error: `{f['error_message'][:200]}`")
                if f["actual_result"]:
                    out.append(f"  - actual: `{f['actual_result'][:200]}`")
            out.append("")

    if run["final_state"]:
        out.append("**Final state**:")
        out.append("")
        out.append(run["final_state"])
        out.append("")

    print("\n".join(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
