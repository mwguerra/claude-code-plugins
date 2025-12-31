---
description: Check docker-local environment status - services, containers, and project accessibility
---

# Docker-Local Status

Check the complete status of your docker-local environment.

## 1. Verify Installation

```bash
# Check docker-local is installed
which docker-local
```

## 2. Check Docker Daemon

```bash
# Verify Docker is running
docker info > /dev/null 2>&1 && echo "Docker: Running" || echo "Docker: NOT running"
```

## 3. Check Services Status

```bash
# Full status report
docker-local status
```

## 4. List Projects

```bash
# Show all projects and accessibility
docker-local list
```

## 5. Test Connections

If services show issues, test individually:

```bash
# MySQL
docker exec mysql mysqladmin ping -h localhost -u root -psecret 2>/dev/null && echo "MySQL: OK" || echo "MySQL: FAIL"

# PostgreSQL
docker exec postgres pg_isready -U laravel 2>/dev/null && echo "PostgreSQL: OK" || echo "PostgreSQL: FAIL"

# Redis
docker exec redis redis-cli ping 2>/dev/null | grep -q PONG && echo "Redis: OK" || echo "Redis: FAIL"
```

## Common Status Issues

### Services Not Running
```bash
docker-local up
```

### Docker Not Running
```bash
# Linux
sudo systemctl start docker

# macOS
open -a Docker
```

### DNS Not Configured
```bash
sudo docker-local setup:dns
```

$ARGUMENTS
