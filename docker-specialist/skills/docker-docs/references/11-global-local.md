# Global vs Local Containers

## Global Containers (Machine-Wide Services)

Located in a dedicated directory, running shared services:

```
/opt/docker/                  # or ~/docker/
├── global/
│   ├── compose.yaml
│   ├── .env
│   │
│   ├── traefik/
│   │   ├── traefik.yaml
│   │   └── dynamic/
│   │
│   ├── portainer/
│   │   └── data/
│   │
│   └── monitoring/
│       ├── prometheus/
│       └── grafana/
```

**global/compose.yaml:**

```yaml
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik:/etc/traefik
      - traefik_certs:/letsencrypt
    networks:
      - proxy

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(`portainer.yourdomain.com`)"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"

networks:
  proxy:
    name: proxy
    driver: bridge

volumes:
  traefik_certs:
  portainer_data:
```

**Setup Commands:**

```bash
# Create the proxy network first
docker network create proxy

# Start global services
cd /opt/docker/global
docker compose up -d

# Enable on boot (systemd)
sudo systemctl enable docker
```

## Local Containers (Project-Specific)

Each project manages its own containers:

```
~/projects/
├── project-a/
│   ├── compose.yaml
│   └── ...
│
├── project-b/
│   ├── compose.yaml
│   └── ...
```

**project-a/compose.yaml:**

```yaml
services:
  app:
    build: .
    networks:
      - proxy  # Connect to global Traefik
      - internal
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.project-a.rule=Host(`project-a.localhost`)"
      - "traefik.docker.network=proxy"

  db:
    image: postgres:16
    networks:
      - internal
    volumes:
      - db_data:/var/lib/postgresql/data

networks:
  proxy:
    external: true  # Use global network
  internal:
    driver: bridge

volumes:
  db_data:
```

## Workflow Summary

```bash
# GLOBAL SERVICES (run once, always available)
cd /opt/docker/global
docker compose up -d

# PROJECT A (start when needed)
cd ~/projects/project-a
docker compose up -d

# PROJECT B (start when needed)
cd ~/projects/project-b
docker compose up -d

# Stop a project
cd ~/projects/project-a
docker compose down

# Global services remain running
```

## Common Global Services

### Traefik (Reverse Proxy)

```yaml
services:
  traefik:
    image: traefik:v3.0
    restart: always
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - proxy
```

### Portainer (Docker Management UI)

```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    ports:
      - "9443:9443"
    networks:
      - proxy

volumes:
  portainer_data:
```

### Mailhog (Email Testing)

```yaml
services:
  mailhog:
    image: mailhog/mailhog
    restart: unless-stopped
    ports:
      - "1025:1025"  # SMTP
      - "8025:8025"  # Web UI
    networks:
      - proxy
```

### Redis (Shared Cache)

```yaml
services:
  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    ports:
      - "127.0.0.1:6379:6379"
    networks:
      - proxy

volumes:
  redis_data:
```

## Connecting Local Projects to Global Services

### Using Global Traefik

```yaml
# Local project compose.yaml
services:
  app:
    build: .
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.localhost`)"
      - "traefik.http.services.myapp.loadbalancer.server.port=3000"
      - "traefik.docker.network=proxy"

networks:
  proxy:
    external: true
```

### Using Global Redis

```yaml
# Local project compose.yaml
services:
  app:
    build: .
    environment:
      - REDIS_URL=redis://redis:6379
    networks:
      - proxy  # Same network as global redis

networks:
  proxy:
    external: true
```

## Host Entries for Local Development

Add to `/etc/hosts`:

```
127.0.0.1 project-a.localhost
127.0.0.1 project-b.localhost
127.0.0.1 api.project-a.localhost
127.0.0.1 traefik.localhost
127.0.0.1 portainer.localhost
```

Or use a wildcard DNS service like `nip.io` or `sslip.io`:
- `myapp.127.0.0.1.nip.io` resolves to `127.0.0.1`

## Starting Global Services on Boot

### Using systemd

```ini
# /etc/systemd/system/docker-global.service
[Unit]
Description=Global Docker Services
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/docker/global
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable docker-global
sudo systemctl start docker-global
```

### Using cron

```bash
# Add to crontab
@reboot cd /opt/docker/global && docker compose up -d
```

## Project Isolation Strategies

### Fully Isolated (Default)

```yaml
# Each project has its own network
services:
  app:
    networks:
      - default

  db:
    networks:
      - default

# Networks are project-scoped by default
```

### Shared Database Server

```yaml
# Global database server
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: admin_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - databases

networks:
  databases:
    name: databases

volumes:
  postgres_data:
```

```yaml
# Local project uses global database
services:
  app:
    environment:
      - DATABASE_URL=postgresql://app_user:password@postgres:5432/app_db
    networks:
      - proxy
      - databases

networks:
  proxy:
    external: true
  databases:
    external: true
```
