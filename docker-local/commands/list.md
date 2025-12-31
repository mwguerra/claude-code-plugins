---
description: List all Laravel projects managed by docker-local
---

# Docker-Local List Projects

List all Laravel projects with their URLs and status.

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

## Run List Command

```bash
docker-local list
```

## Output Format

```
┌─────────────────────────────────────────────────────────────────┐
│  Laravel Projects in ~/projects                                 │
└─────────────────────────────────────────────────────────────────┘

NAME                 URL                                 STATUS
────────────────────────────────────────────────────────────────
blog                 https://blog.test                   ✓ accessible
api                  https://api.test                    ○ DNS ok
shop                 https://shop.test                   ✗ DNS not configured
```

## Status Meanings

- **✓ accessible**: Project is running and reachable via HTTPS
- **○ DNS ok**: DNS resolves but HTTPS not responding
- **✗ DNS not configured**: Cannot resolve hostname

## Fix DNS Issues

```bash
# Option 1: Setup dnsmasq (recommended)
sudo docker-local setup:dns

# Option 2: Add to /etc/hosts
sudo docker-local setup:hosts
```

## Open a Project

```bash
# Open current project
docker-local open

# Open specific project
docker-local open blog
```

$ARGUMENTS
