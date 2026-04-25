#!/usr/bin/env bash
# Verify the {{subject.path}} template engine handles nested keys, missing keys,
# and JSON values.
set -euo pipefail

R="$CLAUDE_PLUGIN_ROOT/scripts/render-template.py"

# Simple substitution
out="$(python3 "$R" 'Navigate to https://{{subject.target_domain}}/admin' \
        '{"subject":{"target_domain":"todo.example.com"}}')"
[[ "$out" == "Navigate to https://todo.example.com/admin" ]] \
    || { echo "simple sub failed: $out"; exit 1; }

# Nested key
out="$(python3 "$R" 'redis={{subject.services.redis}}' \
        '{"subject":{"services":{"redis":"6.2","postgres":"15"}}}')"
[[ "$out" == "redis=6.2" ]] \
    || { echo "nested failed: $out"; exit 1; }

# Missing key — empty string, no error
out="$(python3 "$R" 'host={{subject.host}} port={{subject.port}}' \
        '{"subject":{"host":"db1"}}')"
[[ "$out" == "host=db1 port=" ]] \
    || { echo "missing key failed: $out"; exit 1; }

# JSON value (object) — rendered as compact JSON
out="$(python3 "$R" 'meta={{subject.meta}}' \
        '{"subject":{"meta":{"a":1,"b":2}}}')"
[[ "$out" == 'meta={"a":1,"b":2}' ]] \
    || { echo "json value failed: $out"; exit 1; }

# Multiple substitutions per template
out="$(python3 "$R" '{{subject.username}}/{{subject.password}}' \
        '{"subject":{"username":"alice","password":"hunter2"}}')"
[[ "$out" == "alice/hunter2" ]] \
    || { echo "multi sub failed: $out"; exit 1; }
