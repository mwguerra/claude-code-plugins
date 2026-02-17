# Secretary

A queue-based personal workflow assistant for Claude Code. Captures decisions, commitments, ideas, and session data via ultra-fast hooks (< 50ms), processes them in a background worker with AI extraction, and syncs everything to an Obsidian vault.

## Why Secretary?

The predecessor plugin (`my-workflow`) made Claude Code noticeably slow — each PostToolUse event triggered 3 independent AI calls on the **same text** (up to 60s of blocking), and Stop/SessionEnd fired identical scripts, doubling session-end processing.

Secretary replaces all of that with a **"Capture Fast, Process Later"** architecture:

| Event | my-workflow (old) | Secretary (new) |
|-------|------------------|-----------------|
| PostToolUse(Bash) | 45-75s (3x AI + vault + DB) | **< 50ms** (1 SQLite INSERT) |
| PostToolUse(Edit/Write) | 30-60s (3x AI + vault) | **< 30ms** (1 SQLite INSERT) |
| UserPromptSubmit | 30s (AI + vault + DB) | **< 20ms** (1 SQLite INSERT) |
| Stop | 140s (Sonnet + Haiku + git) | **< 50ms** (1 INSERT + UPDATE) |
| SessionEnd | 140s (duplicate of Stop) | **< 50ms** (dedup check + INSERT) |
| SessionStart | 90s (git sync + briefing) | **< 15s** (SQL queries + time-boxed processing) |
| **AI calls per tool use** | **3 (triplicate)** | **0 (deferred to worker)** |

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         Claude Code Hooks        │
                    │  SessionStart  UserPromptSubmit  │
                    │  PostToolUse   SubagentStop      │
                    │  Stop          SessionEnd        │
                    └──────────────┬──────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────┐
                    │         capture.sh (< 50ms)      │
                    │    SQLite INSERT into queue       │
                    │    (WAL mode for concurrency)     │
                    └──────────────┬──────────────────┘
                                   │
                                   ▼
                    ┌─────────────────────────────────┐
                    │     queue table (SQLite)          │
                    │  Pending items wait for worker    │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────┼──────────────────┐
                    │              │                    │
                    ▼              ▼                    ▼
             ┌────────────┐ ┌──────────┐ ┌──────────────────┐
             │  worker.sh  │ │ Session  │ │  /secretary:     │
             │  (cron 5m)  │ │  Start   │ │  process         │
             │  up to 50   │ │ (inline  │ │  (manual trigger)│
             │  items/run   │ │  10 max) │ │                  │
             └──────┬─────┘ └──────────┘ └──────────────────┘
                    │
         ┌──────────┼──────────┐
         ▼          ▼          ▼
    ┌─────────┐ ┌────────┐ ┌─────────┐
    │    AI    │ │ Vault  │ │  Git    │
    │Extract  │ │ Notes  │ │  Sync   │
    │(1 call  │ │(.md)   │ │(commit  │
    │per item)│ │        │ │ +push)  │
    └────┬────┘ └────┬───┘ └────┬────┘
         │           │          │
         ▼           ▼          ▼
    ┌─────────┐ ┌────────┐ ┌─────────┐
    │decisions│ │Obsidian│ │ Remote  │
    │ideas/   │ │vault/  │ │ repo    │
    │commits  │ │secrty/ │ │         │
    └─────────┘ └────────┘ └─────────┘
