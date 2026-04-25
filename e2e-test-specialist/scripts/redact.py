#!/usr/bin/env python3
"""Mask credential values stored in credentials.fields out of an arbitrary
text stream. Reads stdin, writes redacted text to stdout.

Usage:
    cat report.md | python3 redact.py <db-path>

Heuristics:
    - Skip very short values (< 6 chars) — likely not secrets.
    - Skip values whose key is in NON_SECRET_KEYS (host/port/user/etc).
    - Replace longer values first (avoid substring shadowing).
"""

from __future__ import annotations

import json
import sqlite3
import sys

NON_SECRET_KEYS = {"host", "port", "user", "username", "provider", "url", "region"}


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: redact.py <db-path>", file=sys.stderr)
        return 2
    db_path = argv[1]
    text = sys.stdin.read()

    conn = sqlite3.connect(db_path)
    patterns: list[tuple[str, str, str]] = []  # (value, name, key)
    for name, fields_json in conn.execute("SELECT name, fields FROM credentials"):
        try:
            fields = json.loads(fields_json or "{}")
        except Exception:
            continue
        for k, v in fields.items():
            if not isinstance(v, str) or len(v) < 6:
                continue
            if k in NON_SECRET_KEYS:
                continue
            patterns.append((v, name, k))

    patterns.sort(key=lambda p: -len(p[0]))
    for value, name, key in patterns:
        text = text.replace(value, f"[redacted:{name}:{key}]")

    sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
