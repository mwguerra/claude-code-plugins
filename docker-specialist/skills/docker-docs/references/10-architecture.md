# Project Architecture & Folder Structure

## Single Project Structure

```
my-project/
├── .env                      # Environment variables
├── .env.example              # Template (commit this)
├── .gitignore
├── compose.yaml              # Main compose file
├── compose.override.yaml     # Development overrides (auto-loaded)
├── compose.prod.yaml         # Production overrides
├── Dockerfile
├── .dockerignore
│
├── src/                      # Application source code
│   └── ...
│
├── config/                   # Configuration files
│   ├── nginx/
│   │   └── nginx.conf
│   └── postgres/
│       └── postgresql.conf
│
├── scripts/                  # Utility scripts
│   ├── backup.sh
│   └── deploy.sh
│
├── init-scripts/             # Database initialization
│   └── 01-schema.sql
│
└── secrets/                  # Sensitive files (gitignored)
    ├── db_password.txt
    └── api_key.txt
```

## Multi-Service Project Structure

```
my-platform/
├── .env
├── compose.yaml              # Orchestrates all services
├── compose.override.yaml
├── compose.prod.yaml
│
├── services/
│   ├── api/
│   │   ├── Dockerfile
│   │   ├── .dockerignore
│   │   ├── package.json
│   │   └── src/
│   │
│   ├── frontend/
│   │   ├── Dockerfile
│   │   ├── .dockerignore
│   │   └── src/
│   │
│   └── worker/
│       ├── Dockerfile
│       ├── .dockerignore
│       └── src/
│
├── infrastructure/
│   ├── nginx/
│   │   └── nginx.conf
│   ├── traefik/
│   │   └── traefik.yaml
│   └── postgres/
│       └── init.sql
│
└── scripts/
    └── deploy.sh
```

**compose.yaml for Multi-Service:**

```yaml
services:
  api:
    build:
      context: ./services/api
      dockerfile: Dockerfile
    depends_on:
      - db

  frontend:
    build:
      context: ./services/frontend
      dockerfile: Dockerfile
    depends_on:
      - api

  worker:
    build:
      context: ./services/worker
      dockerfile: Dockerfile
    depends_on:
      - db
      - redis

  db:
    image: postgres:16
    volumes:
      - ./infrastructure/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql

  redis:
    image: redis:7-alpine
```

## Monorepo Structure

```
monorepo/
├── .env
├── compose.yaml
│
├── packages/
│   ├── shared/              # Shared libraries
│   │   ├── package.json
│   │   └── src/
│   │
│   ├── api/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── src/
│   │
│   └── web/
│       ├── Dockerfile
│       ├── package.json
│       └── src/
│
├── infrastructure/
│   └── docker/
│       ├── api.Dockerfile
│       └── web.Dockerfile
│
└── scripts/
```

## Microservices Structure

```
microservices/
├── docker/
│   └── compose.yaml          # All services
│
├── services/
│   ├── user-service/
│   │   ├── compose.yaml      # Service-specific
│   │   ├── Dockerfile
│   │   └── src/
│   │
│   ├── order-service/
│   │   ├── compose.yaml
│   │   ├── Dockerfile
│   │   └── src/
│   │
│   └── payment-service/
│       ├── compose.yaml
│       ├── Dockerfile
│       └── src/
│
├── infrastructure/
│   ├── api-gateway/
│   ├── service-mesh/
│   └── monitoring/
│
└── scripts/
    ├── start-all.sh
    └── stop-all.sh
```

## Laravel Project Structure

```
laravel-project/
├── .env
├── compose.yaml
├── Dockerfile
├── .dockerignore
│
├── app/
├── bootstrap/
├── config/
├── database/
├── public/
├── resources/
├── routes/
├── storage/
├── tests/
│
├── docker/
│   ├── nginx/
│   │   └── default.conf
│   ├── php/
│   │   └── php.ini
│   └── supervisor/
│       └── supervisord.conf
│
└── scripts/
    └── entrypoint.sh
```

## Node.js Project Structure

```
nodejs-project/
├── .env
├── compose.yaml
├── Dockerfile
├── .dockerignore
│
├── src/
│   ├── controllers/
│   ├── models/
│   ├── routes/
│   ├── services/
│   └── index.js
│
├── config/
│   └── default.json
│
├── tests/
│
└── docker/
    └── nginx/
```

## File Naming Conventions

| File | Purpose | Auto-loaded |
|------|---------|-------------|
| `compose.yaml` | Main configuration | Yes |
| `docker-compose.yaml` | Legacy name | Yes |
| `compose.override.yaml` | Development overrides | Yes |
| `docker-compose.override.yaml` | Legacy override | Yes |
| `compose.prod.yaml` | Production config | No |
| `compose.dev.yaml` | Development config | No |
| `compose.test.yaml` | Testing config | No |

## Configuration Management

### Per-Environment Configuration

```
config/
├── default.json          # Base config
├── development.json      # Dev overrides
├── staging.json          # Staging overrides
├── production.json       # Prod overrides
└── custom-environment-variables.json  # Env var mapping
```

### Docker-Specific Config

```
docker/
├── development/
│   ├── Dockerfile
│   └── nginx.conf
│
├── production/
│   ├── Dockerfile
│   └── nginx.conf
│
└── scripts/
    ├── entrypoint.sh
    └── healthcheck.sh
```

## Gitignore for Docker Projects

```gitignore
# Environment
.env
.env.local
.env.*.local
!.env.example

# Secrets
secrets/
*.pem
*.key

# Docker volumes data
data/
volumes/

# Logs
logs/
*.log

# Node
node_modules/

# Build artifacts
dist/
build/

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db
```

## Makefile for Docker Operations

```makefile
.PHONY: help build up down restart logs shell

help:
	@echo "Available commands:"
	@echo "  make build    - Build images"
	@echo "  make up       - Start services"
	@echo "  make down     - Stop services"
	@echo "  make restart  - Restart services"
	@echo "  make logs     - View logs"
	@echo "  make shell    - Shell into app"

build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f

shell:
	docker compose exec app sh
```