```

### How It Works

1. **Every hook event** (user prompt, tool use, stop, etc.) calls `capture.sh` which does a single SQLite INSERT into the `queue` table. This completes in under 50ms — no AI, no network, no file I/O beyond the DB write.

2. **A background worker** (`worker.sh`) runs every 5 minutes via cron. It processes pending queue items: extracts decisions/ideas/commitments with a **single AI call per item** (not 3 like before), creates Obsidian vault notes, syncs to git.

3. **At session start**, if unprocessed items exist, a time-boxed (5s) inline processing handles up to 10 items. A SQL-only briefing (no AI) shows your commitments, recent decisions, goals, and GitHub items.

4. **No cron? Still works.** Queue items accumulate and get processed at the next session start (time-boxed) or via `/secretary:process`.

## Requirements

### Required
- **sqlite3** — Database engine (pre-installed on most systems)
- **jq** — JSON processing (required for hook data parsing)

### Optional
- **sqlcipher** — AES-256 encryption for the memory database
- **flock** — File locking for cron worker (Linux built-in, macOS via `brew install flock`)
- **timeout** — Process timeout for cron safety (Linux built-in, macOS via `brew install coreutils`)
- **gh** — GitHub CLI for issue/PR tracking in briefings

### Installation

#### Ubuntu / Debian
```bash
sudo apt-get install sqlite3 jq
# Optional:
sudo apt-get install sqlcipher
```

#### macOS
```bash
brew install sqlite3 jq
# Optional:
brew install sqlcipher flock coreutils
```

#### Windows (Git Bash / MSYS2)
```bash
choco install sqlite jq
# Or via MSYS2: pacman -S sqlite3 jq
```

## Quick Start

1. **Initialize the plugin:**
   ```
   /secretary:init
   ```
   This creates the databases, config file, vault structure, and encryption key. If `my-workflow` data exists, it offers to migrate.

2. **Set up the background worker (recommended):**
   ```
   /secretary:cron setup
   ```
   Installs a cron job that runs every 5 minutes to process the queue.

3. **Start working!** The hooks automatically capture everything. Use these commands:
   - `/secretary:status` — Dashboard with session info, queue depth, commitments, goals
   - `/secretary:briefing` — Manual briefing (same as session start)
   - `/secretary:track` — Manage commitments (add, complete, defer, list)
   - `/secretary:goals` — Manage goals with progress tracking
   - `/secretary:review` — Weekly/monthly productivity reviews
   - `/secretary:memory` — Encrypted memory for sensitive data
   - `/secretary:process` — Manually trigger queue processing
   - `/secretary:sync` — Force vault sync + git push
   - `/secretary:patterns` — View detected behavior patterns

## File Structure

```
secretary/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest
├── hooks/
│   ├── hooks.json                     # All events → capture.sh
│   └── scripts/
│       ├── capture.sh                 # THE single hook (< 50ms)
│       └── lib/
│           ├── utils.sh               # Dates, paths, config, escaping
│           ├── db.sh                  # ensure_db, db_exec, queue_item
│           └── git-detect.sh          # Fast git commit detection
├── scripts/
│   ├── worker.sh                      # Cron entry point
│   ├── process-queue.sh               # Queue item processing
│   ├── ai-extract.sh                  # AI extraction (1 call/item)
│   ├── briefing.sh                    # SQL-only briefing generator
│   ├── vault-sync.sh                  # Create vault markdown notes
│   ├── vault-git-sync.sh             # Git commit+push for vault
│   ├── memory-manager.sh             # Encrypted memory operations
│   └── install-cron.sh               # Cron setup helper
├── commands/                          # 11 slash commands (*.md)
├── agents/                            # 3 agents (secretary, executive, assistant)
├── skills/                            # 3 skills with SKILL.md
├── schemas/
│   ├── secretary.sql                  # Main database (15+ tables, FTS5)
│   ├── memory.sql                     # Encrypted memory schema
│   └── config.schema.json             # Configuration JSON schema
├── config/
│   └── secretary.example.json         # Example configuration
├── tests/
│   ├── test-capture.sh                # Hook timing tests
│   ├── test-worker.sh                 # Queue processing tests
│   └── test-queue.sh                  # Schema & DB tests
└── README.md
```

## Two Databases

### Main: `~/.claude/secretary/secretary.db`

SQLite with WAL mode. Contains all workflow data:

| Table | Purpose |
|-------|---------|
| `queue` | Raw captured events, pending/processed status |
| `sessions` | Session records with summary, commits, duration |
| `commitments` | Action items with priority, due dates, status (FTS5) |
| `decisions` | Architecture/process decisions with rationale (FTS5) |
| `ideas` | Idea backlog with type, effort, impact (FTS5) |
| `goals` | Objectives with progress tracking |
| `patterns` | Detected behavior patterns |
| `knowledge_nodes` / `knowledge_edges` | Knowledge graph (FTS5) |
| `activity_timeline` | Unified activity log |
| `daily_notes` | Daily summaries and planning |
| `github_cache` | Cached GitHub issues/PRs |
| `worker_state` | Worker run stats |

### Memory: `~/.claude/secretary/memory.db`

Encrypted with **SQLCipher** (AES-256) when available. Falls back to plain sqlite3 with a warning.

| Table | Purpose |
|-------|---------|
| `memory` | Sensitive data (credentials, IPs, secrets) |
| `memory_fts` | Full-text search on title, content, tags |
| `memory_access_log` | Audit trail of all reads/writes |

The encryption key is auto-generated during `/secretary:init` and stored in `~/.claude/secretary/auth.json` (chmod 600).

## Obsidian Vault Integration

Secretary creates structured markdown notes in your Obsidian vault:

```
vault/secretary/
├── daily/          # YYYY-MM-DD.md — daily work logs
├── sessions/       # Session summaries with commits and duration
├── decisions/      # D-XXXX.md — decisions with rationale
├── commitments/    # C-XXXX.md — action items with status
├── ideas/          # I-XXXX.md — idea backlog with assessment
├── goals/          # G-XXXX.md — goals with progress
├── reviews/        # Weekly/monthly productivity reviews
├── patterns/       # Behavior observations
└── index.md        # Dashboard linking all sections
```

Entity IDs are used as filenames (e.g., `D-0001.md`) — no AI calls needed for note creation.

Reads vault path from `~/.claude/obsidian-vault.json` (shared with the obsidian-vault plugin).

## Background Worker

### Cron Entry (installed by `/secretary:cron setup`)

```
*/5 * * * * flock -n /tmp/secretary-worker.lock timeout 120 bash ~/.claude/plugins/secretary/scripts/worker.sh >> ~/.claude/secretary/worker.log 2>&1
```

- **`flock -n`** — Non-blocking lock. If another worker is running, exit immediately.
- **`timeout 120`** — Hard kill after 2 minutes. Prevents runaway processes.

### Worker Flow

1. Process up to 50 pending queue items (AI extraction, DB inserts)
2. Sync vault notes to git if changes exist (single commit+push)
3. Refresh GitHub cache if expired
4. Expire old queue items (> 24h unprocessed)

### No Cron Fallback

If cron is never set up:
1. Queue items accumulate
2. At each session start, 5-second time-boxed processing handles up to 10 items
3. `/secretary:process` triggers the worker manually

## Data Migration

`/secretary:init` detects `~/.claude/my-workflow/workflow.db` and offers to migrate all data:
- Sessions, commitments, decisions, ideas, goals, patterns
- Knowledge graph (nodes + edges)
- Activity timeline, daily notes, GitHub cache
- All entity IDs preserved (C-XXXX, D-XXXX, etc.)

Both plugins can coexist during transition (different DB paths).

## Commands Reference

| Command | Description |
|---------|-------------|
| `/secretary:init` | Initialize databases, config, vault, encryption key |
| `/secretary:status` | Dashboard: session, queue, commitments, goals, activity |
| `/secretary:briefing` | Manual briefing (same as session start) |
| `/secretary:track` | Commitment CRUD: add, complete, defer, edit, delete, list |
| `/secretary:review` | Weekly/monthly reviews with metrics |
| `/secretary:goals` | Goal CRUD: add, update-progress, complete, abandon |
| `/secretary:memory` | Encrypted memory: add, search, list, show, delete |
| `/secretary:process` | Manually trigger queue processing |
| `/secretary:sync` | Force vault sync + external change detection |
| `/secretary:cron` | Setup/check/remove background worker cron job |
| `/secretary:patterns` | View and analyze detected behavior patterns |

## Testing

Run the test suite:

```bash
# Hook performance tests (must be < 100ms)
bash secretary/tests/test-capture.sh

# Queue and schema tests
bash secretary/tests/test-queue.sh

# Worker and processing tests
bash secretary/tests/test-worker.sh
```

## Configuration

Config file: `~/.claude/secretary.json`

See `config/secretary.example.json` for all available options:

```json
{
  "briefing": {
    "showOnStart": true,
    "includePendingCommitments": true,
    "includeRecentDecisions": true,
    "includeGoalProgress": true,
    "includeGitHub": true,
    "daysBack": 7
  },
  "ai": {
    "enabled": true,
    "model": "haiku",
    "maxBudget": "0.50"
  },
  "vault": {
    "enabled": true,
    "secretaryFolder": "secretary"
  },
  "worker": {
    "cronEnabled": true,
    "maxItemsPerRun": 50,
    "retryLimit": 3
  },
  "memory": {
    "enabled": true
  }
}
```

## Cross-Platform Support

Secretary works on:
- **Linux** (Ubuntu, Debian, Fedora, Arch) — full support including flock and timeout
- **macOS** — full support, optional `brew install flock coreutils` for cron safety
- **Windows** (Git Bash / MSYS2) — core functionality, Task Scheduler for background worker

Platform detection is automatic. Date functions, process detection, and file operations all have cross-platform implementations.

## License

MIT
