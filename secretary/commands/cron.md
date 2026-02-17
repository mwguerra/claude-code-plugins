---
name: cron
description: Setup, check, or remove the background worker cron job for automatic queue processing and vault sync
allowed-tools: Read, Bash, Glob, Grep
argument-hint: "<setup|status|remove>"
---

# Secretary Cron Command

Manage the background worker cron job that automatically processes the queue, syncs the vault to git, refreshes the GitHub cache, and expires old queue items every 5 minutes.

## Usage

```
/secretary:cron                    # Show cron status (default)
/secretary:cron status             # Same as above
/secretary:cron setup              # Install the cron job
/secretary:cron remove             # Remove the cron job
```

## Script Location

```bash
CRON_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/install-cron.sh"
```

## Delegate to install-cron.sh

All operations delegate to the `scripts/install-cron.sh` script:

```bash
bash "$CRON_SCRIPT" "$ACTION"
```

Where `$ACTION` is `setup`, `status`, or `remove`.

## Setup Action

Installs a cron job that runs the worker every 5 minutes.

```bash
bash "$CRON_SCRIPT" setup
```

### What It Does

1. **Checks dependencies** (sqlite3, jq) and reports any missing ones with install instructions per platform:
   - Ubuntu/Debian: `sudo apt-get install <package>`
   - macOS: `brew install <package>`
   - Windows: `choco install <package>`

2. **Checks optional tools** (flock, timeout) and warns if missing:
   - `flock` prevents overlapping worker runs (macOS: `brew install flock`)
   - `timeout` kills runaway processes (macOS: `brew install coreutils`)

3. **Creates the cron entry** (Linux/macOS):

```
*/5 * * * * flock -n /tmp/secretary-worker.lock timeout 120 bash ~/.claude/plugins/secretary/scripts/worker.sh >> ~/.claude/secretary/worker.log 2>&1 # secretary-worker
```

4. **For Windows**, provides Task Scheduler instructions:

```
schtasks /create /tn "SecretaryWorker" /tr "bash <worker-path>" /sc minute /mo 5
```

### What the Worker Does (Every 5 Minutes)

1. **Process queue** - Up to 50 pending items (AI extraction, DB inserts)
2. **Vault git sync** - Commit and push vault changes (if > 15 min since last sync)
3. **GitHub cache refresh** - Fetch assigned issues, PRs, reviews (if cache expired)
4. **Expire old items** - Mark queue items past their TTL as expired
5. **Record state** - Update `worker_state` table with run stats

### Setup Output

```markdown
# Secretary Cron Setup

**Status:** Installed successfully

## Configuration

| Setting | Value |
|---------|-------|
| Schedule | Every 5 minutes |
| Worker | ~/.claude/plugins/secretary/scripts/worker.sh |
| Log | ~/.claude/secretary/worker.log |
| Lock | /tmp/secretary-worker.lock |
| Timeout | 120 seconds |

## Safety Features

- **File lock** (flock): Prevents overlapping runs
- **Timeout** (120s): Kills runaway processes
- **Retry limit**: Queue items fail after 3 attempts
- **TTL expiry**: Stale items auto-expire after 24 hours

## Next Steps

The worker will run automatically every 5 minutes.
Use `/secretary:cron status` to verify it is running.
Use `/secretary:status queue` to monitor queue depth.
```

## Status Action

Check whether the cron job is installed and show worker health:

```bash
bash "$CRON_SCRIPT" status
```

### Status Output

```markdown
# Secretary Cron Status

## Cron Job

**Status:** ACTIVE
**Entry:** */5 * * * * flock -n /tmp/secretary-worker.lock timeout 120 bash ...worker.sh >> ...worker.log 2>&1 # secretary-worker

## Worker State

| Metric | Value |
|--------|-------|
| Last Run | 2024-02-17 14:40 (3 min ago) |
| Last Success | 2024-02-17 14:40 |
| Total Runs | 28 |
| Items Processed | 142 |
| Last Error | None |
| Last Vault Sync | 2024-02-17 14:25 |
| Last GitHub Refresh | 2024-02-17 14:30 |

## Recent Worker Log

[2024-02-17T14:40:00Z] Processing 3 pending queue items...
[2024-02-17T14:40:02Z] Worker completed: 3 items processed
[2024-02-17T14:35:00Z] No pending items in queue
[2024-02-17T14:30:00Z] Refreshing GitHub cache...
[2024-02-17T14:25:00Z] Syncing vault to git...
```

### Status When Not Installed

```markdown
# Secretary Cron Status

## Cron Job

**Status:** NOT INSTALLED

Run `/secretary:cron setup` to install the background worker.

Without the cron job, you can still process the queue manually with `/secretary:process`.
```

## Remove Action

Remove the cron job and clean up:

```bash
bash "$CRON_SCRIPT" remove
```

### Remove Output

```markdown
# Secretary Cron Removed

**Cron job:** Removed
**Lock file:** Cleaned up

The background worker will no longer run automatically.
Use `/secretary:process` to process the queue manually.
Use `/secretary:cron setup` to reinstall.
```

## Platform Support

| Platform | Method | Notes |
|----------|--------|-------|
| Linux | crontab | Full support with flock + timeout |
| macOS | crontab | flock needs `brew install flock`, timeout needs `brew install coreutils` |
| Windows | Task Scheduler | Manual setup via schtasks or GUI |

## Troubleshooting

If the worker appears to not be running:

1. **Check cron status**: `/secretary:cron status`
2. **Check worker log**: `tail -20 ~/.claude/secretary/worker.log`
3. **Check debug log**: `tail -20 ~/.claude/secretary/debug.log` (if SECRETARY_DEBUG=true)
4. **Run manually**: `bash ~/.claude/plugins/secretary/scripts/worker.sh`
5. **Check lock file**: `ls -la /tmp/secretary-worker.lock` (stale lock can block runs)
6. **Remove stale lock**: `rm /tmp/secretary-worker.lock`
