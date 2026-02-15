---
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, AskUserQuestion, Task
argument-hint: "<ask|quick|premortem|review|compass|history|followup|init|config|help> [args...]"
description: Personal advisory council for life and business decisions
---

# Board Command

You are implementing the `board` command - a personal advisory council system.

## Purpose

Simulate a Board of Advisors with four pillar councils (Intelligence, Business, Life, Security), a Council Head (orchestrator), and a Master of Councils (synthesizer). All decisions are persisted in SQLite for outcome tracking and pattern analysis.

## Routing

Parse the first argument to determine the subcommand:

- `board ask "question" [--mode standard|conflict|ultra] [--urgency low|medium|high|emergency]` - Full deliberation
- `board quick "question"` - Fast 5-minute decision (quick mode, concise output)
- `board premortem "decision that was made"` - Assume failure, analyze why
- `board review [weekly|monthly|quarterly]` - Periodic CEO review
- `board compass` - Life direction check
- `board history [--last N] [--type TYPE] [--stats] [--patterns]` - View past decisions
- `board followup <decision-id> [--outcome success|partial|fail] [--notes "what happened"]` - Record outcome
- `board init` - Initialize `.board/` directory and database
- `board config [show|weights|mode|councils]` - View/change configuration
- `board help` - Show board structure, all council members, and a worked example

## Database Location

All operations use the SQLite database at `.board/board.db`.

## Pre-check

Before any subcommand (except `init`), verify the database exists:

```bash
DB=".board/board.db"
if [[ ! -f "$DB" ]]; then
    echo "Error: Board not initialized. Run board:board init first."
    exit 1
fi
```

---

## Subcommand: `init`

Initialize the `.board/` directory with SQLite database.

### Check for existing installation

```bash
if [[ -d ".board" ]] && [[ -f ".board/board.db" ]]; then
    VERSION=$(sqlite3 .board/board.db "SELECT version FROM schema_version ORDER BY applied_at DESC LIMIT 1;" 2>/dev/null)
    if [[ "$VERSION" == "1.0.0" ]]; then
        echo "Board already initialized (v1.0.0)"
        # Show summary
        DECISIONS=$(sqlite3 .board/board.db "SELECT COUNT(*) FROM decisions;")
        echo "Decisions recorded: $DECISIONS"
        exit 0
    fi
fi
```

### Create fresh installation

```bash
# Create directory structure
mkdir -p .board/logs

# Create database with schema
sqlite3 .board/board.db < "$PLUGIN_DIR/schemas/schema.sql"

# Load default config into database
# Read default-config.json and insert each key-value pair
sqlite3 .board/board.db "INSERT OR REPLACE INTO config (key, value) VALUES
    ('weights.intelligence', '25'),
    ('weights.business', '25'),
    ('weights.life', '25'),
    ('weights.security', '25'),
    ('defaults.mode', 'standard'),
    ('defaults.urgency', 'medium'),
    ('councils.intelligence', 'true'),
    ('councils.business', 'true'),
    ('councils.life', 'true'),
    ('councils.security', 'true'),
    ('features.auto_research', 'true'),
    ('features.record_decisions', 'true');"

# Initialize log file
touch .board/logs/activity.log

# Log initialization
echo "$(date -Iseconds) [DECISION] [init] Initialized Board Advisory Council v1.0.0 (SQLite)" >> .board/logs/activity.log
```

### Report to user

```
Board Advisory Council initialized! (v1.0.0)

Created:
  .board/
  ├── board.db          # SQLite database (decisions, reviews, stats)
  └── logs/
      └── activity.log  # Activity log

Councils:
  - Intelligence Council (tech, systems, knowledge)
  - Business Council (revenue, market, viability)
  - Life Council (health, family, meaning)
  - Security Council (risk, legal, continuity)

Quick start:
  1. board:board ask "Should I invest 3 months building a SaaS?"
  2. board:board quick "Should I take this meeting?"
  3. board:board history --stats
  4. board:board config show
```

---

## Subcommand: `ask`

Full advisory deliberation.

### Parse arguments

- Extract the question (required)
- Parse `--mode` flag (default: read from config `defaults.mode`)
- Parse `--urgency` flag (default: read from config `defaults.urgency`)

### Phase 1: Council Head

Use the Task tool to launch the `council-head` agent with:

