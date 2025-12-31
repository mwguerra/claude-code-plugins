#!/bin/bash
# task-stats.sh - Efficient task statistics extraction for taskmanager
# Usage: ./task-stats.sh [tasks.json path] [--json|--summary|--next|--next5]
#
# This script efficiently extracts statistics from tasks.json without loading
# the entire file into memory, saving tokens and context when used by Claude.

set -e

# Handle --help as first argument
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [tasks.json path] [mode] [args...]"
    echo ""
    echo "Read-only Modes:"
    echo "  --summary          Full text summary (default)"
    echo "  --json             Full JSON output for programmatic use"
    echo "  --next             Next recommended task"
    echo "  --next5            Next 5 recommended tasks"
    echo "  --status           Task counts by status"
    echo "  --priority         Task counts by priority"
    echo "  --levels           Task counts by level depth"
    echo "  --remaining        Count of remaining tasks"
    echo "  --time             Estimated time remaining"
    echo "  --completion       Completion statistics"
    echo ""
    echo "Task Query Modes:"
    echo "  --get <id> [key]   Get task by ID, optionally extract specific key"
    echo "                     Examples: --get 1.2.3"
    echo "                               --get 1.2.3 title"
    echo "                               --get 1.2.3 status"
    echo "                               --get 1.2.3 complexity.scale"
    echo ""
    echo "Write Modes (modify tasks.json):"
    echo "  --set-status <status> <id1> [id2...]  Update status for one or more tasks"
    echo "                     Valid statuses: draft, planned, in-progress, blocked,"
    echo "                                     paused, done, canceled, duplicate, needs-review"
    echo "                     Examples: --set-status done 1.2.3"
    echo "                               --set-status done 1.2.3 1.2.4 1.2.5"
    echo ""
    echo "  --help, -h         Show this help"
    exit 0
fi

# Default path
TASKS_FILE="${1:-.taskmanager/tasks.json}"
MODE="${2:---summary}"

# Check if tasks.json exists
if [[ ! -f "$TASKS_FILE" ]]; then
    echo "Error: $TASKS_FILE not found" >&2
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed" >&2
    echo "Install with: brew install jq (macOS) or apt install jq (Linux)" >&2
    exit 1
fi

