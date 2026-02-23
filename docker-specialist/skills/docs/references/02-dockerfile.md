# Dockerfile Structure & Instructions

A Dockerfile is a sequential script that defines how to build a Docker image. Each instruction creates a layer in the final image.

## Basic Dockerfile Structure

```dockerfile
# syntax=docker/dockerfile:1

# 1. Base Image
FROM node:20-alpine

# 2. Metadata
LABEL maintainer="your-email@example.com"
LABEL version="1.0"

# 3. Environment Variables
ENV NODE_ENV=production
ENV APP_PORT=3000

# 4. Working Directory
WORKDIR /app

# 5. Copy Dependencies First (for better caching)
COPY package*.json ./

# 6. Install Dependencies
RUN npm ci --only=production

# 7. Copy Application Code
COPY . .

# 8. Create Non-Root User
RUN addgroup -g 10001 appgroup && \
    adduser -u 10001 -G appgroup -D appuser
USER appuser

# 9. Expose Port
EXPOSE 3000

# 10. Health Check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# 11. Default Command
CMD ["node", "dist/index.js"]
```

## Essential Dockerfile Instructions

### FROM - Base Image Selection

```dockerfile
# Use specific version tags (avoid :latest in production)
FROM python:3.12-slim

# Multi-stage builds for smaller images
FROM node:20 AS builder
WORKDIR /app
COPY . .
RUN npm ci && npm run build

FROM node:20-alpine AS runtime
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/index.js"]
```

**Best Practices:**
- Use official images from Docker Hub
- Prefer slim/alpine variants for smaller images
- Pin to specific versions (e.g., `python:3.12-slim` not `python:latest`)

### RUN - Execute Commands

```dockerfile
# BAD: Multiple RUN instructions create multiple layers
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get clean

# GOOD: Combine commands and clean up in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*
```

### COPY vs ADD

```dockerfile
# COPY: Simple file copying (preferred)
COPY requirements.txt /app/
COPY src/ /app/src/

# ADD: Use only when you need:
# - Automatic tar extraction
# - Remote URL fetching (not recommended)
ADD archive.tar.gz /app/
```

**Rule:** Use `COPY` unless you specifically need `ADD`'s features.

### WORKDIR - Set Working Directory

```dockerfile
# Always use WORKDIR instead of RUN cd
WORKDIR /app

# Can chain WORKDIR
WORKDIR /app
WORKDIR src  # Now at /app/src
```

### USER - Run as Non-Root

```dockerfile
# Create and switch to non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
USER appuser

# For Alpine
RUN addgroup -g 10001 appgroup && \
    adduser -u 10001 -G appgroup -D appuser
USER appuser
```

### EXPOSE - Document Ports

```dockerfile
# Document which ports the container listens on
EXPOSE 3000
EXPOSE 443/tcp
EXPOSE 53/udp
```

Note: `EXPOSE` is documentation only; use `-p` flag or compose `ports` to publish.

### CMD vs ENTRYPOINT

```dockerfile
# CMD: Default command, easily overridden
CMD ["npm", "start"]

# ENTRYPOINT: Fixed command, args appended
ENTRYPOINT ["python", "app.py"]
CMD ["--port", "8000"]  # Default args

# Running: docker run myimage --port 9000
# Executes: python app.py --port 9000
```

### HEALTHCHECK

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1
```

## Multi-Stage Builds

Multi-stage builds create smaller, more secure production images:

```dockerfile
# Stage 1: Build
FROM node:20 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production
FROM node:20-alpine AS production
WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./

# Security: Non-root user
RUN addgroup -g 1001 nodejs && \
    adduser -u 1001 -G nodejs -D nodejs
USER nodejs

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

## .dockerignore

Always create a `.dockerignore` file:

```plaintext
# Dependencies
node_modules/
vendor/
__pycache__/
*.pyc

# Build artifacts
dist/
build/
*.egg-info/

# Development files
.git/
.gitignore
.env
.env.*
*.md
README*
Dockerfile*
docker-compose*
.dockerignore

# IDE
.vscode/
.idea/
*.swp

# Testing
coverage/
.pytest_cache/
tests/

# Logs
*.log
logs/
```

## Common Dockerfile Patterns

### Node.js Application

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
USER node
EXPOSE 3000
CMD ["node", "src/index.js"]
```

### Python Application

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
USER nobody
EXPOSE 8000
CMD ["python", "app.py"]
```

### PHP/Laravel Application

```dockerfile
FROM php:8.3-fpm-alpine
WORKDIR /var/www/html
RUN apk add --no-cache postgresql-dev && \
    docker-php-ext-install pdo pdo_pgsql
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
COPY . .
RUN composer install --no-dev --optimize-autoloader
EXPOSE 9000
CMD ["php-fpm"]
```

### Go Application

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
```
