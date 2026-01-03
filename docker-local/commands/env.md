---
description: Check and manage .env configuration - conflict detection, unique IDs
allowed-tools: Bash(docker-local:*), Read, Edit, Glob
argument-hint: "[check | fix | show] [--project path]"
---

# Docker-Local Environment Check

Verify .env configuration and detect conflicts.

## 0. Prerequisite Check

**FIRST, verify docker-local is installed:**

```bash
which docker-local > /dev/null 2>&1 && echo "docker-local: OK" || echo "docker-local: NOT INSTALLED"
```

**If NOT installed, ask user to install:**
```bash
composer global require mwguerra/docker-local
export PATH="$HOME/.composer/vendor/bin:$PATH"
docker-local init
```

## Check Current Project

```bash
docker-local env:check
```

Verifies:
- Service hostnames (mysql vs localhost)
- Redis DB numbers
- Cache prefix uniqueness
- Required variables

## Audit All Projects

```bash
docker-local env:check --all
```

Detects conflicts:
- Duplicate database names
- Overlapping Redis DBs
- Duplicate cache prefixes
- Shared MinIO buckets

## Generate New .env

```bash
docker-local make:env
```

Creates unique:
- CACHE_PREFIX
- REDIS_*_DB numbers
- REVERB credentials

## Update Existing .env

```bash
docker-local update:env
```

Preserves custom settings while updating isolation values.

## Common Issues

### Wrong Database Host
```bash
# Wrong
DB_HOST=localhost

# Correct
DB_HOST=mysql
```

### Cache Prefix Conflict
```bash
# Make unique
CACHE_PREFIX=myapp_
```

### Redis DB Overlap
```bash
# Use next available set
REDIS_CACHE_DB=3
REDIS_SESSION_DB=4
REDIS_QUEUE_DB=5
```

$ARGUMENTS
