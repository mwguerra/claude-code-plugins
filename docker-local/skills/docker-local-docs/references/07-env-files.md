# Docker-Local Environment Files

Docker-local uses **two separate `.env` files** for different purposes:

| File | Scope | Used By | Location |
|------|-------|---------|----------|
| `.env.example` | Docker infrastructure | `docker-compose.yml` | `~/.config/docker-local/.env` |
| `laravel.env.example` | Laravel application | Laravel framework | `~/projects/<project>/.env` |

## Docker .env (Infrastructure)

Controls **how Docker containers are built and connected**:

```bash
PROJECTS_PATH=~/projects       # Where your projects live
MYSQL_PORT=3306               # Port exposed to your host machine
MYSQL_ROOT_PASSWORD=secret    # Container MySQL password
XDEBUG_ENABLED=true           # PHP container configuration
```

This file is copied to `~/.config/docker-local/.env` and read by `docker-compose.yml` via `${VARIABLE}` syntax.

## Laravel .env (Application)

Controls **how Laravel connects to services from inside the container**:

```bash
DB_HOST=mysql                 # Docker service name (NOT localhost!)
DB_PORT=3306                  # Internal container port
REDIS_HOST=redis              # Docker service name
MAIL_HOST=mailpit             # Docker service name
```

This file is copied to each project's `.env` (`~/projects/my-app/.env`) and read by Laravel via `env()` and `config()`.

## Why Both Files Exist

**Key insight:** The same service has different addresses depending on where you're accessing it from:

| Accessing From | MySQL Address | Why |
|----------------|---------------|-----|
| Your host (TablePlus, DBeaver) | `localhost:3306` | Uses exposed port |
| Inside PHP container (Laravel) | `mysql:3306` | Uses Docker DNS |

The Docker `.env` configures what ports are **exposed to your machine**, while the Laravel `.env` configures how to reach services **via Docker's internal network**.

## Related Files

```
docker-local/
├── .env.example              # Docker infrastructure template
├── laravel.env.example       # Laravel application template (manual use)
└── stubs/
    ├── .env.stub             # Docker template (for CLI automation)
    └── laravel.env.stub      # Laravel template with {{PLACEHOLDERS}}
```

The `stubs/` versions contain placeholders like `{{PROJECT_NAME}}` for automated project creation via `docker-local make:laravel`.

## Complete Laravel .env Template

```bash
APP_NAME=MyApp
APP_ENV=local
APP_KEY=base64:...
APP_DEBUG=true
APP_URL=https://myapp.test

LOG_CHANNEL=stack
LOG_LEVEL=debug

# Database - use Docker service names
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=myapp
DB_USERNAME=laravel
DB_PASSWORD=secret

# Redis - use Docker service name
REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

# IMPORTANT: Unique isolation values
CACHE_DRIVER=redis
CACHE_PREFIX=myapp_
REDIS_CACHE_DB=0
REDIS_SESSION_DB=1
REDIS_QUEUE_DB=2

# Session
SESSION_DRIVER=redis
SESSION_LIFETIME=120

# Queue
QUEUE_CONNECTION=redis

# Mail - use Mailpit
MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"

# MinIO/S3
FILESYSTEM_DISK=s3
AWS_ACCESS_KEY_ID=minio
AWS_SECRET_ACCESS_KEY=minio123
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=myapp
AWS_ENDPOINT=http://minio:9000
AWS_USE_PATH_STYLE_ENDPOINT=true

# Reverb/WebSockets (unique per project)
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=123456
REVERB_APP_KEY=unique-key
REVERB_APP_SECRET=unique-secret
REVERB_HOST="localhost"
REVERB_PORT=8080
REVERB_SCHEME=http
```

## Common Mistakes

### Wrong Database Host
```bash
# WRONG - from host perspective
DB_HOST=localhost

# CORRECT - from inside container
DB_HOST=mysql
```

### Missing Cache Prefix
```bash
# WRONG - will conflict with other projects
CACHE_PREFIX=laravel_cache_

# CORRECT - unique per project
CACHE_PREFIX=myapp_
```

### Overlapping Redis DBs
```bash
# Project 1 - OK
REDIS_CACHE_DB=0
REDIS_SESSION_DB=1
REDIS_QUEUE_DB=2

# Project 2 - CONFLICT!
REDIS_CACHE_DB=0  # Same as Project 1!

# Project 2 - CORRECT
REDIS_CACHE_DB=3
REDIS_SESSION_DB=4
REDIS_QUEUE_DB=5
```