```
Analyze this question for the Board of Advisors:

Question: "[user's question]"
Mode: [standard|conflict|ultra]
Urgency: [low|medium|high|emergency]

Follow the Council Head protocol:
1. Strip emotion, restate cleanly
2. Classify decision type
3. Determine urgency
4. Select which councils to consult
5. Ask clarifying questions if needed (use AskUserQuestion)
6. Define evaluation criteria

Return your briefing in the specified format.
```

### Phase 2: Council Deliberation

Based on the Council Head's briefing, launch the required council agents. Launch councils in parallel when possible (up to 2 at a time to respect the max-3-agents rule).

For each required council, use the Task tool to launch the appropriate agent:

```
You are deliberating for the Board of Advisors.

## Council Head Briefing
[paste Council Head briefing]

## Question
[user's question]

## Mode
[standard|conflict|ultra|quick]

## Your Task
Deliver your verdict following your council's protocol and output format.
```

### Phase 3: Master Synthesis

Once all councils have reported, use the Task tool to launch the `master-of-councils` agent:

```
You are the Master of Councils. Synthesize the following verdicts into a final recommendation.

## Council Head Briefing
[paste Council Head briefing]

## Council Verdicts
[paste all council verdicts]

## Configured Weights
[read from config]

## Your Task
1. Create the verdict matrix
2. Find consensus and conflicts
3. Surface critical tradeoffs
4. Define success conditions
5. Make your recommendation
6. Output in the Decision Record format

Decision ID: [next DEC-XXX from database]
```

### Phase 4: Record Decision

After synthesis, persist everything to SQLite:

```bash
# Get next decision ID
NEXT_ID=$(sqlite3 .board/board.db "SELECT 'DEC-' || printf('%03d', COALESCE(MAX(CAST(SUBSTR(id, 5) AS INTEGER)), 0) + 1) FROM decisions;")

# Insert decision record
sqlite3 .board/board.db "INSERT INTO decisions (
    id, question, context, clean_problem, decision_type, urgency, mode,
    councils_consulted, intelligence_verdict, business_verdict, life_verdict, security_verdict,
    consensus_points, conflict_points, critical_tradeoffs, success_conditions,
    master_recommendation, master_confidence, risk_level, next_action, outcome
) VALUES (
    '$NEXT_ID',
    '<question>',
    '<context>',
    '<clean_problem>',
    '<type>', '<urgency>', '<mode>',
    '<councils_json>',
    '<intel_json>', '<biz_json>', '<life_json>', '<sec_json>',
    '<consensus_json>', '<conflicts_json>', '<tradeoffs_json>', '<conditions_json>',
    '<recommendation>',
    '<confidence>', '<risk_level>', '<next_action>',
    'pending'
);"

# Log the decision
echo "$(date -Iseconds) [DECISION] [ask] Recorded decision $NEXT_ID: <question_summary>" >> .board/logs/activity.log
```

### Display to User

Show the full Decision Record from the Master of Councils in formatted markdown.

---

## Subcommand: `quick`

Fast 5-minute decision. Internally calls `ask` with `--mode quick`.

- Council Head: abbreviated analysis, pick only 1-2 councils
- Councils: top 2-3 points only, no deep research
- Master: straight to recommendation, skip detailed council summaries
- Still records the decision to SQLite

---

## Subcommand: `premortem`

Post-decision failure analysis.

1. Accept the decision statement (what was already decided)
2. Set mode to `premortem`
3. Run through all 4 councils with the prompt: "It's 2 years from now. This decision was made and it failed catastrophically. Explain why it failed from your council's perspective."
4. Master synthesizes a unified failure narrative
5. Record as a decision with type matching the original and mode `premortem`

---

## Subcommand: `review`

Periodic CEO review. Types: `weekly`, `monthly`, `quarterly`.

### Behavior

```bash
# Determine review period
REVIEW_TYPE="${1:-weekly}"

case "$REVIEW_TYPE" in
    weekly)
        PERIOD_START=$(date -d "7 days ago" -Iseconds 2>/dev/null || date -v-7d -Iseconds)
        ;;
    monthly)
        PERIOD_START=$(date -d "30 days ago" -Iseconds 2>/dev/null || date -v-30d -Iseconds)
        ;;
    quarterly)
        PERIOD_START=$(date -d "90 days ago" -Iseconds 2>/dev/null || date -v-90d -Iseconds)
        ;;
esac
```

