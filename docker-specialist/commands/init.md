---
name: init
description: Initialize Docker environment for a project with Dockerfile, compose configuration, and supporting files
---

# Initialize Docker Environment

You are initializing a Docker environment for a project. Follow these steps:

## 1. Analyze the Project

First, examine the current project to determine:
- Primary language and framework (check for package.json, requirements.txt, composer.json, go.mod, etc.)
- Required services (database, cache, queue, etc.)
- Existing Docker files (if any)

## 2. Consult Documentation

Read the relevant documentation files:
- `skills/docker-docs/references/02-dockerfile.md` for Dockerfile patterns
- `skills/docker-docs/references/03-compose-fundamentals.md` for compose structure
- `skills/docker-docs/references/05-databases.md` if database is needed
- `skills/docker-docs/references/10-architecture.md` for project structure

## 3. Generate Files

Create the following files based on project type:

### Dockerfile
- Use appropriate base image for the language
- Multi-stage build for smaller images
- Non-root user for security
- Health check
- Proper COPY order for layer caching

### docker-compose.yaml
- No version field (modern compose)
- Health checks for all services
- Dependencies with conditions
- Named volumes for persistence
- Proper networking (internal for databases)

### .dockerignore
- Exclude node_modules, .git, .env, logs, etc.

### .env.example
- Document all required environment variables
- Include sensible defaults where appropriate

## 4. Provide Usage Instructions

After generating files, explain:
- How to start services: `docker compose up -d`
- How to view logs: `docker compose logs -f`
- How to stop services: `docker compose down`
- Development workflow tips

$ARGUMENTS
