---
description: Generate optimized multi-stage Dockerfile with caching, non-root user, and health checks
allowed-tools: Read, Write, Glob, Grep
argument-hint: "[--base image] [--multistage] [--output path]"
---

# Generate Dockerfile

You are generating an optimized Dockerfile. Follow these steps:

## 1. Analyze the Application

Determine:
- Language and version (Node.js, Python, PHP, Go, Rust, etc.)
- Framework (Express, Django, Laravel, etc.)
- Build requirements
- Runtime dependencies
- Entry point

## 2. Consult Documentation

Read the documentation:
- `skills/docker-docs/references/02-dockerfile.md` for complete Dockerfile patterns

## 3. Apply Best Practices

### Base Image Selection
- Use official images
- Prefer Alpine variants for smaller size
- Pin specific versions (not `latest`)

### Multi-Stage Builds
```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS production
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER node
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Layer Optimization
- Copy dependency files first
- Install dependencies before copying source
- Use .dockerignore to exclude unnecessary files

### Security
- Run as non-root user
- Don't store secrets in image
- Use multi-stage to exclude build tools

### Health Check
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

## 4. Generate the Dockerfile

Create a production-ready Dockerfile with:
- Clear comments
- Optimized layer caching
- Security best practices
- Appropriate health check

$ARGUMENTS
