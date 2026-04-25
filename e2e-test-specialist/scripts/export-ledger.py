#!/usr/bin/env python3
"""Export the full DB to a markdown ledger compatible with /import.

Usage:
    python3 export-ledger.py [--db PATH] [--include-history]
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--db", default=os.environ.get("E2E_DB", ".e2e-testing/e2e-tests.sqlite"))
    p.add_argument("--include-history", action="store_true")
    args = p.parse_args()

    if not os.path.exists(args.db):
        print(f"error: db not found: {args.db}", file=sys.stderr)
        return 2
    conn = sqlite3.connect(args.db)
    conn.row_factory = sqlite3.Row

    out: list[str] = []
    out.append("# E2E Testing Ledger (exported)")
    out.append("")

    # Directives
    rows = conn.execute("SELECT * FROM directives WHERE active = 1 ORDER BY id").fetchall()
    if rows:
        out.append("## Directives")
        out.append("")
        for d in rows:
            out.append(f"### {d['title']}")
            out.append("")
            out.append(d["body"])
            out.append("")

    # Infrastructure & credentials (combined, like the source format)
    rows_inf = conn.execute("SELECT * FROM infrastructure ORDER BY id").fetchall()
    if rows_inf:
        out.append("## VPS Infrastructure & Credentials")
        out.append("")
        for i in rows_inf:
            out.append(f"### {i['name']}")
            if i["ip"]:
                out.append(f"- **IP**: {i['ip']} | **SSH Port**: {i['ssh_port'] or 22}")
            if i["wildcard_domain"]:
                out.append(f"- **Wildcard domain**: `{i['wildcard_domain']}`")
            if i["wireguard_ip"]:
                out.append(f"- **WireGuard IP**: `{i['wireguard_ip']}`")
            # Credentials linked to this infra
            cred = conn.execute("SELECT * FROM credentials WHERE id = ?", (i["credential_id"],)).fetchone() if i["credential_id"] else None
            if cred:
                fields = json.loads(cred["fields"] or "{}")
                if fields.get("password"):
                    out.append(f"- **Root password**: `{fields['password']}`")
            out.append("")

    # Apps
    apps = conn.execute("SELECT * FROM apps ORDER BY id").fetchall()
    if apps:
        out.append("## Test App Matrix")
        out.append("")
        out.append("| App | Type | DB | Redis | Horizon | Reverb | Scheduler | S3 |")
        out.append("|-----|------|----|-------|---------|--------|-----------|----|")
        for a in apps:
            services = json.loads(a["services"] or "{}")
            def fmt(v):
                if v is True or v == "yes": return "Yes"
                if v is False or v in ("", None): return "—"
                return str(v)
            out.append(f"| {a['name']} | {a['app_type'] or ''} | {fmt(services.get('db'))} | {fmt(services.get('redis'))} | {fmt(services.get('horizon'))} | {fmt(services.get('reverb'))} | {fmt(services.get('scheduler'))} | {fmt(services.get('s3'))} |")
        out.append("")

    # Phases / Tests / Steps
    phases = conn.execute("SELECT * FROM phases ORDER BY phase_order").fetchall()
    if phases:
        out.append("## E2E Test Phases")
        out.append("")
        for p in phases:
            num = int(p["id"][1:]) if p["id"].startswith("P") else 0
            out.append(f"### Phase {num}: {p['title']}")
            out.append("")
            if p["description"]:
                out.append(p["description"])
                out.append("")
            tests = conn.execute(
                "SELECT * FROM tests WHERE phase_id = ? AND deprecated_at IS NULL ORDER BY test_order",
                (p["id"],)).fetchall()
            for t in tests:
                out.append(f"**{t['title']}**")
                out.append("")
                steps = conn.execute(
                    "SELECT * FROM test_steps WHERE test_id = ? ORDER BY step_order",
                    (t["id"],)).fetchall()
                for s in steps:
                    out.append(f"{s['step_order']}. {s['action']}")
                out.append("")

    # Test Count Summary
    counts = conn.execute("""
        SELECT p.id, p.title, p.expected_test_count,
               (SELECT COUNT(*) FROM tests WHERE phase_id = p.id AND deprecated_at IS NULL) AS actual
          FROM phases p
         ORDER BY p.phase_order
    """).fetchall()
    if counts:
        out.append("## Test Count Summary")
        out.append("")
        out.append("| Phase | What | Tests |")
        out.append("|-------|------|------:|")
        for c in counts:
            n = c["expected_test_count"] or c["actual"]
            out.append(f"| {c['id'][1:]} | {c['title'][:40]} | {n} |")
        out.append("")

    # Historical runs
    if args.include_history:
        runs = conn.execute(
            "SELECT * FROM test_runs WHERE status='completed' ORDER BY started_at"
        ).fetchall()
        if runs:
            out.append("## Test Results Log")
            out.append("")
            for r in runs:
                date = (r["started_at"] or "")[:10]
                out.append(f"### {date} — {r['id']} — {r['label'] or ''}")
                out.append("")
                if r["final_state"]:
                    out.append(r["final_state"])
                    out.append("")

    print("\n".join(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
