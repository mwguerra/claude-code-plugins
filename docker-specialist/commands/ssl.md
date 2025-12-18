---
description: Configure SSL/TLS with Traefik or Nginx reverse proxy
---

# Configure SSL/TLS

You are setting up SSL/TLS for Docker services. Follow these steps:

## 1. Determine SSL Approach

Choose the appropriate method:
- **Traefik**: Automatic Let's Encrypt certificates (recommended for production)
- **Nginx**: Manual or certbot-managed certificates
- **Development**: Self-signed certificates

## 2. Consult Documentation

Read the documentation:
- `skills/docker-docs/references/07-ports-ssl.md` for complete SSL configurations

## 3. Traefik Configuration (Recommended)

### docker-compose.yaml
```yaml
services:
  traefik:
    image: traefik:v3.0
    restart: unless-stopped
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - letsencrypt:/letsencrypt
    networks:
      - proxy

  app:
    build: .
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`${DOMAIN}`)"
      - "traefik.http.routers.app.entrypoints=websecure"
      - "traefik.http.routers.app.tls.certresolver=letsencrypt"
    networks:
      - proxy
      - backend

volumes:
  letsencrypt:

networks:
  proxy:
  backend:
    internal: true
```

## 4. Nginx Configuration (Alternative)

### docker-compose.yaml
```yaml
services:
  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - app
    networks:
      - frontend

  app:
    build: .
    expose:
      - "3000"
    networks:
      - frontend
      - backend
```

### nginx.conf
```nginx
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;

    ssl_certificate /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;

    location / {
        proxy_pass http://app:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 5. Development Self-Signed Certificates

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./certs/privkey.pem \
  -out ./certs/fullchain.pem \
  -subj "/CN=localhost"
```

## 6. Post-Configuration

After setup:
- Verify SSL with: `curl -I https://yourdomain.com`
- Check certificate: `openssl s_client -connect yourdomain.com:443`
- Test redirect from HTTP to HTTPS

$ARGUMENTS
