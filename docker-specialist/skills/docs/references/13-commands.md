# Essential Commands Reference

## Container Management

```bash
# Start services
docker compose up                    # Foreground
docker compose up -d                 # Detached (background)
docker compose up --build            # Rebuild images first
docker compose up -d --force-recreate  # Recreate containers

# Stop services
docker compose down                  # Stop and remove containers
docker compose down -v               # Also remove volumes
docker compose down --rmi all        # Also remove images

# Restart services
docker compose restart               # Restart all
docker compose restart api           # Restart specific service

# View status
docker compose ps                    # List containers
docker compose ps -a                 # Include stopped

# View logs
docker compose logs                  # All services
docker compose logs -f               # Follow
docker compose logs -f api           # Specific service
docker compose logs --tail=100 api   # Last 100 lines

# Execute commands
docker compose exec api bash         # Interactive shell
docker compose exec db psql -U user  # Database CLI
docker compose run api npm test      # Run one-off command

# Scale services
docker compose up -d --scale worker=3
```

## Image Management

```bash
# Build images
docker compose build                 # Build all
docker compose build --no-cache      # Without cache
docker compose build api             # Specific service

# Pull images
docker compose pull                  # Pull all images

# List images
docker images

# Remove images
docker rmi image_name
docker image prune                   # Remove unused
docker image prune -a                # Remove all unused
```

## Volume Management

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect myproject_postgres_data

# Create volume
docker volume create my-volume

# Remove volume
docker volume rm my-volume

# Remove unused volumes
docker volume prune

# Backup volume
docker run --rm -v myproject_data:/data -v $(pwd):/backup \
    alpine tar czf /backup/data-backup.tar.gz -C /data .

# Restore volume
docker run --rm -v myproject_data:/data -v $(pwd):/backup \
    alpine tar xzf /backup/data-backup.tar.gz -C /data
```

## Network Management

```bash
# List networks
docker network ls

# Create network
docker network create proxy

# Inspect network
docker network inspect proxy

# Remove network
docker network rm network_name

# Remove unused networks
docker network prune

# Connect container to network
docker network connect proxy container_name

# Disconnect container from network
docker network disconnect proxy container_name
```

## Cleanup Commands

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune
docker image prune -a    # Including tagged images

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune

# Remove everything unused
docker system prune
docker system prune -a --volumes  # Including volumes

# Check disk usage
docker system df
docker system df -v  # Verbose
```

## Container Inspection

```bash
# View container details
docker inspect container_name

# View container logs
docker logs container_name
docker logs -f container_name           # Follow
docker logs --since 10m container_name  # Last 10 minutes
docker logs --tail 100 container_name   # Last 100 lines

# View container processes
docker top container_name

# View container stats
docker stats
docker stats container_name

# View container changes
docker diff container_name
```

## Executing Commands

```bash
# Interactive shell
docker compose exec app bash
docker compose exec app sh          # For Alpine

# Run command
docker compose exec app npm test
docker compose exec db psql -U postgres

# Run as root
docker compose exec -u root app bash

# Run with environment variable
docker compose exec -e DEBUG=true app npm test

# One-off container
docker compose run --rm app npm test
docker compose run --rm -v $(pwd):/app app npm install
```

## Copying Files

```bash
# Copy from container
docker cp container_name:/app/file.txt ./file.txt

# Copy to container
docker cp ./file.txt container_name:/app/file.txt

# Using compose
docker compose cp app:/app/logs ./logs
docker compose cp ./config app:/app/config
```

## Debugging Commands

```bash
# Shell into running container
docker compose exec app sh

# Shell into failed container
docker compose run --entrypoint sh app

# View container resource usage
docker stats

# View container processes
docker compose top

# View real-time events
docker events

# Check container health
docker inspect --format='{{json .State.Health}}' container_name | jq
```

## Docker Compose Config

```bash
# Validate compose file
docker compose config

# View parsed config
docker compose config --format json

# Check specific service
docker compose config --services

# View volumes
docker compose config --volumes

# View networks
docker compose config --networks
```

## Quick Reference Card

```bash
# ==========================================
# STARTING SERVICES
# ==========================================
docker compose up -d              # Start all (detached)
docker compose up -d --build      # Rebuild then start
docker compose up -d service      # Start specific service

# ==========================================
# STOPPING/RESTARTING (DATA SAFE)
# ==========================================
docker compose stop               # Stop (keeps containers)
docker compose start              # Start stopped containers
docker compose restart            # Restart all
docker compose restart api        # Restart specific service

# ==========================================
# RECREATING (KEEPS VOLUMES/DATA)
# ==========================================
docker compose up -d --force-recreate    # Fresh containers, keep data
docker compose up -d --build             # Rebuild images, keep data

# ==========================================
# RESET (DATA LOSS WARNING)
# ==========================================
docker compose down               # Remove containers (KEEPS volumes)
docker compose down -v            # Remove containers AND volumes (DELETES DATA)
docker compose down -v --rmi all  # Remove everything

# ==========================================
# LOGS & DEBUGGING
# ==========================================
docker compose logs -f            # Follow all logs
docker compose logs -f api        # Follow specific service
docker compose exec app bash      # Shell access
docker compose exec db psql -U postgres  # Database shell

# ==========================================
# DATABASE BACKUP/RESTORE
# ==========================================
# PostgreSQL
docker compose exec -T db pg_dump -U user dbname > backup.sql
docker compose exec -T db psql -U user dbname < backup.sql

# MySQL
docker compose exec -T db mysqldump -u root -p"$PASS" db > backup.sql
docker compose exec -T db mysql -u root -p"$PASS" db < backup.sql

# ==========================================
# STATUS & INFO
# ==========================================
docker compose ps                 # Container status
docker compose ps -a              # Include stopped
docker compose config             # Validate compose file
docker stats                      # Resource usage
```
