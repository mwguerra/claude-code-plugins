---
description: Configure database containers (PostgreSQL, MySQL, MongoDB, Redis) with security, persistence, and health checks
---

# Set Up Database Container

You are configuring a database container. Follow these steps:

## 1. Determine Database Type

Identify the required database:
- PostgreSQL (relational, full-featured)
- MySQL/MariaDB (relational, widely used)
- MongoDB (document database)
- Redis (cache/session store)

## 2. Consult Documentation

Read the documentation:
- `skills/docker-docs/references/05-databases.md` for complete configurations

## 3. Apply Best Practices

### Security
- Never expose database ports to the internet (bind to 127.0.0.1)
- Use internal networks
- Strong passwords via environment variables
- Store credentials in .env file (never commit)

### Persistence
- Always use named volumes
- Never use anonymous volumes for data
- Configure regular backups

### Health Checks
- Always include health checks
- Use `service_healthy` condition in dependencies

### Database Configurations

#### PostgreSQL
```yaml
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    shm_size: 256mb
    environment:
      POSTGRES_USER: ${DB_USER:-appuser}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME:-appdb}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "127.0.0.1:5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-appuser}"]
      interval: 10s
      timeout: 5s
      retries: 5
```

#### MySQL
```yaml
services:
  mysql:
    image: mysql:8.0
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      retries: 5
```

#### MongoDB
```yaml
services:
  mongodb:
    image: mongo:7
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_USER}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_PASSWORD}
    volumes:
      - mongo_data:/data/db
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      retries: 5
```

#### Redis
```yaml
services:
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      retries: 5
```

## 4. Provide Connection Strings

After configuration, provide:
- Connection string format for the database
- Example .env variables
- Backup/restore commands

$ARGUMENTS
