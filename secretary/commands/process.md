---
description: Manually trigger queue processing - run the worker inline and show before/after queue depth
allowed-tools: Read, Bash, Glob, Grep
argument-hint: "[--limit N]"
---

# Secretary Process Command

Manually trigger queue processing. Runs the worker inline (not via cron) to process pending queue items immediately. Shows before and after queue depth so you can see what was processed.

## Usage

```
/secretary:process                 # Process all pending items (up to 50)
/secretary:process --limit 10      # Process at most 10 items
/secretary:process --verbose        # Show details of each processed item
```

## Database Location

```bash
DB_PATH="$HOME/.claude/secretary/secretary.db"
PROCESS_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/process-queue.sh"

if [[ ! -f "$DB_PATH" ]]; then
    echo "Secretary database not initialized. Run /secretary:init first."
    exit 1
fi
```

## Process Steps

### 1. Capture Before State

Query queue depth before processing:

```sql
SELECT
    status,
    COUNT(*) as count
FROM queue
GROUP BY status;
```

Also get item type breakdown for pending:

```sql
SELECT
    item_type,
    COUNT(*) as count
FROM queue
WHERE status = 'pending'
GROUP BY item_type
ORDER BY count DESC;
```

### 2. Run the Queue Processor

Execute the process-queue.sh script inline (not via the full worker):

```bash
bash "$PROCESS_SCRIPT" --inline --limit ${LIMIT:-50}
```

The `--inline` flag tells the processor:
- Time-boxed execution (no vault sync)
- No GitHub cache refresh
- Focus only on queue processing

The processor handles these item types:
- `user_prompt` / `tool_output` / `agent_output` - AI extraction of decisions, ideas, commitments
- `commit` - Git metadata parsing, activity timeline entry
- `stop` / `session_end` - Session closure, summary generation

### 3. Capture After State

Query queue depth after processing:

```sql
SELECT
    status,
    COUNT(*) as count
FROM queue
GROUP BY status;
```

### 4. Show Results

Calculate the delta between before and after states.

Query what was created during processing:

```sql
-- New decisions created
SELECT id, title FROM decisions
WHERE created_at >= datetime('now', '-5 minutes')
ORDER BY created_at DESC LIMIT 10;

-- New ideas created
SELECT id, title FROM ideas
WHERE created_at >= datetime('now', '-5 minutes')
ORDER BY created_at DESC LIMIT 10;

-- New commitments created
SELECT id, title FROM commitments
WHERE created_at >= datetime('now', '-5 minutes')
ORDER BY created_at DESC LIMIT 10;

-- Activity timeline entries
SELECT activity_type, title FROM activity_timeline
WHERE timestamp >= datetime('now', '-5 minutes')
ORDER BY timestamp DESC LIMIT 10;
```

## Output Format

```markdown
# Queue Processing Complete

## Before

| Status | Count |
|--------|-------|
| Pending | 12 |
| Processing | 0 |
| Processed | 230 |
| Failed | 1 |
| Expired | 8 |

**Pending by type:**
- user_prompt: 5
- tool_output: 4
- commit: 2
- session_end: 1

## After

| Status | Count |
|--------|-------|
| Pending | 0 |
| Processing | 0 |
| Processed | 242 |
| Failed | 1 |
| Expired | 8 |

## Results

**Processed:** 12 items
**Failed:** 0 items

### Extracted Items

**Decisions (2):**
- [D-0023] Use queue-based architecture for Secretary
- [D-0024] Separate memory DB for encryption support

**Ideas (1):**
- [I-0015] Add pattern-based scheduling recommendations

**Commitments (3):**
- [C-0030] Write tests for queue processor
- [C-0031] Document API endpoints
- [C-0032] Review PR #89

**Commits Logged (2):**
- abc123 feat: add queue processing
- def456 fix: session tracking bug

**Sessions Closed (1):**
- Session 20240217-100000 completed (45m, 5 commits)

---
*Queue depth: 12 -> 0 (all clear)*
*Use `/secretary:status queue` for detailed queue view*
```

### When Queue is Empty

```markdown
# Queue Processing

No pending items in queue. Nothing to process.

**Queue stats:**
- Total processed: 242
- Total failed: 1
- Total expired: 8

*Queue items are added automatically by session hooks.*
*Use `/secretary:status queue` for detailed queue view.*
```

### When Items Fail

```markdown
# Queue Processing Complete

**Processed:** 10 items
**Failed:** 2 items

## Failed Items

| ID | Type | Error | Attempts |
|----|------|-------|----------|
| 301 | user_prompt | AI extraction timeout | 3/3 |
| 305 | tool_output | JSON parse error | 3/3 |

*Failed items (3/3 attempts) will not be retried.*
*Items with < 3 attempts will be retried on next processing run.*
```

## Notes

- The `process-queue.sh` script processes items in priority order (1=highest, 10=lowest), then FIFO within same priority
- Items with 3+ failed attempts are marked as permanently failed
- Queue items older than their `ttl_hours` (default 24h) are expired by the worker
- For regular automatic processing, use `/secretary:cron setup` to install the background worker
- The inline flag prevents vault sync and GitHub refresh for faster processing
