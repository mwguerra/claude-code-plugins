# Docker-Local Plugin Redesign

**Date:** 2026-01-27
**Status:** Approved
**Author:** Marcelo Guerra

## Overview

Redesign the docker-local Claude Code plugin from scratch. The current plugin has scattered skills/commands and poor troubleshooting logic (e.g., tries complex solutions before simple ones, sometimes modifies application code unnecessarily).

### Goals

1. **Focused troubleshooting** - Fix access issues (404, SSL, DNS) with a strict diagnostic hierarchy
2. **Health checking** - Quick verification that everything is working
3. **Project setup** - Add new or manually cloned projects to docker-local
4. **Predictable behavior** - Never modify application code, confirm before fixing

### Non-Goals

- Database management (backup/restore) - rarely needed
- Log viewing - can use CLI directly
- General Docker management - docker-local handles this

## Plugin Structure

```
docker-local/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── agents/
│   └── docker-local-agent.md    # Single focused agent
└── skills/
    └── docker-local-reference/
        ├── SKILL.md             # Reference skill loader
        └── reference.md         # Architecture & commands reference
```

**Key decision:** One focused agent instead of multiple scattered skills/commands.

## Diagnostic Hierarchy

When troubleshooting access issues, the agent follows this strict order (simple → complex):

### Step 1: Identify the Problem

Ask: "What URL are you trying to access?" (e.g., `myapp.test` or `api.myapp.test`)

### Step 2: Container Check (fastest)

```bash
docker-local status
```

- If containers down → `docker-local up`
- If unhealthy → `docker-local restart`

### Step 3: DNS Resolution Check

```bash
ping -c 1 myapp.test
```

- Should resolve to `127.0.0.1`
- If not → Check dnsmasq config or `/etc/hosts`
- **Sudo required** → Present command to user, verify after they run it

### Step 4: Project Linking Check

```bash
ls -la ~/projects/.docker-local-links/ | grep myapp
ls -la ~/projects/myapp/public/index.php
```

- If symlink missing → `docker-local link`
- If project directory wrong → Guide user to correct location

### Step 5: SSL Certificate Check

```bash
docker-local ssl:status
curl -I https://myapp.test 2>&1 | head -5
```

- If cert errors → `docker-local ssl:regenerate`
- If mkcert not installed → **Sudo required** for `mkcert -install`

### Step 6: Nginx Routing Check

```bash
docker-local logs nginx | tail -20
```

- Check for 404/500 errors in nginx logs
- Verify project's `public/` directory exists

**Rule:** Never jump ahead. Complete each step before moving to the next.

## Health Check

When user asks "is docker-local working?" or requests a health check:

```bash
docker-local doctor
```

### Output Format

Success:
```
✓ Docker running
✓ All 8 containers healthy
✓ DNS resolving *.test → 127.0.0.1
✓ SSL certificates valid
✓ No port conflicts

All systems operational.
```

Issues found:
```
✓ Docker running
✗ Container 'php' unhealthy
✓ DNS resolving
⚠ SSL certificate expires in 3 days

Found 1 error, 1 warning. Want me to fix these?
```

## Project Setup

### New Laravel Project

User: "Create a new Laravel project called myapp"

```bash
docker-local make:laravel myapp
```

Automatically creates:
- Project in `~/projects/myapp`
- MySQL database `myapp`
- MinIO bucket `myapp`
- `.env` with unique Redis DBs, cache prefix
- Symlink in `.docker-local-links`

Agent verifies setup:
```bash
curl -I https://myapp.test
```

### Manually Cloned Project

User: "I cloned a project to ~/projects/myapp, set it up"

Agent workflow:

1. **Verify project exists**
   ```bash
   ls ~/projects/myapp/artisan
   ```

2. **Run link command**
   ```bash
   docker-local link
   ```

3. **Check/create database**
   ```bash
   docker-local db:create myapp
   ```

