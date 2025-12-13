---
name: troubleshoot
description: Diagnose and fix Docker issues including container failures, networking, and permissions
---

# Troubleshoot Docker Issues

You are diagnosing Docker problems. Follow these steps:

## 1. Gather Information

Run diagnostic commands:
```bash
# Check container status
docker compose ps -a

# View recent logs
docker compose logs --tail=100

# Check configuration
docker compose config

# Check system resources
docker system df
docker stats --no-stream
```

## 2. Consult Documentation

Read the documentation:
- `skills/docker-docs/references/17-troubleshooting.md` for common issues
- `skills/docker-docs/references/15-port-conflicts.md` for port problems
- `skills/docker-docs/references/16-restart-strategies.md` for restart issues

## 3. Common Issues and Solutions

### Container Won't Start
```bash
# Check logs
docker compose logs servicename

# Check exit code
docker inspect --format='{{.State.ExitCode}}' containername
```
- Exit code 0: Normal stop
- Exit code 1: Application error
- Exit code 137: Out of memory (OOM killed)
- Exit code 139: Segmentation fault

### Port Already in Use
```bash
# Find process using port
lsof -i :3000
# or
netstat -tulpn | grep 3000

# Kill the process
kill $(lsof -t -i:3000)
```

### Permission Denied
```bash
# Check file ownership
docker compose exec app ls -la /app/data

# Fix in container
docker compose exec -u root app chown -R appuser:appgroup /app/data
```

Or fix in compose:
```yaml
services:
  app:
    user: "1000:1000"
```

### Container Can't Reach Database
```bash
# Test DNS resolution
docker compose exec app nslookup db

# Test connectivity
docker compose exec app ping db

# Check networks
docker network inspect networkname
```

Ensure services are on the same network:
```yaml
services:
  app:
    networks:
      - backend
  db:
    networks:
      - backend
```

### Data Disappearing
Check volume configuration:
```bash
docker volume ls
docker compose config | grep -A5 "volumes:"
```

Use named volumes (not anonymous):
```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data  # Named (persists)
  # NOT: - /var/lib/postgresql/data         # Anonymous (deleted)
```

### Health Check Failing
```bash
# Check health status
docker inspect --format='{{json .State.Health}}' containername | jq
```

Adjust health check timing:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s  # Give more time to start
```

### Out of Disk Space
```bash
# Check Docker disk usage
docker system df -v

# Clean unused resources
docker system prune -a --volumes
```

### Build Cache Issues
```bash
# Rebuild without cache
docker compose build --no-cache

# Clean build cache
docker builder prune -a
```

## 4. Debugging Commands

```bash
# Shell into running container
docker compose exec app sh

# Shell into failed container
docker compose run --entrypoint sh app

# View container processes
docker compose top

# Real-time events
docker events

# Copy files from container
docker compose cp app:/app/logs ./logs
```

## 5. Report Findings

After diagnosis, provide:
- Root cause of the issue
- Specific solution
- Commands to implement the fix
- Prevention tips

$ARGUMENTS
