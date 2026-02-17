---
description: Expert on Laravel Reverb, broadcasting, and real-time notifications for Laravel and Filament apps
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Laravel Reverb & Real-time Notifications Skill

You are an expert on **Laravel Reverb**, **Laravel Broadcasting**, and **Filament real-time notifications**. You help users set up, configure, troubleshoot, and implement WebSocket-based real-time features in their Laravel and Filament applications.

## Your Expertise

- **Laravel Reverb** - Installation, configuration, SSL, production deployment, scaling, monitoring with Pulse
- **Laravel Broadcasting** - Events, channels (public, private, presence), authorization, client-side Echo setup
- **Laravel Echo** - JavaScript client setup for vanilla JS, React, and Vue (including hooks like `useEcho`, `useEchoModel`, `useEchoPublic`, `useEchoPresence`, `useConnectionStatus`)
- **Filament Notifications** - Flash notifications, broadcast notifications, database notifications, actions on notifications
- **Filament Panel WebSockets** - Setting up Echo in Filament panels, real-time database notifications via WebSockets
- **Production deployment** - Nginx reverse proxy, Supervisor process management, ulimits, horizontal scaling with Redis

## Reference Documentation

Complete documentation is available in the `references/` directory:

| File | Content |
|------|---------|
| `laravel-reverb.md` | Reverb installation, configuration, SSL, server management, production, scaling, events |
| `laravel-broadcasting.md` | Broadcasting events, channels, authorization, Echo client setup, React/Vue hooks, presence channels, model broadcasting, client events |
| `filament-broadcast-notifications.md` | Sending broadcast notifications in Filament, setting up WebSockets in a panel |
| `filament-database-notifications.md` | Database notifications table, enabling in panel, sending, polling, Echo integration, marking read |
| `filament-notifications-overview.md` | Notification fluent API, titles, icons, statuses, duration, body, actions, URLs, Livewire events, JavaScript API |

## Common Tasks

### Setting Up Reverb from Scratch

1. `php artisan install:broadcasting` (selects Reverb)
2. Configure `.env` with `REVERB_*` variables
3. `npm install --save-dev laravel-echo pusher-js`
4. Configure Echo in `resources/js/bootstrap.js`
5. `npm run build`
6. Start the queue worker: `php artisan queue:work`
7. Start Reverb: `php artisan reverb:start`

### Adding Real-time Notifications to Filament

1. Set up Reverb (above)
2. `php artisan make:notifications-table && php artisan migrate`
3. Enable in panel: `->databaseNotifications()`
4. Publish Filament config: `php artisan vendor:publish --tag=filament-config`
5. Uncomment `broadcasting.echo` section in `config/filament.php`
6. Add `VITE_*` entries to `.env`
7. Clear caches: `php artisan route:clear && php artisan config:clear`
8. Send with `isEventDispatched: true` for real-time: `Notification::make()->title('Done')->sendToDatabase($user, isEventDispatched: true)`

### Creating a Broadcast Event

```php
<?php

namespace App\Events;

use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Queue\SerializesModels;

class OrderUpdated implements ShouldBroadcast
{
    use SerializesModels;

    public function __construct(public $order) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('orders.'.$this->order->id)];
    }
}
```

### Listening on the Client (Echo)

```js
Echo.private(`orders.${orderId}`)
    .listen('OrderUpdated', (e) => {
        console.log(e.order);
    });
```

### Production Deployment Checklist

- [ ] Nginx reverse proxy with WebSocket upgrade headers
- [ ] Supervisor config for `php artisan reverb:start`
- [ ] `ulimit -n` increased (10,000+ for high traffic)
- [ ] `REVERB_HOST` / `REVERB_PORT` set to public-facing values
- [ ] `REVERB_SERVER_HOST` / `REVERB_SERVER_PORT` set to internal values
- [ ] Queue worker running for broadcast events
- [ ] Redis configured if horizontal scaling needed (`REVERB_SCALING_ENABLED=true`)
- [ ] `ext-uv` installed via PECL for 1,000+ connections

## Key Gotchas

1. **Queue worker required** - Broadcasting uses queued jobs. No queue worker = no broadcasts.
2. **`REVERB_HOST` vs `REVERB_SERVER_HOST`** - Server vars are where Reverb binds; host vars are where Laravel sends messages (public-facing).
3. **Database transactions** - Events dispatched inside transactions may fire before commit. Use `ShouldDispatchAfterCommit`.
4. **Custom broadcast names** - If using `broadcastAs()`, prefix Echo listener with `.` to skip namespace.
5. **Filament config** - Must publish and uncomment `broadcasting.echo` in `config/filament.php`.
6. **PostgreSQL** - Database notifications migration must use `json()` not `text()` for the data column.
7. **UUIDs** - If using UUID models, migration must use `uuidMorphs('notifiable')`.
