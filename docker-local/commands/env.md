---
description: Check and manage .env configuration - conflict detection, unique IDs
---

# Docker-Local Environment Check

Verify .env configuration and detect conflicts.

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
