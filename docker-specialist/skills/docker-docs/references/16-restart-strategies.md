# Restart Strategies & Data Persistence

## Understanding What Gets Preserved

| Action | Containers | Named Volumes | Anonymous Volumes | Bind Mounts | Networks |
|--------|------------|---------------|-------------------|-------------|----------|
| `docker compose stop` | Stopped (preserved) | Kept | Kept | Kept | Kept |
| `docker compose down` | Removed | Kept | Removed | Kept | Removed |
| `docker compose down -v` | Removed | Removed | Removed | Kept | Removed |
| `docker compose down --rmi all` | Removed | Kept | Removed | Kept | Removed |
| `docker compose down -v --rmi all` | Removed | Removed | Removed | Kept | Removed |

## Restart Commands Reference

### Scenario 1: Quick Restart (Keep Everything)
**Use when:** Service is unresponsive, need to apply env changes

```bash
docker compose restart                    # Restart all
docker compose restart api               # Restart one service
```

### Scenario 2: Recreate Containers (Keep Volumes/Data)
**Use when:** Changed compose.yaml, need fresh container state

```bash
docker compose up -d --force-recreate    # Recreate all
docker compose up -d --force-recreate api # Recreate one service
```

### Scenario 3: Rebuild and Recreate (Keep Data)
**Use when:** Changed Dockerfile or source code

```bash
docker compose up -d --build             # Rebuild changed images
docker compose up -d --build --force-recreate  # Rebuild all
```

### Scenario 4: Stop Without Removing (Pause Work)
**Use when:** Taking a break, need ports freed temporarily

```bash
docker compose stop                      # Stop all (can start later)
docker compose start                     # Start stopped containers
```

### Scenario 5: Full Reset Keeping Data (Clean Container State)
**Use when:** Troubleshooting, major config changes

```bash
docker compose down                      # Remove containers
docker compose up -d                     # Fresh containers, same data
```

### Scenario 6: Full Reset Removing Data (Fresh Start)
**Use when:** Corrupted data, schema changes, starting over

```bash
docker compose down -v                   # Remove everything including volumes
docker compose up -d                     # Completely fresh
```

### Scenario 7: Nuclear Option (Remove Everything)
**Use when:** Complete cleanup, switching projects

```bash
docker compose down -v --rmi all --remove-orphans
```

## Restart Decision Tree

```
WHAT DO YOU NEED TO DO?
         │
    ┌────┴────┬─────────────┐
    ▼         ▼             ▼
Quick      Update        Fresh
restart    config        start
    │         │             │
    ▼         ▼             ▼
restart   up -d         down -v
          --force       up -d
          -recreate
```

## When to Use What

| Situation | Command |
|-----------|---------|
| Service unresponsive | `docker compose restart service` |
| Changed environment variables | `docker compose up -d --force-recreate` |
| Changed Dockerfile | `docker compose up -d --build` |
| Changed compose.yaml | `docker compose up -d --force-recreate` |
| Free up ports temporarily | `docker compose stop` |
| Start fresh, keep data | `docker compose down && docker compose up -d` |
| Complete reset | `docker compose down -v && docker compose up -d` |
| Debug failing container | `docker compose logs service` then `docker compose run service sh` |

## Restart Policies in Compose

```yaml
services:
  app:
    restart: unless-stopped  # Recommended for production
```

| Policy | Behavior |
|--------|----------|
| `no` | Never restart (default) |
| `always` | Always restart |
| `on-failure` | Restart only on error |
| `unless-stopped` | Restart unless manually stopped |

## Health Checks for Auto-Recovery

```yaml
services:
  app:
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## Graceful Shutdown

```yaml
services:
  app:
    stop_grace_period: 30s
    stop_signal: SIGTERM
```

Handle in application:
```javascript
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  await server.close();
  await db.disconnect();
  process.exit(0);
});
```

## Smart Restart Script

**scripts/docker-restart.sh:**

```bash
#!/bin/bash

echo "Docker Compose Restart Manager"
echo "=============================="

echo "Current status:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers running"

echo ""
echo "Data-Safe Options:"
echo "  1) Restart services (keeps everything, fastest)"
echo "  2) Recreate containers (keeps volumes/data)"
echo "  3) Rebuild and recreate (keeps volumes/data)"
echo "  4) Stop services (free ports, keep data)"
echo ""
echo "Data-Risk Options:"
echo "  5) Reset all data (DELETES DATABASE)"
echo ""
echo "  0) Exit"

read -p "Enter choice [0-5]: " choice

case $choice in
    1)
        echo "Restarting services..."
        docker compose restart
        ;;
    2)
        echo "Recreating containers..."
        docker compose up -d --force-recreate
        ;;
    3)
        echo "Rebuilding and recreating..."
        docker compose up -d --build --force-recreate
        ;;
    4)
        echo "Stopping services..."
        docker compose stop
        ;;
    5)
        read -p "This will DELETE all data. Type 'DELETE' to confirm: " confirm
        if [ "$confirm" = "DELETE" ]; then
            docker compose down -v
            docker compose up -d
        else
            echo "Aborted."
        fi
        ;;
    0)
        exit 0
        ;;
    *)
        echo "Invalid option"
        ;;
esac

echo ""
docker compose ps
```

## Database Backup Before Restart

```bash
# Always backup before risky operations
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# PostgreSQL
docker compose exec -T db pg_dumpall -U postgres > "backup_$TIMESTAMP.sql"

# MySQL
docker compose exec -T db mysqldump -u root -p"$PASS" --all-databases > "backup_$TIMESTAMP.sql"

# MongoDB
docker compose exec -T db mongodump --archive > "backup_$TIMESTAMP.archive"
```

## Data Persistence Best Practices

### What to Use Named Volumes For
- Database data
- Cache data that should persist
- Application data (uploads, files)

### What to Use Bind Mounts For
- Source code (development)
- Configuration files
- Log files (for easy access)

### What to Use Anonymous Volumes For
- node_modules (preserve between rebuilds)
- Temporary build artifacts

```yaml
volumes:
  # Named volume - persists across down/up
  - db_data:/var/lib/postgresql/data

  # Bind mount - always on host
  - ./src:/app/src

  # Anonymous volume - lost on down
  - /app/node_modules
```
