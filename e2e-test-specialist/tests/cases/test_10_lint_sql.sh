#!/usr/bin/env bash
# Linter integration: lint-sql.sh should exit 0 on a clean tree.
set -euo pipefail

bash "$CLAUDE_PLUGIN_ROOT/tests/lint-sql.sh" --quiet
