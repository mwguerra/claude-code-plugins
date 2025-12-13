# Volumes & Data Persistence

## Volume Types

```yaml
services:
  app:
    volumes:
      # Named Volume (recommended for data)
      - app_data:/app/data

      # Bind Mount (for development)
      - ./src:/app/src

      # Anonymous Volume (temporary, for node_modules etc.)
      - /app/node_modules

      # Read-only mount
      - ./config:/app/config:ro

      # tmpfs (in-memory, for sensitive data)
      # Defined separately in tmpfs section

    tmpfs:
      - /app/tmp
      - /app/cache:size=100M

volumes:
  app_data:
    driver: local
```

## Volume Comparison

| Type | Persistence | Use Case | Example |
|------|-------------|----------|---------|
| **Named Volume** | Permanent | Database data, uploads | `pgdata:/var/lib/postgresql/data` |
| **Bind Mount** | Host-dependent | Source code in development | `./src:/app/src` |
| **Anonymous Volume** | Until container removed | Preserve node_modules | `/app/node_modules` |
| **tmpfs** | Memory only | Sensitive temp data | `/app/secrets` |

## Volume Configuration Options

```yaml
volumes:
  # Simple named volume
  data:

  # Volume with driver options
  postgres_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /path/on/host

  # External volume (created outside compose)
  external_data:
    external: true
    name: my-external-volume
```

## Development vs Production Volumes

```yaml
# compose.yaml (base)
services:
  app:
    build: .
    volumes:
      - app_data:/app/data

volumes:
  app_data:
```

```yaml
# compose.override.yaml (development - auto-loaded)
services:
  app:
    volumes:
      - ./src:/app/src  # Live reload
      - /app/node_modules  # Preserve node_modules
```

```yaml
# compose.prod.yaml (production)
services:
  app:
    # No source code mounts
    volumes:
      - app_data:/app/data
```

## Volume Permissions

### Fix Ownership Issues

```yaml
services:
  app:
    user: "1000:1000"  # Match host user
    volumes:
      - ./data:/app/data
```

### Init Container for Permissions

```yaml
services:
  init:
    image: busybox
    command: chown -R 1000:1000 /data
    volumes:
      - app_data:/data
    restart: "no"

  app:
    depends_on:
      init:
        condition: service_completed_successfully
    volumes:
      - app_data:/app/data

volumes:
  app_data:
```

## Bind Mount Options

```yaml
volumes:
  # Read-only
  - ./config:/app/config:ro

  # Cached (macOS performance)
  - ./src:/app/src:cached

  # Delegated (macOS performance)
  - ./logs:/app/logs:delegated

  # SELinux label
  - ./data:/app/data:z       # Private
  - ./shared:/shared:Z       # Shared
```

## Volume Backup and Restore

### Backup

```bash
# Backup a volume to tar file
docker run --rm \
  -v myproject_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/data-backup.tar.gz -C /data .

# Using docker compose
docker compose exec -T db pg_dump -U postgres > backup.sql
```

### Restore

```bash
# Restore from tar file
docker run --rm \
  -v myproject_data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/data-backup.tar.gz -C /data

# Restore database
docker compose exec -T db psql -U postgres < backup.sql
```

## Volume Management Commands

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect myproject_postgres_data

# Create volume
docker volume create my-volume

# Remove volume
docker volume rm my-volume

# Remove unused volumes
docker volume prune

# Remove ALL volumes (dangerous!)
docker volume prune -a
```

## Data Persistence Matrix

| Action | Named Volumes | Anonymous Volumes | Bind Mounts |
|--------|---------------|-------------------|-------------|
| `docker compose stop` | Kept | Kept | Kept |
| `docker compose down` | Kept | Removed | Kept |
| `docker compose down -v` | Removed | Removed | Kept |
| Container rebuild | Kept | Lost | Kept |

## Common Volume Patterns

### Node.js with node_modules

```yaml
services:
  app:
    build: .
    volumes:
      - ./src:/app/src
      - ./package.json:/app/package.json
      - /app/node_modules  # Preserve container's node_modules
```

### PHP with Vendor

```yaml
services:
  app:
    build: .
    volumes:
      - ./:/var/www/html
      - /var/www/html/vendor  # Preserve vendor
```

### Multiple Apps Sharing Data

```yaml
services:
  app:
    volumes:
      - shared_data:/data

  worker:
    volumes:
      - shared_data:/data

volumes:
  shared_data:
```

## tmpfs for Sensitive Data

```yaml
services:
  app:
    tmpfs:
      - /app/tmp:size=100M,mode=1777
      - /app/secrets:size=10M,uid=1000,gid=1000
```

## Volume Drivers

### Local Driver Options

```yaml
volumes:
  nfs_data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=192.168.1.100,rw
      device: ":/path/to/share"

  cifs_data:
    driver: local
    driver_opts:
      type: cifs
      device: "//server/share"
      o: "addr=server,username=user,password=pass"
```

### Cloud Storage Drivers

```yaml
volumes:
  s3_data:
    driver: rexray/s3fs
    driver_opts:
      size: 10

  gcs_data:
    driver: gcsfuse
```

## Handling External Files

```yaml
services:
  app:
    volumes:
      # SOURCE CODE - Always on host
      - ./src:/app/src

      # UPLOADS - Bind mount for persistence + easy access
      - ./data/uploads:/app/uploads

      # LOGS - Bind mount for easy access
      - ./logs:/app/logs

      # CONFIG - Read-only
      - ./config/app.json:/app/config.json:ro

      # NODE_MODULES - Anonymous (recreated on rebuild)
      - /app/node_modules

      # CACHE - Named volume (persists across restarts)
      - app_cache:/app/.cache

volumes:
  app_cache:
```
