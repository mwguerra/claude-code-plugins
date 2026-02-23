# Docker Compose Fundamentals

Docker Compose uses YAML files to define multi-container applications.

## Modern Compose File Structure

> **Note:** The `version` field is deprecated since Docker Compose v1.27.0 (2020). Modern compose files start directly with `services`.

```yaml
# Modern Docker Compose file (no version field needed)
services:
  app:
    build: .
    ports:
      - "3000:3000"

  db:
    image: postgres:16
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:

networks:
  default:
    driver: bridge
```

## Service Configuration Options

```yaml
services:
  webapp:
    # Build Configuration
    build:
      context: ./app
      dockerfile: Dockerfile
      args:
        - NODE_ENV=production
      target: production  # For multi-stage builds

    # Or use pre-built image
    image: nginx:alpine

    # Container name (optional)
    container_name: my-webapp

    # Restart Policy
    restart: unless-stopped  # no | always | on-failure | unless-stopped

    # Port Mapping
    ports:
      - "80:80"           # host:container
      - "443:443/tcp"
      - "127.0.0.1:8080:8080"  # Bind to localhost only

    # Environment Variables
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://user:pass@db:5432/app

    # Or use env file
    env_file:
      - .env
      - .env.local

    # Volume Mounts
    volumes:
      - ./src:/app/src          # Bind mount
      - app-data:/app/data      # Named volume
      - /app/node_modules       # Anonymous volume (preserve)

    # Dependencies
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started

    # Networks
    networks:
      - frontend
      - backend

    # Resource Limits
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M

    # Health Check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

    # Logging
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

## Profiles for Conditional Services

```yaml
services:
  app:
    image: myapp:latest
    ports:
      - "3000:3000"

  debug:
    image: myapp:debug
    profiles:
      - debug
    ports:
      - "9229:9229"

  test:
    image: myapp:test
    profiles:
      - testing
```

```bash
# Run without profiles (only app starts)
docker compose up

# Run with debug profile
docker compose --profile debug up

# Run with multiple profiles
docker compose --profile debug --profile testing up
```

## File Naming Conventions

| File | Purpose |
|------|---------|
| `compose.yaml` | Main compose file (preferred) |
| `docker-compose.yaml` | Legacy name (still works) |
| `compose.override.yaml` | Auto-loaded for development |
| `compose.prod.yaml` | Production-specific config |
| `compose.dev.yaml` | Development-specific config |

## Override Files

Docker Compose automatically merges `compose.yaml` with `compose.override.yaml`:

```yaml
# compose.yaml (base)
services:
  app:
    build: .
    environment:
      - NODE_ENV=production

# compose.override.yaml (auto-loaded in development)
services:
  app:
    volumes:
      - ./src:/app/src
    environment:
      - NODE_ENV=development
    ports:
      - "3000:3000"
```

## Using Multiple Compose Files

```bash
# Development (auto-loads override)
docker compose up

# Production (explicit files)
docker compose -f compose.yaml -f compose.prod.yaml up -d

# Testing
docker compose -f compose.yaml -f compose.test.yaml up
```

## Compose File Reference Structure

```yaml
# Top-level elements
services:      # Container definitions (required)
volumes:       # Named volumes
networks:      # Custom networks
configs:       # Configuration files (Swarm)
secrets:       # Secret management
```

## Variable Substitution

```yaml
services:
  app:
    image: ${IMAGE_NAME:-myapp}:${TAG:-latest}
    ports:
      - "${HOST_PORT:-3000}:3000"
    environment:
      - DB_PASSWORD=${DB_PASSWORD:?Database password required}
```

| Syntax | Behavior |
|--------|----------|
| `${VAR}` | Value of VAR |
| `${VAR:-default}` | Default if VAR unset or empty |
| `${VAR-default}` | Default if VAR unset |
| `${VAR:?error}` | Error if VAR unset or empty |
| `${VAR?error}` | Error if VAR unset |

## Extends (Reusable Services)

```yaml
# common.yaml
services:
  base:
    image: node:20-alpine
    environment:
      - NODE_ENV=production
    restart: unless-stopped

# compose.yaml
services:
  app:
    extends:
      file: common.yaml
      service: base
    ports:
      - "3000:3000"
```

## Anchors and Aliases (YAML Feature)

```yaml
# Define anchor
x-common: &common
  restart: unless-stopped
  logging:
    driver: json-file
    options:
      max-size: "10m"

services:
  app:
    <<: *common  # Use alias
    build: .
    ports:
      - "3000:3000"

  worker:
    <<: *common  # Reuse configuration
    build: ./worker
```
