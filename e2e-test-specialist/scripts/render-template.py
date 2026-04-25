#!/usr/bin/env python3
"""Render a {{subject.field.path}} template against a JSON context.

Usage:
    python3 render-template.py "<template>" "<json-context>"

Examples:
    $ render-template.py 'Navigate to https://{{subject.target_domain}}/admin' \\
        '{"subject":{"target_domain":"todo.secnote.com.br"}}'
    Navigate to https://todo.secnote.com.br/admin

Missing keys render as empty strings (safe — no errors).
"""

from __future__ import annotations

import json
import re
import sys

TPL = re.compile(r"\{\{\s*([\w.\[\]\-]+)\s*\}\}")


def lookup(ctx: dict | list | None, path: str) -> str:
    """Resolve dotted path through nested dicts/lists. Empty string on miss."""
    cur: object = ctx
    for part in path.split("."):
        if isinstance(cur, dict):
            cur = cur.get(part)
        elif isinstance(cur, list):
            try:
                cur = cur[int(part)]
            except (ValueError, IndexError):
                return ""
        else:
            return ""
        if cur is None:
            return ""
    if isinstance(cur, (dict, list)):
        return json.dumps(cur, separators=(",", ":"))
    return str(cur)


def render(template: str, ctx: dict) -> str:
    return TPL.sub(lambda m: lookup(ctx, m.group(1)), template)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("usage: render-template.py <template> <json-context>", file=sys.stderr)
        return 2
    template = argv[1]
    try:
        context = json.loads(argv[2])
    except json.JSONDecodeError as e:
        print(f"error: invalid JSON context: {e}", file=sys.stderr)
        return 2
    sys.stdout.write(render(template, context))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
