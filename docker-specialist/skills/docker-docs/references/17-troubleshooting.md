# Troubleshooting

## Container Won't Start

### Check Logs
```bash
docker compose logs servicename
docker compose logs --tail=100 servicename
```

### Check Container Status
```bash
docker compose ps -a
docker inspect containername
```

### Run Container Interactively
```bash
docker compose run --rm servicename sh
docker compose run --entrypoint sh servicename
```

### Check Exit Code
```bash
docker inspect --format='{{.State.ExitCode}}' containername
```

## Port Already in Use

### Find What's Using the Port
```bash
lsof -i :3000
# or
netstat -tulpn | grep 3000
# or
ss -tulpn | grep 3000
```

### Kill the Process
```bash
kill $(lsof -t -i:3000)
```

### Check for Docker Containers
```bash
docker ps --filter "publish=3000"
docker stop $(docker ps -q --filter "publish=3000")
```

## Container Keeps Restarting (Crash Loop)

### Check Logs for Errors
```bash
docker compose logs --tail=100 servicename
```

### Check Health Status
```bash
docker inspect --format='{{json .State.Health}}' containername | jq
```

### Run Interactively to Debug
```bash
docker compose run --rm servicename sh
```

### Check Resource Limits
```bash
docker stats containername
```

## Volume Permission Issues

### Check Volume Permissions
```bash
docker compose exec app ls -la /app/data
```

### Fix Ownership Inside Container
```bash
docker compose exec -u root app chown -R appuser:appgroup /app/data
```

### Fix Host Permissions
```bash
sudo chown -R $(id -u):$(id -g) ./mounted-folder
```

### Use User Mapping
```yaml
services:
  app:
    user: "1000:1000"  # Match your host user
```

## Data Disappearing After Restart

### Check Volume Configuration
```bash
docker compose config | grep -A5 "volumes:"
```

### Verify Volume Exists
```bash
docker volume ls
docker volume inspect projectname_dbdata
```

### Common Mistake
```yaml
# BAD: Anonymous volume (gets deleted)
volumes:
  - /var/lib/postgresql/data

# GOOD: Named volume (persists)
volumes:
  - postgres_data:/var/lib/postgresql/data
```

## Container Can't Reach Another Container

### Check Network Configuration
```bash
docker network inspect networkname
```

### Test Connectivity
```bash
docker compose exec app ping db
docker compose exec app nc -zv db 5432
```

### Test DNS Resolution
```bash
docker compose exec app nslookup db
```

### Verify Same Network
```yaml
services:
  app:
    networks:
      - backend
  db:
    networks:
      - backend  # Must be same network

networks:
  backend:
```

## Out of Disk Space

### Check Docker Disk Usage
```bash
docker system df
docker system df -v
```

### Clean Up
```bash
# Remove unused containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove everything unused
docker system prune -a --volumes
```

## Build Cache Issues

### Build Without Cache
```bash
docker compose build --no-cache
docker compose build --no-cache servicename
```

### Clear All Build Cache
```bash
docker builder prune -a
```

## Service Won't Start After Config Change

### Validate Compose File
```bash
docker compose config
docker compose config --quiet && echo "Valid!" || echo "Invalid!"
```

### Force Recreate
```bash
docker compose up -d --force-recreate
```

## Database Won't Start (Data Corruption)

### Check Database Logs
```bash
docker compose logs db
```

### Backup and Reset
```bash
# Try to backup first
docker compose exec db pg_dumpall -U postgres > emergency_backup.sql 2>/dev/null || true

# Reset database
docker compose down -v
docker compose up -d

# Restore from backup if available
docker compose exec -T db psql -U postgres < backup.sql
```

## Environment Variables Not Working

### Check Variable Values
```bash
docker compose config
docker compose exec app env
docker compose exec app printenv DATABASE_URL
```

### Check .env File Parsing
```bash
docker compose config --format json | jq '.services.app.environment'
```

### Variable Expansion Issues
```yaml
# Make sure to use correct syntax
environment:
  - VAR=${VAR:-default}  # Works
  - VAR=$VAR             # May not work
```

## Health Check Failing

### Check Health Status
```bash
docker inspect --format='{{json .State.Health}}' containername | jq
```

### Run Health Check Manually
```bash
docker compose exec app curl -f http://localhost:3000/health
```

### Check Health Check Config
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s  # Time before first check
```

## Memory/CPU Issues

### View Resource Usage
```bash
docker stats
docker stats --no-stream
```

### Set Limits
```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
```

### Check for Memory Leaks
```bash
docker compose exec app top
docker compose exec app ps aux
```

## Debugging Commands Summary

```bash
# Shell into running container
docker compose exec app sh

# Shell into failed container
docker compose run --entrypoint sh app

# View resource usage
docker stats

# View container processes
docker compose top

# Copy files from container
docker compose cp app:/app/logs ./logs

# View real-time events
docker events

# Inspect container
docker inspect containername

# View container logs with timestamps
docker compose logs -t servicename
```

## Quick Diagnostic Checklist

1. **Check if container is running:** `docker compose ps`
2. **Check logs:** `docker compose logs servicename`
3. **Check network:** `docker network ls`
4. **Check volumes:** `docker volume ls`
5. **Check resources:** `docker stats`
6. **Validate config:** `docker compose config`
7. **Check disk space:** `docker system df`

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "port is already allocated" | Port in use | Kill process or change port |
| "network not found" | Missing network | Create network or check name |
| "volume not found" | Missing volume | Create volume or check name |
| "no such service" | Service name typo | Check compose.yaml |
| "unauthorized" | Auth issue | `docker login` |
| "image not found" | Missing image | `docker compose pull` |
| "permission denied" | File permissions | Fix ownership/permissions |
| "out of memory" | Memory limit | Increase limit or optimize app |
