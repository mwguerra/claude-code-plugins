#!/usr/bin/env bash
# SQL-injection linter for the e2e-test-specialist plugin.
#
# Walks every commands/*.md and scripts/*.sh and greps for risky patterns —
# bash variable interpolation directly into SQL strings without going through
# e2e_sql_quote. Numeric and known-safe internal interpolations are allowed
# via an explicit pragma comment: "# lint-sql: numeric-safe" or
# "# lint-sql: internal-safe".
#
# Exit codes:
#   0 → no findings
#   1 → at least one risky pattern found
#
# Usage:
#   bash tests/lint-sql.sh
#   bash tests/lint-sql.sh --quiet      (suppress passes; show only findings)

set -euo pipefail

ROOT="${E2E_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

findings=0
checked=0

# Patterns we flag. Each is a regex of risky shapes; run against bash code
# blocks inside .md and the entire .sh file.
RISKY_PATTERNS=(
    # 'literal'$VAR' or "='$VAR'" — single-quote-bracketing a bash var.
    "='\\\$[A-Za-z_]"
    "= '\\\$[A-Za-z_]"
    # VALUES (..., '$X', ...) where $X is not e2e_sql_quote'd.
    "VALUES.*'\\\$[A-Za-z_]"
    # WHERE id='$X'
    "WHERE [a-z_]+ *= *'\\\$[A-Za-z_]"
    # SET col='$X'
    "SET [a-z_]+ *= *'\\\$[A-Za-z_]"
)

# Patterns that are SAFE and should NOT be flagged even if they superficially
# match (escape-hatches for documented intentional use).
SAFE_OVERRIDES=(
    "lint-sql: ignore"
    "lint-sql: numeric-safe"
    "lint-sql: internal-safe"
    "WHERE \\\$WHERE"  # /tag bulk-tag --where uses raw SQL by design
)

is_safe_line() {
    local line="$1"
    for safe in "${SAFE_OVERRIDES[@]}"; do
        if echo "$line" | grep -Eq "$safe"; then
            return 0
        fi
    done
    return 1
}

scan_file() {
    local file="$1"
    local lineno=0
    local in_fence=0
    while IFS= read -r line; do
        lineno=$((lineno + 1))
        # In .md, only scan inside ```bash code fences.
        if [[ "$file" == *.md ]]; then
            if [[ "$line" =~ ^\`\`\`(bash)?$ ]]; then
                in_fence=$((1 - in_fence))
                continue
            fi
            (( in_fence )) || continue
        fi

        for pat in "${RISKY_PATTERNS[@]}"; do
            if echo "$line" | grep -Eq "$pat"; then
                if is_safe_line "$line"; then continue; fi
                printf '  RISKY  %s:%d  %s\n' "$file" "$lineno" "$(echo "$line" | sed 's/^[ \t]*//' | cut -c1-100)"
                findings=$((findings + 1))
            fi
        done
    done < "$file"
    checked=$((checked + 1))
}

# Walk command + script files
shopt -s nullglob
for f in "$ROOT"/commands/*.md "$ROOT"/scripts/*.sh "$ROOT"/scripts/lib.sh; do
    [[ -f "$f" ]] || continue
    (( QUIET )) || printf 'scanning %s\n' "${f#$ROOT/}"
    scan_file "$f"
done

echo
printf 'lint-sql: %d file(s) checked, %d finding(s)\n' "$checked" "$findings"
[[ "$findings" -eq 0 ]]