1. Query all decisions in the review period
2. Analyze patterns: most common decision types, council agreement rates, outcome distribution
3. Identify: decisions still pending outcome, decisions that went well/poorly
4. Generate action items for the next period
5. Save the review to the `reviews` table

### Output

```markdown
## Board Review - [Weekly|Monthly|Quarterly]
### Period: [start] to [end]

### Decisions Made: N
[Summary table of decisions, outcomes, and council accuracy]

### Patterns Identified
- [Pattern 1]
- [Pattern 2]

### Open Items
- [Decisions still pending outcome]

### Action Items for Next Period
1. [Action 1]
2. [Action 2]
```

---

## Subcommand: `compass`

Life direction check. A special review that goes beyond recent decisions to examine overall trajectory.

1. Query ALL decisions (not just recent)
2. Analyze: decision type distribution over time, what councils are most consulted, what areas of life are getting the most/least attention
3. Identify blind spots: areas with no decisions (are you avoiding something?)
4. Generate a "Life Direction" assessment

### Output

```markdown
## Life Compass

### Decision Distribution
| Area | Count | % | Trend |
|------|-------|---|-------|
| Strategic | N | X% | up/down/stable |
| Financial | N | X% | up/down/stable |
| Career | N | X% | up/down/stable |
| Technical | N | X% | up/down/stable |
| Personal | N | X% | up/down/stable |

### Where You're Focusing
[Areas getting the most attention]

### Blind Spots
[Areas getting neglected - potential hidden risks]

### Council Accuracy
| Council | Accuracy | Strongest Area | Weakest Area |
|---------|----------|---------------|-------------|
| Intelligence | X% | [type] | [type] |
| Business | X% | [type] | [type] |
| Life | X% | [type] | [type] |
| Security | X% | [type] | [type] |

### Direction Assessment
[Overall assessment of life trajectory based on decision patterns]

### Recommended Focus
[What should get more attention in the coming period]
```

---

## Subcommand: `history`

View past decisions and analytics.

### Flags

- `--last N` - Show last N decisions (default: 10)
- `--type TYPE` - Filter by decision type
- `--stats` - Show aggregate statistics
- `--patterns` - Show pattern analysis (requires 5+ decisions with outcomes)

### `history` (default)

```bash
sqlite3 -column -header .board/board.db "
SELECT id, substr(question, 1, 50) || '...' as question,
    decision_type, urgency, master_confidence, outcome,
    date(created_at) as date
FROM decisions
ORDER BY created_at DESC
LIMIT ${LAST:-10};"
```

### `history --stats`

```bash
sqlite3 -column -header .board/board.db "
SELECT
    COUNT(*) as total_decisions,
    SUM(CASE WHEN outcome = 'success' THEN 1 ELSE 0 END) as successful,
    SUM(CASE WHEN outcome = 'partial' THEN 1 ELSE 0 END) as partial,
    SUM(CASE WHEN outcome = 'fail' THEN 1 ELSE 0 END) as failed,
    SUM(CASE WHEN outcome = 'pending' OR outcome IS NULL THEN 1 ELSE 0 END) as pending
FROM decisions;"
```

Also show council stats from the `council_stats` table.

### `history --patterns`

Requires at least 5 decisions with recorded outcomes. Analyzes:
- Which council predicts reality best
- Which decision types have best/worst outcomes
- Whether high-confidence recommendations correlate with better outcomes
- User's blind spots (areas where outcomes are consistently worse than expected)

---

## Subcommand: `followup`

Record outcome for a past decision.

### Arguments

- `<decision-id>` - Required. e.g., "DEC-001"
- `--outcome success|partial|fail` - Required. How it turned out.
- `--notes "what happened"` - Optional. Details.

### Behavior

1. Verify the decision exists and outcome is 'pending'
2. If `--outcome` not provided, use AskUserQuestion to ask
3. Update the decision record
4. Update council accuracy scores

