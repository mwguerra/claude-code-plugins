# Migrating from Project-Specific Docker

If your project has its own Docker configuration, you can migrate to docker-local for a shared, centralized environment.

## What docker-local Provides

| Service | Included | Notes |
|---------|----------|-------|
| PHP 8.4 FPM | Yes | With FFmpeg, ImageMagick, 50+ extensions |
| PostgreSQL 17 | Yes | With pgvector for AI embeddings |
| MySQL 9.1 | Yes | Innovation release |
| Redis 8 | Yes | With persistence |
| MinIO | Yes | S3-compatible storage |
| Mailpit | Yes | Email testing |
| Nginx | Yes | Dynamic multi-project routing |
| Traefik | Yes | Reverse proxy with SSL |
| RTMP Server | Yes | Live streaming with HLS |
| Whisper AI | Yes | php-ai container with transcription |
| Node.js 20 | Yes | Frontend build tooling |

## What Stays Project-Specific

These should remain in your project's `docker-compose.override.yml`:

| Service | Reason |
|---------|--------|
| Laravel Horizon | Uses app container, just different command |
| Laravel Reverb | WebSocket server specific to your app |
| Scheduler | Cron jobs specific to your app |
| E2E Testing (Playwright) | Test infrastructure is project-specific |
| Custom AI Models | Specialized ML models beyond Whisper |

## Migration Steps

### 1. Copy Custom Services to Override File

```bash
# Create override in project root
touch ~/projects/your-app/docker-compose.override.yml
```

### 2. Add Laravel-specific Services

```yaml
# docker-compose.override.yml
services:
  horizon:
    image: php  # Uses docker-local's PHP image
    container_name: your-app-horizon
    working_dir: /var/www/your-app
    volumes:
      - ${PROJECTS_PATH:-../projects}:/var/www:cached
    networks:
      - laravel-dev
    command: php artisan horizon
    depends_on:
      - redis
      - postgres

  reverb:
    image: php
    container_name: your-app-reverb
    working_dir: /var/www/your-app
    volumes:
      - ${PROJECTS_PATH:-../projects}:/var/www:cached
    ports:
      - "8080:8080"
    networks:
      - laravel-dev
    command: php artisan reverb:start --host=0.0.0.0 --port=8080

  scheduler:
    image: php
    container_name: your-app-scheduler
    working_dir: /var/www/your-app
    volumes:
      - ${PROJECTS_PATH:-../projects}:/var/www:cached
    networks:
      - laravel-dev
    command: sh -c "while true; do php artisan schedule:run; sleep 60; done"

networks:
  laravel-dev:
    external: true
```

### 3. Update .env for docker-local

```bash
# Database (uses docker-local's PostgreSQL)
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=your_app
DB_USERNAME=laravel
DB_PASSWORD=secret

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# MinIO
FILESYSTEM_DISK=s3
AWS_ENDPOINT=http://minio:9000
AWS_ACCESS_KEY_ID=minio
AWS_SECRET_ACCESS_KEY=minio123
AWS_BUCKET=your-app
AWS_USE_PATH_STYLE_ENDPOINT=true

# Mail
MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
```

### 4. For RTMP/Streaming Features

```bash
# RTMP is included by default, just start docker-local
docker-local up

# Create custom RTMP config with your callbacks (optional)
mkdir -p ~/projects/your-app/docker/rtmp
# Edit nginx-rtmp.conf with on_publish webhooks
```

### 5. Remove Old Docker Files

```bash
cd ~/projects/your-app
rm -rf docker/
rm docker-compose.yml
rm docker-compose.test.yml
# Keep docker-compose.override.yml for project-specific services
```

### 6. Start Using docker-local

```bash
docker-local up
docker-local open your-app
```

## Example: Complex App Migration

**Before (project-specific):**
```
myapp/
├── docker/
│   ├── app/Dockerfile          # Custom PHP with Whisper
│   ├── nginx/                  # nginx configs
│   ├── playwright/             # E2E testing
│   ├── rtmp-tester/            # Test tools
│   └── webrtc-tester/          # Test tools
├── docker-compose.yml          # 12 services
├── docker-compose.test.yml     # Testing
└── docker-compose.testing.yml  # E2E testing
```

**After (docker-local):**
```
myapp/
├── docker/
│   └── rtmp/nginx-rtmp.conf    # Only: Custom RTMP callbacks
├── docker-compose.override.yml # Horizon, Reverb, Scheduler
└── .env                        # Updated for docker-local
```

## Benefits

- Shared services across all projects
- Centralized updates and maintenance
- Consistent development environment
- Smaller project footprint
- Easy onboarding for team members

## Adding Custom Services

Create `~/.config/docker-local/docker-compose.override.yml` for global additions:

```yaml
services:
  elasticsearch:
    image: elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - laravel-dev
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9200/_cluster/health"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  elasticsearch_data:
```

Then restart:
```bash
docker-local restart
```