# Function to flatten all tasks recursively
flatten_tasks() {
    jq -r '
    def flatten_all:
      . as $t |
      [$t] + (($t.subtasks // []) | map(flatten_all) | add // []);

    [.tasks[] | flatten_all] | add // []
    ' "$TASKS_FILE"
}

# Function to get counts by status
get_status_counts() {
    flatten_tasks | jq -r '
    group_by(.status) |
    map({status: .[0].status, count: length}) |
    sort_by(.status) |
    .[] | "\(.status): \(.count)"
    '
}

# Function to get counts by priority
get_priority_counts() {
    flatten_tasks | jq -r '
    group_by(.priority) |
    map({priority: .[0].priority, count: length}) |
    sort_by(.priority) |
    .[] | "\(.priority): \(.count)"
    '
}

# Function to get counts by level (depth based on ID dots)
get_level_counts() {
    flatten_tasks | jq -r '
    map({
      id: .id,
      level: ((.id | split(".") | length))
    }) |
    group_by(.level) |
    map({level: .[0].level, count: length}) |
    sort_by(.level) |
    .[] | "Level \(.level): \(.count) tasks"
    '
}

# Function to get remaining tasks (not done/canceled/duplicate)
get_remaining_tasks() {
    flatten_tasks | jq -r '
    map(select(.status != "done" and .status != "canceled" and .status != "duplicate")) |
    length
    '
}

# Function to get total tasks
get_total_tasks() {
    flatten_tasks | jq -r 'length'
}

# Function to get completion stats
get_completion_stats() {
    flatten_tasks | jq -r '
    {
      total: length,
      done: [.[] | select(.status == "done")] | length,
      in_progress: [.[] | select(.status == "in-progress")] | length,
      blocked: [.[] | select(.status == "blocked")] | length,
      remaining: [.[] | select(.status != "done" and .status != "canceled" and .status != "duplicate")] | length
    } |
    "Total: \(.total)\nDone: \(.done)\nIn Progress: \(.in_progress)\nBlocked: \(.blocked)\nRemaining: \(.remaining)\nCompletion: \(if .total > 0 then ((.done / .total * 100) | floor) else 0 end)%"
    '
}

# Function to get leaf tasks only (tasks without subtasks or with empty subtasks)
get_leaf_tasks() {
    flatten_tasks | jq -r '
    map(select((.subtasks | length) == 0 or .subtasks == null))
    '
}

# Function to get estimated time remaining (sum of estimateSeconds for remaining leaf tasks)
get_time_remaining() {
    flatten_tasks | jq -r '
    [
      .[] |
      select(
        (.status != "done" and .status != "canceled" and .status != "duplicate") and
        ((.subtasks | length) == 0 or .subtasks == null)
      ) |
      .estimateSeconds // 0
    ] | add // 0 |
    . as $seconds |
    {
      seconds: .,
      hours: (. / 3600 | floor),
      days: (. / 86400 * 10 | floor / 10)
    } |
    "Estimated remaining: \(.seconds) seconds (\(.hours) hours / \(.days) days)"
    '
}

# Function to find next recommended task
# Priority: not done/canceled/duplicate, dependencies satisfied, highest priority, lowest complexity
get_next_task() {
    flatten_tasks | jq -r '
    # Get all task IDs that are done
    [.[] | select(.status == "done" or .status == "canceled" or .status == "duplicate") | .id] as $done_ids |

    # Find tasks that are:
    # 1. Not done/canceled/duplicate
    # 2. Are leaf tasks (no subtasks)
    # 3. Have all dependencies in $done_ids (or no dependencies)
    [
      .[] |
      select(
        (.status != "done" and .status != "canceled" and .status != "duplicate") and
        (.status != "blocked") and
        ((.subtasks | length) == 0 or .subtasks == null)
      ) |
      select(
        (.dependencies == null) or
        (.dependencies | length == 0) or
        (.dependencies | all(. as $dep | $done_ids | index($dep) != null))
      )
    ] |

    # Sort by priority (critical > high > medium > low) then by complexity score (ascending)
    sort_by(
      (if .priority == "critical" then 0
       elif .priority == "high" then 1
       elif .priority == "medium" then 2
       else 3 end),
      (.complexity.score // 3)
    ) |

    # Get first task
    .[0] // null |

    if . == null then
      "No available tasks found"
    else
      "ID: \(.id)\nTitle: \(.title)\nStatus: \(.status)\nPriority: \(.priority)\nComplexity: \(.complexity.scale // "N/A") (\(.complexity.score // "N/A"))\nEstimate: \((.estimateSeconds // 0) / 3600 | . * 10 | floor / 10) hours"
    end
    '
}

# Function to find next 5 recommended tasks
get_next5_tasks() {
    flatten_tasks | jq -r '
    # Get all task IDs that are done
    [.[] | select(.status == "done" or .status == "canceled" or .status == "duplicate") | .id] as $done_ids |

    # Find available tasks
    [
      .[] |
      select(
        (.status != "done" and .status != "canceled" and .status != "duplicate") and
        (.status != "blocked") and
        ((.subtasks | length) == 0 or .subtasks == null)
      ) |
      select(
        (.dependencies == null) or
        (.dependencies | length == 0) or
        (.dependencies | all(. as $dep | $done_ids | index($dep) != null))
      )
    ] |

    # Sort by priority then complexity
    sort_by(
      (if .priority == "critical" then 0
       elif .priority == "high" then 1
       elif .priority == "medium" then 2
       else 3 end),
      (.complexity.score // 3)
    ) |

    # Get first 5
    .[0:5] |

    if length == 0 then
      "No available tasks found"
    else
      to_entries |
      map("\(.key + 1). [\(.value.id)] \(.value.title) (\(.value.priority), \(.value.complexity.scale // "N/A"))") |
      join("\n")
    end
    '
}

# Function to get a task by ID
get_task_by_id() {
    local task_id="$1"
    local key="$2"

    if [[ -z "$task_id" ]]; then
        echo "Error: Task ID required" >&2
        exit 1
    fi

    local result
    result=$(flatten_tasks | jq --arg id "$task_id" '
    .[] | select(.id == $id)
    ')

    if [[ -z "$result" ]] || [[ "$result" == "null" ]]; then
        echo "Error: Task '$task_id' not found" >&2
        exit 1
    fi

    if [[ -z "$key" ]]; then
        echo "$result" | jq '.'
    else
        # Handle nested keys like "complexity.scale"
        echo "$result" | jq -r --arg key "$key" 'getpath($key | split("."))'
    fi
}

# Function to get multiple tasks by IDs
get_tasks_by_ids() {
    local ids_json="$1"

    flatten_tasks | jq --argjson ids "$ids_json" '
    [.[] | select(.id as $tid | $ids | index($tid) != null)]
    '
}

# Function to update task status by ID (modifies tasks.json)
set_task_status() {
    local new_status="$1"
    shift
    local task_ids=("$@")

    # Validate status
    local valid_statuses="draft planned in-progress blocked paused done canceled duplicate needs-review"
    if ! echo "$valid_statuses" | grep -qw "$new_status"; then
        echo "Error: Invalid status '$new_status'" >&2
        echo "Valid statuses: $valid_statuses" >&2
        exit 1
    fi

    if [[ ${#task_ids[@]} -eq 0 ]]; then
        echo "Error: At least one task ID required" >&2
        exit 1
    fi

    # Convert task IDs array to JSON array
    local ids_json
    ids_json=$(printf '%s\n' "${task_ids[@]}" | jq -R . | jq -s .)

    # Create backup
    cp "$TASKS_FILE" "${TASKS_FILE}.bak"

    # Update tasks recursively
    local updated
    updated=$(jq --arg status "$new_status" --argjson ids "$ids_json" '
    def update_status:
      if .id as $tid | $ids | index($tid) != null then
        .status = $status |
        if $status == "done" or $status == "canceled" or $status == "duplicate" then
          .completedAt = (now | todate)
        else
          .
        end |
        if $status == "in-progress" and .startedAt == null then
          .startedAt = (now | todate)
        else
          .
        end
      else
        .
      end |
      if .subtasks then
        .subtasks = [.subtasks[] | update_status]
      else
        .
      end;

    .tasks = [.tasks[] | update_status]
    ' "$TASKS_FILE")

    # Validate the result is valid JSON
    if ! echo "$updated" | jq empty 2>/dev/null; then
        echo "Error: Failed to update tasks (invalid JSON produced)" >&2
        mv "${TASKS_FILE}.bak" "$TASKS_FILE"
        exit 1
    fi

    # Write the updated file
    echo "$updated" > "$TASKS_FILE"

    # Verify the IDs were found and updated
    local updated_count
    updated_count=$(flatten_tasks | jq --arg status "$new_status" --argjson ids "$ids_json" '
    [.[] | select(.id as $tid | $ids | index($tid) != null) | select(.status == $status)] | length
    ')

    local requested_count=${#task_ids[@]}

    if [[ "$updated_count" -eq "$requested_count" ]]; then
        echo "Successfully updated $updated_count task(s) to status '$new_status':"
        for id in "${task_ids[@]}"; do
            echo "  - $id"
        done
        rm -f "${TASKS_FILE}.bak"
    else
        echo "Warning: Requested $requested_count task(s), but only $updated_count were updated" >&2
        echo "Some task IDs may not exist. Check your IDs and try again." >&2
        # Keep the update but warn
        rm -f "${TASKS_FILE}.bak"
    fi
}

# Function to output full JSON stats
get_json_stats() {
    flatten_tasks | jq '
    # Get all task IDs that are done
    [.[] | select(.status == "done" or .status == "canceled" or .status == "duplicate") | .id] as $done_ids |

    # Find available tasks
    [
      .[] |
      select(
        (.status != "done" and .status != "canceled" and .status != "duplicate") and
        (.status != "blocked") and
        ((.subtasks | length) == 0 or .subtasks == null)
      ) |
      select(
        (.dependencies == null) or
        (.dependencies | length == 0) or
        (.dependencies | all(. as $dep | $done_ids | index($dep) != null))
      )
    ] |
    sort_by(
      (if .priority == "critical" then 0
       elif .priority == "high" then 1
       elif .priority == "medium" then 2
       else 3 end),
      (.complexity.score // 3)
    ) as $available |

    . as $all |
    {
      summary: {
        total: ($all | length),
        done: ([$all[] | select(.status == "done")] | length),
        in_progress: ([$all[] | select(.status == "in-progress")] | length),
        blocked: ([$all[] | select(.status == "blocked")] | length),
        planned: ([$all[] | select(.status == "planned")] | length),
        needs_review: ([$all[] | select(.status == "needs-review")] | length),
        remaining: ([$all[] | select(.status != "done" and .status != "canceled" and .status != "duplicate")] | length),
        completion_percent: (if ($all | length) > 0 then (([$all[] | select(.status == "done")] | length) / ($all | length) * 100 | floor) else 0 end)
      },
      by_status: (
        $all | group_by(.status // "unknown") |
        map({key: (.[0].status // "unknown"), value: length}) |
        from_entries
      ),
      by_priority: (
        $all | group_by(.priority // "unset") |
        map({key: (.[0].priority // "unset"), value: length}) |
        from_entries
      ),
      by_level: (
        $all |
        map({level: (.id | split(".") | length)}) |
        group_by(.level) |
        map({key: ("level_" + (.[0].level | tostring)), value: length}) |
        from_entries
      ),
      time_estimate: {
        remaining_seconds: (
          [$all[] |
           select(
             (.status != "done" and .status != "canceled" and .status != "duplicate") and
             ((.subtasks | length) == 0 or .subtasks == null)
           ) | .estimateSeconds // 0
          ] | add // 0
        ),
        remaining_hours: (
          ([$all[] |
           select(
             (.status != "done" and .status != "canceled" and .status != "duplicate") and
             ((.subtasks | length) == 0 or .subtasks == null)
           ) | .estimateSeconds // 0
          ] | add // 0) / 3600 | . * 10 | floor / 10
        )
      },
      next_task: ($available[0] // null | if . then {id: .id, title: .title, priority: .priority, complexity: .complexity.scale, estimate_hours: ((.estimateSeconds // 0) / 3600 | . * 10 | floor / 10)} else null end),
      next_5_tasks: ([$available[0:5][] | {id: .id, title: .title, priority: .priority, complexity: .complexity.scale}])
    }
    '
}

# Main logic based on mode
case "$MODE" in
    --json)
        get_json_stats
        ;;
    --summary)
        echo "=== Task Statistics ==="
        echo ""
        get_completion_stats
        echo ""
        echo "--- By Status ---"
        get_status_counts
        echo ""
        echo "--- By Priority ---"
        get_priority_counts
        echo ""
        echo "--- By Level ---"
        get_level_counts
        echo ""
        get_time_remaining
        ;;
    --next)
        echo "=== Next Recommended Task ==="
        get_next_task
        ;;
    --next5)
        echo "=== Next 5 Recommended Tasks ==="
        get_next5_tasks
        ;;
    --status)
        get_status_counts
        ;;
    --priority)
        get_priority_counts
        ;;
    --levels)
        get_level_counts
        ;;
    --remaining)
        echo "Remaining tasks: $(get_remaining_tasks)"
        ;;
    --time)
        get_time_remaining
        ;;
    --completion)
        get_completion_stats
        ;;
    --get)
        # Get task by ID: --get <id> [key]
        TASK_ID="${3:-}"
        KEY="${4:-}"
        get_task_by_id "$TASK_ID" "$KEY"
        ;;
    --set-status)
        # Set status: --set-status <status> <id1> [id2...]
        NEW_STATUS="${3:-}"
        shift 3 2>/dev/null || { echo "Error: --set-status requires status and at least one task ID" >&2; exit 1; }
        set_task_status "$NEW_STATUS" "$@"
        ;;
    --help|-h)
        echo "Usage: $0 [tasks.json path] [mode] [args...]"
        echo ""
        echo "Read-only Modes:"
        echo "  --summary          Full text summary (default)"
        echo "  --json             Full JSON output for programmatic use"
        echo "  --next             Next recommended task"
        echo "  --next5            Next 5 recommended tasks"
        echo "  --status           Task counts by status"
        echo "  --priority         Task counts by priority"
        echo "  --levels           Task counts by level depth"
        echo "  --remaining        Count of remaining tasks"
        echo "  --time             Estimated time remaining"
        echo "  --completion       Completion statistics"
        echo ""
        echo "Task Query Modes:"
        echo "  --get <id> [key]   Get task by ID, optionally extract specific key"
        echo ""
        echo "Write Modes:"
        echo "  --set-status <status> <id1> [id2...]  Update status for tasks"
        echo ""
        echo "  --help, -h         Show this help"
        ;;
    *)
        echo "Unknown mode: $MODE"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
