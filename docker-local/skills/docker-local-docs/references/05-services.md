# Docker-Local Services

## Service URLs

| Service | URL |
|---------|-----|
| Your Projects | `https://<project>.test` |
| Traefik Dashboard | `https://traefik.localhost` |
| Mailpit | `https://mail.localhost` |
| MinIO Console | `https://minio.localhost` |

## Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| Traefik HTTP | 80 | HTTP (redirects to HTTPS) |
| Traefik HTTPS | 443 | HTTPS |
| MySQL | 3306 | Database |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache/Queue |
| MinIO API | 9000 | S3 API |
| MinIO Console | 9001 | Web UI |
| Mailpit SMTP | 1025 | Email |
| Mailpit Web | 8025 | Email UI |

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| MySQL (root) | root | secret |
| MySQL (user) | laravel | secret |
| PostgreSQL | laravel | secret |
| MinIO | minio | minio123 |

## All Included Services

All services are enabled by default. Simply run:

```bash
docker-local up
```

### RTMP Server (Live Streaming)

The RTMP server provides live streaming with HLS delivery:

| Endpoint | URL |
|----------|-----|
| RTMP Ingest | `rtmp://localhost:1935/live/<stream_key>` |
| HLS Playback | `http://localhost:8088/hls/<stream_key>.m3u8` |
| HLS (via Traefik) | `https://stream.localhost/hls/<stream_key>.m3u8` |
| Stats | `http://localhost:8088/stat` |

### Node.js Container

A dedicated Node.js 20 container for long-running build processes:

```bash
# Run npm commands
docker-compose exec node npm install
docker-compose exec node npm run dev
```

### PostgreSQL with pgvector

PostgreSQL 17 includes the pgvector extension for AI embeddings:

```sql
-- Enabled automatically, just use it
CREATE TABLE items (
  id SERIAL PRIMARY KEY,
  embedding vector(1536)
);

-- Similarity search
SELECT * FROM items ORDER BY embedding <-> '[...]' LIMIT 10;
```

### AI/Whisper Transcription

PHP-AI container with OpenAI Whisper for audio transcription:

```bash
# Run transcription
docker-compose exec php-ai whisper audio.mp3 --model base --language en

# Or from your Laravel app
docker-compose exec php-ai php artisan transcribe:audio path/to/audio.mp3
```

**Whisper Models:**

| Model | Size | Memory | Speed | Accuracy |
|-------|------|--------|-------|----------|
| tiny | 39M | ~1GB | Fastest | Lower |
| base | 74M | ~1GB | Fast | Good |
| small | 244M | ~2GB | Medium | Better |
| medium | 769M | ~5GB | Slow | High |
| large | 1550M | ~10GB | Slowest | Best |

Configure the model in `.env`:
```bash
WHISPER_MODEL=base
WHISPER_LANGUAGE=en
```

### Laravel Workers (Horizon, Reverb, Scheduler)

For Laravel-specific services, use the override stub as a template:

```bash
# Copy the stub
cp ~/.composer/vendor/mwguerra/docker-local/stubs/docker-compose.override.yml.stub \
   ~/.config/docker-local/docker-compose.override.yml

# Uncomment the services you need and customize
```

Available templates:
- **Horizon** - Queue worker with Laravel Horizon
- **Reverb** - WebSocket server for real-time features
- **Scheduler** - Cron-like task scheduler
- **Elasticsearch/Meilisearch** - Full-text search
- **Soketi** - Open-source Pusher alternative