```bash
# Update decision
sqlite3 .board/board.db "UPDATE decisions SET
    outcome = '$OUTCOME',
    outcome_notes = '$NOTES',
    outcome_date = datetime('now'),
    updated_at = datetime('now')
WHERE id = '$DECISION_ID';"

# Update council accuracy based on whether their verdict aligned with outcome
# For each council that participated:
# - If council supported and outcome is success -> accurate (1)
# - If council opposed and outcome is fail -> accurate (1)
# - If council supported and outcome is fail -> inaccurate (0)
# - If council opposed and outcome is success -> inaccurate (0)
# - Partial outcomes: both get NULL (unclear)

# Then recalculate council_stats
sqlite3 .board/board.db "UPDATE council_stats SET
    total_consultations = (SELECT COUNT(*) FROM decisions WHERE councils_consulted LIKE '%intelligence%' AND outcome IS NOT NULL AND outcome != 'pending'),
    correct_predictions = (SELECT COUNT(*) FROM decisions WHERE intelligence_accurate = 1),
    accuracy_rate = CASE
        WHEN total_consultations > 0 THEN CAST(correct_predictions AS REAL) / total_consultations
        ELSE 0.0
    END,
    updated_at = datetime('now')
WHERE council = 'intelligence';"
-- (repeat for each council)
```

### Log

```bash
echo "$(date -Iseconds) [DECISION] [followup] Recorded outcome for $DECISION_ID: $OUTCOME" >> .board/logs/activity.log
```

---

## Subcommand: `config`

View and change configuration.

### `config show`

```bash
sqlite3 -column -header .board/board.db "SELECT key, value FROM config ORDER BY key;"
```

### `config weights [intelligence=N] [business=N] [life=N] [security=N]`

Update council weights. Values must sum to 100.

```bash
# Parse weight arguments
# Validate they sum to 100
# Update config table
sqlite3 .board/board.db "UPDATE config SET value = '$INTEL_WEIGHT', updated_at = datetime('now') WHERE key = 'weights.intelligence';"
# ... repeat for each
```

Use AskUserQuestion if weights are provided interactively.

### `config mode [standard|conflict|ultra]`

Set default deliberation mode.

```bash
sqlite3 .board/board.db "UPDATE config SET value = '$MODE', updated_at = datetime('now') WHERE key = 'defaults.mode';"
```

### `config councils [enable|disable] [council-name]`

Enable or disable a specific council.

```bash
sqlite3 .board/board.db "UPDATE config SET value = '$ENABLED', updated_at = datetime('now') WHERE key = 'councils.$COUNCIL';"
```

---

## SQLite Query Helpers

### Get next decision ID

```sql
SELECT 'DEC-' || printf('%03d', COALESCE(MAX(CAST(SUBSTR(id, 5) AS INTEGER)), 0) + 1)
FROM decisions;
```

### Get next review ID

```sql
SELECT 'REV-' || printf('%03d', COALESCE(MAX(CAST(SUBSTR(id, 5) AS INTEGER)), 0) + 1)
FROM reviews;
```

### Get config value

```sql
SELECT value FROM config WHERE key = 'weights.intelligence';
```

### Get all weights as JSON

```sql
SELECT json_object(
    'intelligence', (SELECT CAST(value AS INTEGER) FROM config WHERE key = 'weights.intelligence'),
    'business', (SELECT CAST(value AS INTEGER) FROM config WHERE key = 'weights.business'),
    'life', (SELECT CAST(value AS INTEGER) FROM config WHERE key = 'weights.life'),
    'security', (SELECT CAST(value AS INTEGER) FROM config WHERE key = 'weights.security')
);
```

---

## Logging

All significant actions are logged to `.board/logs/activity.log`:

```text
<timestamp> [<level>] [<command>] <message>
```

Levels: `DECISION`, `ERROR`

Examples:
```text
2026-02-15T10:00:00Z [DECISION] [init] Initialized Board Advisory Council v1.0.0
2026-02-15T10:05:00Z [DECISION] [ask] Recorded decision DEC-001: "Should I invest in SaaS?"
2026-02-15T10:10:00Z [DECISION] [followup] Recorded outcome for DEC-001: success
2026-02-15T10:15:00Z [ERROR] [ask] Failed to insert decision: UNIQUE constraint failed
```

---

## Important Notes

- Always JSON-escape strings before inserting into SQLite to prevent injection
- Council verdicts are stored as JSON strings in the database
- The `outcome` field starts as `'pending'` and is updated via `followup`
- Council accuracy is only calculated after outcomes are recorded
- Pattern analysis requires at least 5 decisions with non-pending outcomes
- In `quick` mode, the entire flow should be fast and concise - no deep research
- In `ultra` mode, ALL councils are consulted regardless of decision type
- The `premortem` mode assumes the decision was already made and failed
