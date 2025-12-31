# Docker-Local Overview

Complete Docker development environment for Laravel with a powerful CLI.

## Features

- **PHP 8.4** with Xdebug 3.4, FFmpeg, and all Laravel extensions
- **MySQL 9.1** and **PostgreSQL 17 with pgvector** (AI embeddings)
- **Redis 8** for cache, sessions, and queues
- **MinIO** S3-compatible object storage
- **Traefik 3.6** reverse proxy with automatic SSL
- **Mailpit** for email testing
- **RTMP Server** (optional) for live streaming with HLS
- **Whisper AI** (optional) for audio transcription
- **Node.js 20** (optional) standalone container for asset builds
- **50+ CLI commands** for rapid development
- **Multi-project support** with automatic isolation
- **Cross-platform** - Linux, macOS, and Windows (WSL2)

## System Requirements

### All Platforms

| Software | Minimum Version | Check Command |
|----------|-----------------|---------------|
| Docker | 24.0+ | `docker --version` |
| Docker Compose | 2.20+ | `docker compose version` |
| PHP | 8.2+ | `php --version` |
| Composer | 2.6+ | `composer --version` |

### System Requirements

- **RAM:** 8GB minimum, 16GB recommended
- **Disk:** 20GB free space
- **CPU:** 64-bit processor with virtualization support

## Package Location

```
~/.composer/vendor/mwguerra/docker-local/   # Package source (Composer managed)
~/.config/docker-local/                     # User configuration (persistent)
~/projects/                                 # Your Laravel projects
```

## Package Structure

```
docker-local/
├── bin/
│   └── docker-local              # CLI entry point
├── src/                          # PHP application code
├── lib/
│   └── config.sh                 # Bash helper functions
├── scripts/                      # Shell scripts for operations
├── stubs/                        # Templates with placeholders
├── templates/                    # Installation templates
├── tests/                        # Pest PHP tests
├── docs/                         # Extended documentation
├── docker-compose.yml            # Main orchestration file
├── php/                          # PHP-FPM container
├── nginx/                        # Nginx configuration
├── mysql/                        # MySQL configuration
├── postgres/                     # PostgreSQL configuration
├── redis/                        # Redis configuration
├── traefik/                      # Traefik configuration
└── rtmp/                         # RTMP streaming config
```

## Configuration File

Configuration is stored in `~/.config/docker-local/config.json`:

```json
{
  "version": "2.0.0",
  "projects_path": "~/projects",
  "editor": "code",
  "mysql": {
    "version": "9.1",
    "port": 3306,
    "root_password": "secret",
    "database": "laravel",
    "user": "laravel",
    "password": "secret"
  },
  "postgres": {
    "version": "17",
    "port": 5432,
    "database": "laravel",
    "user": "laravel",
    "password": "secret"
  },
  "redis": {
    "version": "8",
    "port": 6379
  },
  "minio": {
    "api_port": 9000,
    "console_port": 9001,
    "root_user": "minio",
    "root_password": "minio123"
  },
  "mailpit": {
    "smtp_port": 1025,
    "web_port": 8025
  },
  "xdebug": {
    "enabled": true,
    "mode": "develop,debug"
  }
}
```
