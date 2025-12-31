#!/bin/bash
# task-stats.sh - Efficient task statistics extraction for taskmanager
# Usage: ./task-stats.sh [tasks.json path] [--json|--summary|--next|--next5]
#
# This script efficiently extracts statistics from tasks.json without loading
# the entire file into memory, saving tokens and context when used by Claude.

set -e

# Handle --help as first argument
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0 [tasks.json path] [mode]"
    echo ""
    echo "Modes:"
    echo "  --summary     Full text summary (default)"
    echo "  --json        Full JSON output for programmatic use"
    echo "  --next        Next recommended task"
    echo "  --next5       Next 5 recommended tasks"
    echo "  --status      Task counts by status"
    echo "  --priority    Task counts by priority"
    echo "  --levels      Task counts by level depth"
    echo "  --remaining   Count of remaining tasks"
    echo "  --time        Estimated time remaining"
    echo "  --completion  Completion statistics"
    echo "  --help, -h    Show this help"
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
    --help|-h)
        echo "Usage: $0 [tasks.json path] [mode]"
        echo ""
        echo "Modes:"
        echo "  --summary     Full text summary (default)"
        echo "  --json        Full JSON output for programmatic use"
        echo "  --next        Next recommended task"
        echo "  --next5       Next 5 recommended tasks"
        echo "  --status      Task counts by status"
        echo "  --priority    Task counts by priority"
        echo "  --levels      Task counts by level depth"
        echo "  --remaining   Count of remaining tasks"
        echo "  --time        Estimated time remaining"
        echo "  --completion  Completion statistics"
        echo "  --help, -h    Show this help"
        ;;
    *)
        echo "Unknown mode: $MODE"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
