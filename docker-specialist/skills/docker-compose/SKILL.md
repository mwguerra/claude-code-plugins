---
name: docker-compose
description: Generate Docker Compose configurations for multi-container applications with services, networking, and volumes
---

# Docker Compose Configuration Skill

## Overview

This skill generates Docker Compose configurations for multi-container applications. It creates properly structured compose files with:
- Service definitions
- Network configuration
- Volume management
- Health checks
- Dependencies
- Environment configuration

## Activation

Use this skill when:
- Creating a new compose file
- Adding services to existing compose
- Configuring container orchestration
- Setting up development or production environments

## Process

### 1. Understand Requirements

Gather information about:
- Required services (web, api, database, cache, etc.)
- Environment (development/production)
- Networking needs (internal, external, SSL)
- Persistence requirements
- Scaling needs

### 2. Consult Documentation

Read relevant documentation:
- `03-compose-fundamentals.md` for structure
- `04-networking.md` for networks
- `05-databases.md` for database services
- `06-services.md` for dependencies
- `08-volumes.md` for persistence

### 3. Generate Configuration

Create compose file following best practices:

```yaml
# Modern compose (no version field)
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    depends_on:
      db:
        condition: service_healthy
    networks:
      - frontend
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:

networks:
  frontend:
  backend:
    internal: true
```

## Service Patterns

### Web Application

```yaml
services:
  web:
    build: .
    ports:
      - "80:80"
    depends_on:
      - api
```

### API Service

```yaml
services:
  api:
    build: ./api
    expose:
      - "3000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/app
    depends_on:
      db:
        condition: service_healthy
```

### Database Service

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - db_data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 10s
      retries: 5
```

### Cache Service

```yaml
services:
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
```

### Background Worker

```yaml
services:
  worker:
    build: .
    command: npm run worker
    depends_on:
      - db
      - redis
```

## Network Patterns

### Internal Database Network

```yaml
networks:
  backend:
    internal: true  # No external access
```

### External Shared Network

```yaml
networks:
  proxy:
    external: true
    name: traefik_proxy
```

## Volume Patterns

### Named Volume

```yaml
volumes:
  postgres_data:
```

### Bind Mount (Development)

```yaml
volumes:
  - ./src:/app/src
```

### Anonymous Volume

```yaml
volumes:
  - /app/node_modules
```

## Environment Patterns

### Direct Values

```yaml
environment:
  - NODE_ENV=production
```

### From .env File

```yaml
env_file:
  - .env
```

### With Defaults

```yaml
environment:
  - DB_HOST=${DB_HOST:-localhost}
```

## Output

Generated compose file includes:
- All required services
- Proper network configuration
- Volume definitions
- Health checks
- Dependency management
- Environment configuration
- Comments for complex settings
