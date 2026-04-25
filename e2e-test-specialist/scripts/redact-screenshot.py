#!/usr/bin/env python3
"""Detect credential values in browser snapshot text and warn before screenshot.

This is a *detection* helper — actual image redaction would require OCR, which
isn't shipped here. Instead, we check the most recent browser_snapshot text
(passed in via stdin) for any stored credential values and emit a warning the
calling command can surface to the user.

Usage:
    cat snapshot.txt | python3 redact-screenshot.py [--db PATH]

Exit codes:
    0  no credential strings found in snapshot
    1  one or more credential values are visibly present (warning printed to stderr)
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--db", default=os.environ.get(
        "E2E_DB", ".e2e-testing/e2e-tests.sqlite"))
    args = p.parse_args()

    snapshot = sys.stdin.read()
    if not snapshot:
        return 0

    if not os.path.exists(args.db):
        return 0  # no creds to check against

    conn = sqlite3.connect(args.db)
    findings: list[tuple[str, str]] = []   # (cred_name, field_name)

    for name, fields_json in conn.execute("SELECT name, fields FROM credentials"):
        try:
            fields = json.loads(fields_json or "{}")
        except Exception:
            continue
        for k, v in fields.items():
            if not isinstance(v, str) or len(v) < 6:
                continue
            if k in ("host", "port", "user", "username", "provider", "url"):
                continue
            if v in snapshot:
                findings.append((name, k))

    if findings:
        print("WARNING: credential values appear in the current page snapshot:", file=sys.stderr)
        for name, field in findings:
            print(f"  - credential '{name}' field '{field}' is visible", file=sys.stderr)
        print("Consider scrolling/dismissing before capturing the screenshot.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
