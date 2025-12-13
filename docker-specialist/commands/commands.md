---
name: commands
description: Show essential Docker and Docker Compose commands reference
---

# Docker Commands Reference

Here are the essential Docker and Docker Compose commands:

## Docker Compose Commands

### Lifecycle
```bash
# Start services (detached)
docker compose up -d

# Start with rebuild
docker compose up -d --build

# Stop services
docker compose down

# Stop and remove volumes
docker compose down -v

# Restart services
docker compose restart

# Restart specific service
docker compose restart servicename
```

### Viewing Status
```bash
# List running containers
docker compose ps

# List all containers (including stopped)
docker compose ps -a

# View logs
docker compose logs

# Follow logs
docker compose logs -f

# Logs for specific service
docker compose logs -f servicename

# Last 100 lines
docker compose logs --tail=100
```

### Executing Commands
```bash
# Run command in container
docker compose exec servicename command

# Shell into container
docker compose exec servicename sh

# Run as root
docker compose exec -u root servicename sh

# One-off container
docker compose run servicename command
```

### Building
```bash
# Build images
docker compose build

# Build without cache
docker compose build --no-cache

# Build specific service
docker compose build servicename

# Pull latest images
docker compose pull
```

## Docker Commands

### Container Management
```bash
# List running containers
docker ps

# List all containers
docker ps -a

# Stop container
docker stop containername

# Remove container
docker rm containername

# Force remove running container
docker rm -f containername
```

### Images
```bash
# List images
docker images

# Remove image
docker rmi imagename

# Remove unused images
docker image prune -a
```

### Volumes
```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect volumename

# Remove volume
docker volume rm volumename

# Remove unused volumes
docker volume prune
```

### Networks
```bash
# List networks
docker network ls

# Inspect network
docker network inspect networkname

# Create network
docker network create networkname
```

### System
```bash
# Show disk usage
docker system df

# Detailed disk usage
docker system df -v

# Clean everything unused
docker system prune -a --volumes

# View real-time stats
docker stats
```

### Debugging
```bash
# Inspect container
docker inspect containername

# View container logs
docker logs containername

# Follow logs
docker logs -f containername

# Copy files from container
docker cp containername:/path/in/container ./local/path

# Execute command in container
docker exec -it containername sh
```

## Common Workflows

### Development
```bash
# Start with live reload
docker compose up

# Rebuild and restart
docker compose up -d --build

# View logs while developing
docker compose logs -f app
```

### Debugging
```bash
# Check what's running
docker compose ps

# Check logs for errors
docker compose logs --tail=100

# Shell into container
docker compose exec app sh

# Check container health
docker inspect --format='{{.State.Health.Status}}' containername
```

### Cleanup
```bash
# Stop everything
docker compose down

# Remove volumes too
docker compose down -v

# Full system cleanup
docker system prune -a --volumes
```

### Database Operations
```bash
# PostgreSQL backup
docker compose exec -T db pg_dumpall -c -U user > backup.sql

# PostgreSQL restore
docker compose exec -T db psql -U user -d dbname < backup.sql

# MySQL backup
docker compose exec -T db mysqldump -u root -p"$PASS" --all-databases > backup.sql

# Connect to PostgreSQL
docker compose exec db psql -U user -d dbname

# Connect to MySQL
docker compose exec db mysql -u root -p
```

$ARGUMENTS
