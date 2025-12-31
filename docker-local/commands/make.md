---
description: Create a new Laravel project with docker-local (MySQL or PostgreSQL)
---

# Docker-Local Make Project

Create a new Laravel project with complete Docker configuration.

## Create with MySQL (Default)

```bash
docker-local make:laravel myapp
```

## Create with PostgreSQL

```bash
docker-local make:laravel myapp --postgres
```

## What Gets Created

1. **Laravel project** via Composer
2. **Databases**: `myapp` and `myapp_testing`
3. **MinIO bucket**: `myapp`
4. **Redis isolation**: Unique DB numbers
5. **Cache prefix**: `myapp_`
6. **Reverb credentials**: Unique app ID/key/secret
7. **Configured .env**: All Docker service connections

## After Creation

```bash
# Navigate to project
cd ~/projects/myapp

# Open in browser
docker-local open

# Run tinker
docker-local tinker

# Create models
docker-local new:model Post -mcr
```

## Project URLs

| Project | URL |
|---------|-----|
| myapp | https://myapp.test |
| mailpit | https://mail.localhost |
| minio | https://minio.localhost |

## Verify Setup

```bash
# Check .env configuration
docker-local env:check

# Run migrations
docker-local db:fresh
```

$ARGUMENTS
