---
allowed-tools: Skill(taskmanager)
description: Display task progress dashboard with status counts, completion percentage, and recent activity
---

# Tasks Dashboard Command

You are implementing `/mwguerra:taskmanager:dashboard`.

## Behavior

1. Ask the `taskmanager` skill to:
   - Read `.taskmanager/tasks.json`.
   - Flatten all tasks and subtasks into a single list.
   - Ensure `estimateSeconds` is populated for all leaf tasks and rollups are recomputed for parents (see the skill’s estimation rules).
   - Ensure `status` propagation is up to date for all parents.

2. Compute summary metrics such as:
   - Total number of tasks (all levels).
   - Number of leaf tasks vs parent tasks.
   - Counts by `status` (`planned`, `in-progress`, `blocked`, `needs-review`, `done`, etc.).
   - Counts by `priority` (`low`, `medium`, `high`, `critical`).
   - Total **estimated** effort for the project:
     - Sum of `estimateSeconds` for all **top-level** tasks (or equivalently, `estimateSeconds` of the virtual root).
     - Present both in seconds and in a human-friendly format (e.g. hours/days).
   - Total **actual** duration so far:
     - Sum of `durationSeconds` for all leaf tasks with a non-null `durationSeconds`.

   - For tasks with `domain = "writing"`:
      - Sum of `targetWordCount` across relevant leaf tasks (by work, by writingType).
      - Sum of `currentWordCount` for tasks where it is non-null (to estimate progress).
      - Breakdown of writing tasks by `writingStage` (how many tasks are in `"outline"`, `"draft"`, `"edit"`, etc.).
3. Compute the **critical path** over the dependency graph:

   1. Treat each task as a node with:
      - weight = `estimateSeconds` (use 0 if `null` but prefer to exclude 0-estimate nodes from the path if possible),
      - edges from each task to the tasks that **depend on it** (based on `dependencies`).
   2. Assume the dependency graph is acyclic. If a cycle is detected, highlight it and skip critical-path computation until the user fixes it.
   3. For each task, compute the length of the **longest path** ending at that task (in seconds) using dynamic programming over a topological ordering:
      - `longestFinish[t] = estimateSeconds[t] + max(longestFinish[dep] for dep in dependenciesOf(t))`
      - tasks with no dependencies start at 0.
   4. The **critical path** is the path ending at the task with the maximum `longestFinish` value.
   5. Present:
      - The ordered list of task IDs and titles on the critical path.
      - The total critical-path duration (in seconds and human-friendly units).
      - A note that this is based purely on `estimateSeconds` + `dependencies`.

4. Highlight the **next available task** (using the shared selection logic defined in the skill):

   - Show its `id`, `title`, `status`, `priority`, `estimateSeconds` (in human units).
   - Optionally show a couple of “runner up” candidates.

5. Render a small text dashboard, for example:

   - High-level counts (by status, priority).
   - A small table of:
     - `id | title | status | priority | estimate (h) | duration (h)`.
   - If writing tasks exist:
     - A table like:
       - `id | title | writingType | contentUnit | writingStage | targetWords | currentWords`.
     - Aggregate totals:
       - Total target words vs current words for each writing work (book, article, etc.).
   - A “Critical path” section:
     - `id -> id -> id` with titles and per-node estimates.
   - A “Next up” section:
     - Next available task and its estimate.

6. Do not modify any files; this command is strictly **read-only**.
