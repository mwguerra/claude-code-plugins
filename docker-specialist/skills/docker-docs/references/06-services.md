# Services & Multi-Container Applications

## Service Dependencies and Startup Order

```yaml
services:
  app:
    build: .
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
      migrations:
        condition: service_completed_successfully

  migrations:
    build: .
    command: npm run migrate
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
```

## Dependency Conditions

| Condition | Description |
|-----------|-------------|
| `service_started` | Wait for service to start (default) |
| `service_healthy` | Wait for healthcheck to pass |
| `service_completed_successfully` | Wait for service to exit with code 0 |

## Scaling Services

```yaml
services:
  worker:
    build: ./worker
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
```

```bash
# Scale a service
docker compose up -d --scale worker=5

# Check running instances
docker compose ps
```

## Inter-Service Communication Pattern

```yaml
services:
  # API Gateway / Load Balancer
  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "80:80"
    depends_on:
      - api

  # Application API
  api:
    build: ./api
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/app
      - REDIS_URL=redis://redis:6379
      - QUEUE_URL=amqp://rabbitmq:5672
    depends_on:
      - db
      - redis
      - rabbitmq
    expose:
      - "3000"  # Internal only

  # Background Worker
  worker:
    build: ./worker
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/app
      - QUEUE_URL=amqp://rabbitmq:5672
    depends_on:
      - db
      - rabbitmq

  # Services
  db:
    image: postgres:16
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7
    volumes:
      - redis_data:/data

  rabbitmq:
    image: rabbitmq:3-management
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

volumes:
  pgdata:
  redis_data:
  rabbitmq_data:
```

## Service Restart Policies

```yaml
services:
  app:
    restart: unless-stopped  # Recommended for production
```

| Policy | Description |
|--------|-------------|
| `no` | Never restart (default) |
| `always` | Always restart |
| `on-failure` | Restart only on error exit |
| `unless-stopped` | Restart unless explicitly stopped |

## One-Off Services

```yaml
services:
  app:
    build: .

  migrate:
    build: .
    command: npm run migrate
    depends_on:
      db:
        condition: service_healthy
    profiles:
      - tools

  seed:
    build: .
    command: npm run seed
    depends_on:
      db:
        condition: service_healthy
    profiles:
      - tools
```

```bash
# Run migration
docker compose run --rm migrate

# Or with profile
docker compose --profile tools run migrate
```

## Init Containers Pattern

```yaml
services:
  init-permissions:
    image: busybox
    command: chown -R 1000:1000 /data
    volumes:
      - app_data:/data
    restart: "no"

  app:
    build: .
    depends_on:
      init-permissions:
        condition: service_completed_successfully
    volumes:
      - app_data:/app/data

volumes:
  app_data:
```

## Sidecar Pattern

```yaml
services:
  app:
    build: .
    volumes:
      - logs:/app/logs

  log-shipper:
    image: fluent/fluent-bit
    volumes:
      - logs:/logs:ro
      - ./fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf
    depends_on:
      - app

volumes:
  logs:
```

## Service Discovery

Services can discover each other by name within the same network:

```yaml
services:
  frontend:
    environment:
      - API_URL=http://api:3000
      - WS_URL=ws://websocket:8080

  api:
    environment:
      - DB_HOST=postgres
      - CACHE_HOST=redis

  websocket:
    environment:
      - REDIS_HOST=redis

  postgres:
    image: postgres:16

  redis:
    image: redis:7
```

## Service Configuration Patterns

### Environment-Based Configuration

```yaml
services:
  app:
    build: .
    environment:
      - NODE_ENV=${NODE_ENV:-development}
      - LOG_LEVEL=${LOG_LEVEL:-info}
    env_file:
      - .env
      - .env.${NODE_ENV:-development}
```

### Config Files via Volumes

```yaml
services:
  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
```

### Docker Configs (Swarm Mode)

```yaml
services:
  app:
    configs:
      - source: app_config
        target: /app/config.json

configs:
  app_config:
    file: ./config.json
```

## Health Check Patterns

### HTTP Health Check
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### TCP Health Check
```yaml
healthcheck:
  test: ["CMD-SHELL", "nc -z localhost 3000"]
  interval: 10s
  timeout: 5s
  retries: 5
```

### Custom Script Health Check
```yaml
healthcheck:
  test: ["CMD", "/healthcheck.sh"]
  interval: 30s
  timeout: 10s
  retries: 3
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
