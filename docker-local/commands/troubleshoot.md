---
description: Diagnose and fix docker-local issues - container failures, port conflicts, connectivity problems
---

# Docker-Local Troubleshoot

Diagnose and fix common docker-local issues.

## 1. Gather Information

```bash
# Check status
docker-local status

# View logs
docker-local logs --tail=50

# Check system
docker system df
```

## 2. Common Issues

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

## 3. Full Reset

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

## 4. Get More Help

```bash
# Full diagnostic
docker-local doctor

# View configuration
docker-local config

# Check specific service logs
docker-local logs mysql
docker-local logs php
docker-local logs traefik
```

$ARGUMENTS
