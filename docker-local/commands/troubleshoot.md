---
description: Diagnose and fix docker-local issues - container failures, port conflicts, connectivity problems
allowed-tools: Bash(docker-local:*), Bash(docker:*), Bash(lsof:*), Bash(netstat:*), Read, Glob, Grep
argument-hint: "[issue-description] [--fix] [--verbose]"
---

# Docker-Local Troubleshoot

Diagnose and fix common docker-local issues.

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

## 1. Quick Fix (Recommended First Step)

The `fix` command auto-diagnoses and fixes common issues:

```bash
# Run all checks and auto-fix what's possible
docker-local fix

# Target specific areas
docker-local fix --dns         # Only check/fix DNS issues
docker-local fix --docker      # Only check/fix Docker daemon
docker-local fix --services    # Only check/fix container services
docker-local fix --hosts       # Only check/fix /etc/hosts

# Additional options
docker-local fix --verbose     # Show detailed diagnostic info
docker-local fix --dry-run     # Show what would be fixed without making changes
```

The fix command automatically detects and resolves:
- Docker daemon not running
- Stopped containers
- Missing systemd-resolved configuration for *.test DNS
- Missing dnsmasq configuration
- /etc/hosts not configured

## 2. Gather Information

```bash
# Check status
docker-local status

# View logs
docker-local logs --tail=50

# Check system
docker system df
```

## 3. Common Issues

### Docker Not Running

```bash
# Check
docker info

# Fix (Linux)
sudo systemctl start docker

# Fix (macOS)
open -a Docker
```

### Port Conflict

```bash
# Find what's using the port
lsof -i :3306

# Kill the process
kill $(lsof -t -i:3306)

# Or change port in ~/.config/docker-local/config.json
```

### Container Won't Start

```bash
# Check logs
docker-local logs php

# Restart
docker-local restart
```

### Cannot Connect to Database

```bash
# Verify container running
docker-local status

# Check .env has correct host
# DB_HOST=mysql (not localhost)
```

### DNS Not Working

```bash
# Setup DNS
sudo docker-local setup:dns

# Or add to hosts
sudo docker-local setup:hosts
```

### SSL Certificate Issues

```bash
# Regenerate certificates
docker-local init --certs
```

## 4. SSL Certificate Issues

```bash
# Check SSL certificate status
docker-local ssl:status

# Regenerate SSL certificates with mkcert
docker-local ssl:regenerate

# Or regenerate during init
docker-local init --certs
```

## 5. Full Reset

If all else fails:

```bash
# Stop everything
docker-local down

# Clean Docker
docker system prune -af
docker volume prune -f

# Reinitialize
docker-local init
docker-local up
```

## 6. Get More Help

```bash
# Full diagnostic
docker-local doctor

# Auto-fix issues
docker-local fix

# View configuration
docker-local config

# Check specific service logs
docker-local logs mysql
docker-local logs php
docker-local logs traefik
```

$ARGUMENTS
