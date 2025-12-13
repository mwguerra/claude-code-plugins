---
name: compose
description: Generate Docker Compose configuration for multi-container applications
---

# Generate Docker Compose Configuration

You are generating a Docker Compose configuration. Follow these steps:

## 1. Understand Requirements

Gather information about:
- Required services (web, api, database, cache, queue, etc.)
- Environment (development or production)
- Networking needs (internal, external, SSL)
- Persistence requirements
- Scaling needs

## 2. Consult Documentation

Read relevant documentation:
- `skills/docker-docs/references/03-compose-fundamentals.md` for structure
- `skills/docker-docs/references/04-networking.md` for networks
- `skills/docker-docs/references/05-databases.md` for database services
- `skills/docker-docs/references/06-services.md` for dependencies
- `skills/docker-docs/references/08-volumes.md` for persistence

## 3. Generate Configuration

Create a compose file with:

### Services
- Build configuration or image reference
- Restart policy (`unless-stopped` for production)
- Environment variables (use ${VAR} syntax)
- Port mappings (bind to 127.0.0.1 for internal services)
- Health checks
- Dependencies with conditions

### Networks
- Frontend network for public services
- Backend network (internal: true) for databases
- External networks for reverse proxy integration

### Volumes
- Named volumes for data persistence
- Bind mounts for development only

### Example Structure
```yaml
services:
  app:
    build: .
    restart: unless-stopped
    ports:
      - "3000:3000"
    depends_on:
      db:
        condition: service_healthy
    networks:
      - frontend
      - backend

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 10s
      retries: 5

volumes:
  postgres_data:

networks:
  frontend:
  backend:
    internal: true
```

## 4. Create Supporting Files

Also create:
- `.env.example` with all required variables
- Update `.dockerignore` if needed

$ARGUMENTS
