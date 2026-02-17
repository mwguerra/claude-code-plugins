#!/bin/bash
# Secretary Plugin - Cron Setup Helper
# Cross-platform: Linux, macOS, Windows (Task Scheduler)
#
# Usage:
#   install-cron.sh setup    - Install cron job
#   install-cron.sh status   - Check cron status
#   install-cron.sh remove   - Remove cron job

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PLUGIN_ROOT/hooks/scripts/lib/utils.sh"

ACTION="${1:-status}"
WORKER_SCRIPT="$SCRIPT_DIR/worker.sh"
LOCK_FILE="/tmp/secretary-worker.lock"
CRON_MARKER="# secretary-worker"

# ============================================================================
# Dependency Checks
# ============================================================================

check_dependencies() {
    local missing=()

    if ! command -v sqlite3 &>/dev/null; then
        missing+=("sqlite3")
    fi

    if ! command -v jq &>/dev/null; then
        missing+=("jq")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing required dependencies: ${missing[*]}"
        echo ""
        echo "Install them with:"
        case "$SECRETARY_OS_TYPE" in
            linux)
                echo "  Ubuntu/Debian: sudo apt-get install ${missing[*]}"
                echo "  Fedora/RHEL:   sudo dnf install ${missing[*]}"
                echo "  Arch:          sudo pacman -S ${missing[*]}"
                ;;
            macos)
                echo "  brew install ${missing[*]}"
                ;;
            windows)
                echo "  choco install ${missing[*]}"
                echo "  # Or install via Git Bash / MSYS2"
                ;;
        esac
        return 1
    fi
    return 0
}

# ============================================================================
# Platform-specific Cron Management
# ============================================================================

setup_cron() {
    if ! check_dependencies; then
        return 1
    fi

    case "$SECRETARY_OS_TYPE" in
        linux|macos)
            # Check if flock is available (Linux built-in, macOS needs install)
            local flock_cmd="flock -n $LOCK_FILE"
            if ! command -v flock &>/dev/null; then
                if [[ "$SECRETARY_OS_TYPE" == "macos" ]]; then
                    echo "Note: 'flock' is not available on macOS by default."
                    echo "Install with: brew install flock"
                    echo "Proceeding without file locking (not recommended for production)."
                    flock_cmd=""
                fi
            fi

            local timeout_cmd="timeout 120"
            if ! command -v timeout &>/dev/null; then
                if [[ "$SECRETARY_OS_TYPE" == "macos" ]]; then
                    echo "Note: 'timeout' is not available on macOS by default."
                    echo "Install with: brew install coreutils"
                    echo "Proceeding without timeout (not recommended)."
                    timeout_cmd=""
                fi
            fi

            # Build cron line
            local cron_line="*/5 * * * * "
            if [[ -n "$flock_cmd" ]]; then
                cron_line+="$flock_cmd "
            fi
            if [[ -n "$timeout_cmd" ]]; then
                cron_line+="$timeout_cmd "
            fi
            cron_line+="bash $WORKER_SCRIPT >> $SECRETARY_WORKER_LOG 2>&1 $CRON_MARKER"

            # Remove existing secretary cron entry
            crontab -l 2>/dev/null | grep -v "$CRON_MARKER" | crontab - 2>/dev/null || true

            # Add new entry
            (crontab -l 2>/dev/null; echo "$cron_line") | crontab -

            echo "Cron job installed successfully!"
            echo "Schedule: Every 5 minutes"
            echo "Worker: $WORKER_SCRIPT"
            echo "Log: $SECRETARY_WORKER_LOG"
            if [[ -n "$flock_cmd" ]]; then
                echo "Lock: $LOCK_FILE (prevents overlapping runs)"
            fi
            if [[ -n "$timeout_cmd" ]]; then
                echo "Timeout: 120 seconds (hard kill for runaway processes)"
            fi
            ;;

        windows)
            echo "Windows cron setup:"
            echo ""
            echo "Use Task Scheduler to run every 5 minutes:"
            echo "  Program: bash"
            echo "  Arguments: $WORKER_SCRIPT"
            echo "  Log output: $SECRETARY_WORKER_LOG"
            echo ""
            echo "Or use schtasks from command line:"
            echo "  schtasks /create /tn \"SecretaryWorker\" /tr \"bash $WORKER_SCRIPT\" /sc minute /mo 5"
            ;;
    esac
}

check_status() {
    echo "Secretary Cron Status"
    echo "====================="
    echo ""

    case "$SECRETARY_OS_TYPE" in
        linux|macos)
            local existing
            existing=$(crontab -l 2>/dev/null | grep "$CRON_MARKER" || true)
            if [[ -n "$existing" ]]; then
                echo "Status: ACTIVE"
                echo "Entry:  $existing"
            else
                echo "Status: NOT INSTALLED"
                echo "Run: /secretary:cron setup"
            fi
            ;;
        windows)
            echo "Check Task Scheduler for 'SecretaryWorker' task"
            schtasks /query /tn "SecretaryWorker" 2>/dev/null || echo "Status: NOT INSTALLED"
            ;;
    esac

    echo ""

    # Check worker log
    if [[ -f "$SECRETARY_WORKER_LOG" ]]; then
        echo "Recent worker log:"
        tail -5 "$SECRETARY_WORKER_LOG" 2>/dev/null
    else
        echo "No worker log found yet."
    fi

    # Check worker state from DB
    if [[ -f "$SECRETARY_DB_PATH" ]]; then
        echo ""
        echo "Worker state:"
        sqlite3 "$SECRETARY_DB_PATH" "
            SELECT
                'Last run: ' || COALESCE(last_run_at, 'never'),
                'Last success: ' || COALESCE(last_success_at, 'never'),
                'Total runs: ' || total_runs,
                'Items processed: ' || items_processed
            FROM worker_state WHERE id = 1
        " 2>/dev/null | while read -r line; do echo "  $line"; done
    fi
}

remove_cron() {
    case "$SECRETARY_OS_TYPE" in
        linux|macos)
            crontab -l 2>/dev/null | grep -v "$CRON_MARKER" | crontab - 2>/dev/null || true
            echo "Cron job removed."
            ;;
        windows)
            schtasks /delete /tn "SecretaryWorker" /f 2>/dev/null || echo "No task found to remove."
            ;;
    esac

    # Clean up lock file
    rm -f "$LOCK_FILE" 2>/dev/null || true
}

# ============================================================================
# Main
# ============================================================================

case "$ACTION" in
    setup)  setup_cron ;;
    status) check_status ;;
    remove) remove_cron ;;
    *)
        echo "Usage: install-cron.sh {setup|status|remove}"
        exit 1
        ;;
esac
