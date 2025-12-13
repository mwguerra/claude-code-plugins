# Database Containers Best Practices

## PostgreSQL Configuration

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped

    # Shared memory for PostgreSQL
    shm_size: 256mb

    environment:
      POSTGRES_USER: ${DB_USER:-appuser}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME:-appdb}
      # Performance tuning
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"

    volumes:
      # Data persistence
      - postgres_data:/var/lib/postgresql/data
      # Custom configuration
      - ./config/postgresql.conf:/etc/postgresql/postgresql.conf
      # Initialization scripts (run once on first start)
      - ./init-scripts:/docker-entrypoint-initdb.d

    ports:
      - "127.0.0.1:5432:5432"  # Localhost only

    networks:
      - database

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-appuser} -d ${DB_NAME:-appdb}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

volumes:
  postgres_data:

networks:
  database:
    internal: true  # No external access
```

## MySQL/MariaDB Configuration

```yaml
services:
  mysql:
    image: mysql:8.0
    container_name: mysql
    restart: unless-stopped

    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME}
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}

    volumes:
      - mysql_data:/var/lib/mysql
      - ./config/my.cnf:/etc/mysql/conf.d/custom.cnf
      - ./init-scripts:/docker-entrypoint-initdb.d

    ports:
      - "127.0.0.1:3306:3306"

    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci

    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mysql_data:
```

## MongoDB Configuration

```yaml
services:
  mongodb:
    image: mongo:7
    container_name: mongodb
    restart: unless-stopped

    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_USER}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_PASSWORD}
      MONGO_INITDB_DATABASE: ${MONGO_DB}

    volumes:
      - mongo_data:/data/db
      - mongo_config:/data/configdb
      - ./init-scripts:/docker-entrypoint-initdb.d

    ports:
      - "127.0.0.1:27017:27017"

    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  mongo_data:
  mongo_config:
```

## Redis Configuration

```yaml
services:
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped

    command: >
      redis-server
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --requirepass ${REDIS_PASSWORD}

    volumes:
      - redis_data:/data

    ports:
      - "127.0.0.1:6379:6379"

    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  redis_data:
```

## Database Best Practices Summary

1. **Always use named volumes** for data persistence
2. **Never expose database ports publicly** unless absolutely necessary
3. **Use health checks** to ensure database is ready before dependent services start
4. **Store credentials in environment variables** or Docker secrets
5. **Use initialization scripts** for schema setup
6. **Regular backups** using `docker exec` with database dump commands
7. **Use internal networks** to isolate database traffic

## Backup Commands

```bash
# Backup PostgreSQL
docker exec -t postgres pg_dumpall -c -U appuser > backup.sql

# Backup MySQL
docker exec mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} --all-databases > backup.sql

# Backup MongoDB
docker exec mongodb mongodump --archive --gzip > backup.gz
```

## Restore Commands

```bash
# Restore PostgreSQL
docker exec -i postgres psql -U appuser -d appdb < backup.sql

# Restore MySQL
docker exec -i mysql mysql -u root -p${MYSQL_ROOT_PASSWORD} < backup.sql

# Restore MongoDB
docker exec -i mongodb mongorestore --archive --gzip < backup.gz
```

## Connection Strings

### PostgreSQL
```
DATABASE_URL=postgresql://user:password@db:5432/dbname
```

### MySQL
```
DATABASE_URL=mysql://user:password@db:3306/dbname
```

### MongoDB
```
MONGO_URI=mongodb://user:password@mongodb:27017/dbname?authSource=admin
```

### Redis
```
REDIS_URL=redis://:password@redis:6379
```

## Database Initialization Scripts

Scripts in `/docker-entrypoint-initdb.d/` run on first container start:

```sql
-- init-scripts/01-schema.sql
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_users_email ON users(email);
```

```bash
# init-scripts/02-seed.sh
#!/bin/bash
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
    INSERT INTO users (email) VALUES ('admin@example.com');
EOSQL
```

## Multi-Database Setup

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_MULTIPLE_DATABASES: app,analytics,logs
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./create-multiple-databases.sh:/docker-entrypoint-initdb.d/create-multiple-databases.sh

volumes:
  postgres_data:
```

```bash
# create-multiple-databases.sh
#!/bin/bash

set -e
set -u

function create_database() {
    local database=$1
    echo "Creating database '$database'"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE $database;
        GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_database $db
    done
fi
```
