# Host Interaction: Ports, URLs & SSL

## Port Mapping

```yaml
services:
  web:
    ports:
      # Standard mapping
      - "8080:80"                    # HOST:CONTAINER

      # Localhost only (security)
      - "127.0.0.1:3000:3000"

      # Random host port
      - "80"                         # Container port 80 → random host port

      # UDP protocol
      - "53:53/udp"

      # Port range
      - "6000-6010:6000-6010"
```

## Port vs Expose

| Directive | Description |
|-----------|-------------|
| `ports` | Maps container port to host port |
| `expose` | Documents internal port, no host mapping |

```yaml
services:
  frontend:
    ports:
      - "80:80"  # Accessible from host

  api:
    expose:
      - "3000"  # Only accessible within Docker network
```

## SSL/TLS with Traefik (Recommended)

Traefik is a modern reverse proxy with automatic SSL certificate management:

```yaml
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    command:
      # API and Dashboard
      - "--api.dashboard=true"
      - "--api.insecure=false"

      # Docker provider
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=proxy"

      # Entrypoints
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"

      # HTTP to HTTPS redirect
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"

      # Let's Encrypt
      - "--certificatesresolvers.letsencrypt.acme.email=your-email@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"

    ports:
      - "80:80"
      - "443:443"

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_letsencrypt:/letsencrypt

    networks:
      - proxy

    labels:
      # Dashboard
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.yourdomain.com`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.middlewares=auth"
      - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$xyz..."

  # Your application
  webapp:
    build: ./app
    restart: unless-stopped
    networks:
      - proxy
      - internal
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.webapp.rule=Host(`app.yourdomain.com`)"
      - "traefik.http.routers.webapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.webapp.loadbalancer.server.port=3000"

networks:
  proxy:
    external: true
  internal:
    internal: true

volumes:
  traefik_letsencrypt:
```

## SSL with Nginx + Certbot

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro
    depends_on:
      - app

  certbot:
    image: certbot/certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

  app:
    build: .
    expose:
      - "3000"
```

**nginx.conf:**

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://app:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Self-Signed Certificates (Development)

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./ssl/privkey.pem \
  -out ./ssl/fullchain.pem \
  -subj "/CN=localhost"
```

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "443:443"
    volumes:
      - ./ssl:/etc/nginx/ssl:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
```

## Traefik Labels Reference

### Basic Routing
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.com`)"
  - "traefik.http.services.myapp.loadbalancer.server.port=3000"
```

### Path-Based Routing
```yaml
labels:
  - "traefik.http.routers.api.rule=Host(`example.com`) && PathPrefix(`/api`)"
  - "traefik.http.routers.api.middlewares=strip-api"
  - "traefik.http.middlewares.strip-api.stripprefix.prefixes=/api"
```

### Multiple Domains
```yaml
labels:
  - "traefik.http.routers.myapp.rule=Host(`app.com`) || Host(`www.app.com`)"
```

### Wildcard SSL
```yaml
labels:
  - "traefik.http.routers.myapp.tls.domains[0].main=example.com"
  - "traefik.http.routers.myapp.tls.domains[0].sans=*.example.com"
```

## Local Development with SSL

### Using mkcert

```bash
# Install mkcert
brew install mkcert  # macOS
# or
sudo apt install mkcert  # Linux

# Install local CA
mkcert -install

# Generate certificates
mkcert -cert-file ./ssl/cert.pem -key-file ./ssl/key.pem localhost 127.0.0.1 ::1
```

### Using Traefik for Local Dev

```yaml
services:
  traefik:
    image: traefik:v3.0
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./ssl:/etc/traefik/ssl:ro
    labels:
      - "traefik.http.routers.traefik.tls=true"

  app:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.localhost`)"
      - "traefik.http.routers.app.tls=true"
```

## WebSocket Support

```yaml
labels:
  - "traefik.http.routers.ws.rule=Host(`ws.example.com`)"
  - "traefik.http.services.ws.loadbalancer.server.port=8080"
```

```nginx
# Nginx WebSocket proxy
location /ws {
    proxy_pass http://app:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
}
```

## HTTP/2 Configuration

```nginx
server {
    listen 443 ssl http2;
    # ... SSL config
}
```

## Rate Limiting with Traefik

```yaml
labels:
  - "traefik.http.middlewares.ratelimit.ratelimit.average=100"
  - "traefik.http.middlewares.ratelimit.ratelimit.burst=50"
  - "traefik.http.routers.api.middlewares=ratelimit"
```

## CORS Headers

```yaml
labels:
  - "traefik.http.middlewares.cors.headers.accesscontrolallowmethods=GET,OPTIONS,PUT"
  - "traefik.http.middlewares.cors.headers.accesscontrolallowheaders=*"
  - "traefik.http.middlewares.cors.headers.accesscontrolalloworiginlist=https://app.com"
  - "traefik.http.middlewares.cors.headers.accesscontrolmaxage=100"
```
