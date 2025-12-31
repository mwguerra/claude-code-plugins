---
description: Run comprehensive health check on docker-local environment
---

# Docker-Local Doctor

Run a full diagnostic of your docker-local environment.

## 0. Prerequisite Check

**FIRST, verify docker-local is installed:**

```bash
which docker-local > /dev/null 2>&1 && echo "docker-local: OK" || echo "docker-local: NOT INSTALLED"
```

**If NOT installed, ask user to install:**
```bash
composer global require mwguerra/docker-local
export PATH="$HOME/.composer/vendor/bin:$PATH"
docker-local init
```

## 1. Run Doctor Command

```bash
docker-local doctor
```

This checks:
- System requirements (Docker, PHP, Composer versions)
- Configuration files
- Container health
- Network connectivity
- DNS resolution
- SSL certificates
- Project configurations

## 2. Check System Requirements

If doctor is unavailable, check manually:

```bash
# Docker (24.0+)
docker --version

# Docker Compose (2.20+)
docker compose version

# PHP (8.2+)
php --version

# Composer (2.6+)
composer --version
```

## 3. Check Configuration

```bash
# View current config
docker-local config

# Check config directory
ls -la ~/.config/docker-local/
```

## 4. Audit All Projects

```bash
# Check for conflicts
docker-local env:check --all
```

## 5. Common Fixes

### Missing Configuration
```bash
docker-local init
```

### Outdated Images
```bash
docker-local update
```

### Certificate Issues
```bash
docker-local init --certs
```

### Service Problems
```bash
docker-local restart
```

$ARGUMENTS
