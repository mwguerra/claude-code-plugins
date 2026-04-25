#!/usr/bin/env bash
# Plugin self-tests for e2e-test-specialist.
#
# Each test runs in a temporary working directory with a fresh DB. The runner
# stops at the first failure unless --keep-going is passed. Test names are the
# files in tests/cases/*.sh sorted alphabetically.
#
# Usage:
#   bash tests/run-tests.sh                     (run everything, stop on first failure)
#   bash tests/run-tests.sh --keep-going        (run everything, report at end)
#   bash tests/run-tests.sh test_init.sh        (run a specific case)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$ROOT"

KEEP_GOING=0
SELECTED=""
for arg in "$@"; do
    case "$arg" in
        --keep-going) KEEP_GOING=1 ;;
        --help|-h) echo "usage: run-tests.sh [--keep-going] [test_case.sh ...]"; exit 0 ;;
        *) SELECTED="$SELECTED $arg" ;;
    esac
done

# ANSI helpers
green()  { printf '\033[32m%s\033[0m' "$*"; }
red()    { printf '\033[31m%s\033[0m' "$*"; }
yellow() { printf '\033[33m%s\033[0m' "$*"; }

passes=0
fails=0
failures=()

# Pick test case files
cases_dir="$ROOT/tests/cases"
if [[ -n "$SELECTED" ]]; then
    case_files=()
    for s in $SELECTED; do
        case_files+=("$cases_dir/$s")
    done
else
    case_files=("$cases_dir"/*.sh)
fi

for case_file in "${case_files[@]}"; do
    [[ -f "$case_file" ]] || { echo "missing: $case_file"; exit 2; }
    name="$(basename "$case_file" .sh)"
    sandbox="$(mktemp -d -t e2e-self-XXXXXX)"
    printf '  %s ... ' "$name"

    if (
        cd "$sandbox"
        export E2E_ROOT_DIR="$sandbox/.e2e-testing"
        export E2E_DB="$E2E_ROOT_DIR/e2e-tests.sqlite"
        export E2E_LOG="$E2E_ROOT_DIR/logs/activity.log"
        export E2E_CONFIG="$E2E_ROOT_DIR/config.json"
        bash "$case_file"
    ) >"$sandbox/out.log" 2>&1; then
        green "ok"; echo
        rm -rf "$sandbox"
        passes=$((passes + 1))
    else
        red "FAIL"; echo "  ($sandbox/out.log)"
        sed 's/^/    | /' "$sandbox/out.log" | tail -30
        failures+=("$name :: $sandbox/out.log")
        fails=$((fails + 1))
        if (( KEEP_GOING == 0 )); then break; fi
    fi
done

echo
printf 'tests: %s passed, %s failed\n' "$(green "$passes")" "$([[ $fails -eq 0 ]] && green 0 || red "$fails")"

if (( fails > 0 )); then
    echo
    yellow "Failures:"; echo
    for f in "${failures[@]}"; do echo "  $f"; done
    exit 1
fi
exit 0