4. **Check .env configuration**
   - Verify docker-local credentials: `DB_HOST=mysql`, `REDIS_HOST=redis`
   - Verify `APP_URL=https://myapp.test`
   - Check for Redis DB conflicts
   - If issues → suggest fixes or run `docker-local env:check`

5. **Run migrations** (with confirmation)
   ```bash
   docker-local db:fresh
   ```

6. **Verify access**
   ```bash
   curl -I https://myapp.test
   ```

### Required .env Settings

```bash
APP_URL=https://myapp.test
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=myapp
DB_USERNAME=laravel
DB_PASSWORD=secret

REDIS_HOST=redis
REDIS_PORT=6379

MAIL_HOST=mailpit
MAIL_PORT=1025

AWS_ENDPOINT=http://minio:9000
AWS_ACCESS_KEY_ID=minio
AWS_SECRET_ACCESS_KEY=minio123
AWS_BUCKET=myapp
AWS_USE_PATH_STYLE_ENDPOINT=true
```

## Agent Behavior Rules

### Core Rules

1. **Never modify application code**
   - Don't touch PHP, JS, routes, controllers
   - Only modify `.env` files when fixing docker-local settings
   - Only run docker-local CLI commands

2. **Follow diagnostic order strictly**
   - Complete each step before moving to next
   - Don't skip to "advanced" solutions

3. **Confirm before fixing**
   - Explain what's wrong
   - Show the command that will fix it
   - Wait for user confirmation

4. **Sudo commands = manual execution**
   - Present the command to the user
   - Ask them to run it
   - Verify the result after they confirm

5. **Verify after every fix**
   - After each fix, test if the issue is resolved
   - Don't assume success

6. **One problem at a time**
   - If multiple issues found, fix in order of diagnostic hierarchy
   - Don't overwhelm with all problems at once

### Agent Triggers

The agent activates when user mentions:
- Site not working, 404, 502, can't reach
- SSL/certificate errors
- DNS not resolving
- docker-local, containers, services
- "Set up project", "add project to docker-local"
- "Is docker-local working?", "check status"

## Reference Documentation

The agent has access to a compact reference with:

### Service Credentials (defaults)

| Service    | Host     | Port | User   | Password  |
|------------|----------|------|--------|-----------|
| MySQL      | mysql    | 3306 | laravel| secret    |
| PostgreSQL | postgres | 5432 | laravel| secret    |
| Redis      | redis    | 6379 | -      | -         |
| Mailpit    | mailpit  | 1025 | -      | -         |
| MinIO      | minio    | 9000 | minio  | minio123  |

### URLs

- Projects: `https://{project}.test`
- Subdomains: `https://{sub}.{project}.test`
- Traefik: `https://traefik.localhost:8080`
- Mailpit: `https://mail.localhost`
- MinIO: `https://minio.localhost`

### Key Commands

```bash
docker-local status          # Check all services
docker-local doctor          # Full health check
docker-local link            # Rescan and link projects
docker-local make:laravel X  # Create new project
docker-local ssl:status      # Check certificates
docker-local ssl:regenerate  # Regenerate certs
docker-local db:create X     # Create database
docker-local env:check       # Check .env conflicts
docker-local fix             # Auto-fix common issues
```

### Project Structure

```
~/projects/                      # Projects root
~/projects/.docker-local-links/  # Symlinks for Nginx routing
~/.config/docker-local/          # Config directory
~/.config/docker-local/certs/    # SSL certificates
```

## Implementation Plan

1. **Delete current plugin content** (preserve plugin.json metadata)
2. **Create new agent** (`agents/docker-local-agent.md`)
3. **Create reference skill** (`skills/docker-local-reference/`)
4. **Test with real scenarios**:
   - 404 on existing project (linking issue)
   - SSL certificate error
   - New project setup
   - Cloned project setup
5. **Commit and push**

## Success Criteria

- Agent fixes a 404 linking issue without trying complex solutions first
- Agent never modifies application code
- Agent presents sudo commands for manual execution
- Agent verifies fixes work before declaring success
- Health check provides clear, actionable output
