---
description: View Docker and Laravel logs
allowed-tools: Bash(docker-local:*), Bash(docker:*), Read
argument-hint: "[service] [--follow] [--tail N]"
---

# Docker-Local Logs

View logs from Docker services and Laravel.

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

## View All Logs

```bash
docker-local logs
```

## View Specific Service

```bash
# PHP container
docker-local logs php

# MySQL
docker-local logs mysql

# PostgreSQL
docker-local logs postgres

# Redis
docker-local logs redis

# Nginx
docker-local logs nginx

# Traefik
docker-local logs traefik

# Mailpit
docker-local logs mailpit

# MinIO
docker-local logs minio
```

## View Laravel Logs

```bash
# Tail Laravel log file
docker-local logs:laravel
```

## Log Options

```bash
# Last 50 lines
docker-local logs --tail=50

# Follow logs (real-time)
docker-local logs -f

# Specific service with follow
docker-local logs mysql -f
```

## Common Log Locations

| Log | Location |
|-----|----------|
| Laravel | `~/projects/myapp/storage/logs/laravel.log` |
| PHP | Docker container logs |
| MySQL | Docker container logs |
| Nginx | Docker container logs |

## Debugging with Logs

```bash
# Find errors
docker-local logs php 2>&1 | grep -i error

# Check MySQL startup
docker-local logs mysql --tail=100

# Monitor in real-time
docker-local logs -f
```

$ARGUMENTS
