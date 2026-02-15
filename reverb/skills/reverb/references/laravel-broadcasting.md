# Laravel Broadcasting

> Source: https://laravel.com/docs/12.x/broadcasting

## Introduction

In many modern web applications, WebSockets are used to implement realtime, live-updating user interfaces. When some data is updated on the server, a message is typically sent over a WebSocket connection to be handled by the client. WebSockets provide a more efficient alternative to continually polling your application's server for data changes that should be reflected in your UI.

The core concepts behind broadcasting are simple: clients connect to named channels on the frontend, while your Laravel application broadcasts events to these channels on the backend. These events can contain any additional data you wish to make available to the frontend.

### Supported Drivers

By default, Laravel includes three server-side broadcasting drivers: Laravel Reverb, Pusher Channels, and Ably.

## Quickstart

By default, broadcasting is not enabled in new Laravel applications. You may enable broadcasting using the `install:broadcasting` Artisan command:

```shell
php artisan install:broadcasting
```

The `install:broadcasting` command will prompt you for which event broadcasting service you would like to use. All of your application's event broadcasting configuration is stored in the `config/broadcasting.php` configuration file.

> **Important:** Before broadcasting any events, you should first configure and run a queue worker. All event broadcasting is done via queued jobs so that the response time of your application is not seriously affected by events being broadcast.

## Server Side Installation

### Reverb

To quickly enable support for Laravel's broadcasting features while using Reverb as your event broadcaster:

```shell
php artisan install:broadcasting --reverb
```

#### Manual Installation

```shell
composer require laravel/reverb
php artisan reverb:install
```

### Pusher Channels

```shell
php artisan install:broadcasting --pusher
```

#### Manual Installation

```shell
composer require pusher/pusher-php-server
```

Configure credentials in `.env`:

```ini
PUSHER_APP_ID="your-pusher-app-id"
PUSHER_APP_KEY="your-pusher-key"
PUSHER_APP_SECRET="your-pusher-secret"
PUSHER_HOST=
PUSHER_PORT=443
PUSHER_SCHEME="https"
PUSHER_APP_CLUSTER="mt1"
```

Set the broadcast connection:

```ini
BROADCAST_CONNECTION=pusher
```

### Ably

```shell
php artisan install:broadcasting --ably
```

**Important:** Enable Pusher protocol support in your Ably application settings (Protocol Adapter Settings).

## Client Side Installation

### Reverb

When installing Laravel Reverb via the `install:broadcasting` Artisan command, Reverb and Echo's scaffolding and configuration will be injected into your application automatically.

#### Manual Installation

```shell
npm install --save-dev laravel-echo pusher-js
```

Create an Echo instance in `resources/js/bootstrap.js`:

```js
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';
window.Pusher = Pusher;

window.Echo = new Echo({
    broadcaster: 'reverb',
    key: import.meta.env.VITE_REVERB_APP_KEY,
    wsHost: import.meta.env.VITE_REVERB_HOST,
    wsPort: import.meta.env.VITE_REVERB_PORT ?? 80,
    wssPort: import.meta.env.VITE_REVERB_PORT ?? 443,
    forceTLS: (import.meta.env.VITE_REVERB_SCHEME ?? 'https') === 'https',
    enabledTransports: ['ws', 'wss'],
});
```

For React:

```js
import { configureEcho } from "@laravel/echo-react";

configureEcho({
    broadcaster: "reverb",
});
```

For Vue:

```js
import { configureEcho } from "@laravel/echo-vue";

configureEcho({
    broadcaster: "reverb",
});
```

> **Warning:** The Laravel Echo `reverb` broadcaster requires laravel-echo v1.16.0+.

## Defining Broadcast Events

To inform Laravel that a given event should be broadcast, implement the `Illuminate\Contracts\Broadcasting\ShouldBroadcast` interface on the event class:

```php
<?php

namespace App\Events;

use App\Models\User;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Queue\SerializesModels;

class ServerCreated implements ShouldBroadcast
{
    use SerializesModels;

    public function __construct(
        public User $user,
    ) {}

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.'.$this->user->id),
        ];
    }
}
```

### Broadcast Name

Customize the broadcast name by defining a `broadcastAs` method:

```php
public function broadcastAs(): string
{
    return 'server.created';
}
```

If you customize the broadcast name using `broadcastAs`, register your listener with a leading `.` character to not prepend the application's namespace:

```javascript
.listen('.server.created', function (e) {
    // ...
});
```

### Broadcast Data

All `public` properties are automatically serialized. For fine-grained control:

```php
public function broadcastWith(): array
{
    return ['id' => $this->user->id];
}
```

### Broadcast Queue

Customize the queue connection and name:

```php
public $connection = 'redis';
public $queue = 'default';
```

Or define a `broadcastQueue` method:

```php
public function broadcastQueue(): string
{
    return 'default';
}
```

To broadcast synchronously, implement `ShouldBroadcastNow` instead of `ShouldBroadcast`:

```php
class OrderShipmentStatusUpdated implements ShouldBroadcastNow
{
    // ...
}
```

### Broadcast Conditions

```php
public function broadcastWhen(): bool
{
    return $this->order->value > 100;
}
```

### Broadcasting and Database Transactions

When broadcast events are dispatched within database transactions, they may be processed by the queue before the database transaction has committed. Implement `ShouldDispatchAfterCommit`:

```php
class ServerCreated implements ShouldBroadcast, ShouldDispatchAfterCommit
{
    use SerializesModels;
}
```

## Authorizing Channels

Private channels require authorization. Define authorization rules in `routes/channels.php`:

```php
use App\Models\Order;
use App\Models\User;

Broadcast::channel('orders.{orderId}', function (User $user, int $orderId) {
    return $user->id === Order::findOrNew($orderId)->user_id;
});
```

#### Authorization Callback Model Binding

```php
use App\Models\Order;
use App\Models\User;

Broadcast::channel('orders.{order}', function (User $user, Order $order) {
    return $user->id === $order->user_id;
});
```

### Defining Channel Classes

```shell
php artisan make:channel OrderChannel
```

Register in `routes/channels.php`:

```php
use App\Broadcasting\OrderChannel;

Broadcast::channel('orders.{order}', OrderChannel::class);
```

The channel class:

```php
<?php

namespace App\Broadcasting;

use App\Models\Order;
use App\Models\User;

class OrderChannel
{
    public function __construct() {}

    public function join(User $user, Order $order): array|bool
    {
        return $user->id === $order->user_id;
    }
}
```

## Broadcasting Events

Fire the event using the dispatch method:

```php
use App\Events\OrderShipmentStatusUpdated;

OrderShipmentStatusUpdated::dispatch($order);
```

### Only to Others

```php
broadcast(new OrderShipmentStatusUpdated($update))->toOthers();
```

Your event must use the `Illuminate\Broadcasting\InteractsWithSockets` trait to call `toOthers`.

### Customizing the Connection

```php
broadcast(new OrderShipmentStatusUpdated($update))->via('pusher');
```

### Anonymous Events

```php
Broadcast::on('orders.'.$order->id)->send();

Broadcast::on('orders.'.$order->id)
    ->as('OrderPlaced')
    ->with($order)
    ->send();

// Private or presence channels
Broadcast::private('orders.'.$order->id)->send();
Broadcast::presence('channels.'.$channel->id)->send();

// Immediate (non-queued)
Broadcast::on('orders.'.$order->id)->sendNow();

// Exclude current user
Broadcast::on('orders.'.$order->id)
    ->toOthers()
    ->send();
```

### Rescuing Broadcasts

Implement `ShouldRescue` to prevent broadcast exceptions from disrupting the user experience:

```php
class ServerCreated implements ShouldBroadcast, ShouldRescue
{
    // ...
}
```

## Receiving Broadcasts

### Listening for Events

```js
Echo.channel(`orders.${this.order.id}`)
    .listen('OrderShipmentStatusUpdated', (e) => {
        console.log(e.order.name);
    });
```

Private channel:

```js
Echo.private(`orders.${this.order.id}`)
    .listen(/* ... */)
    .listen(/* ... */)
    .listen(/* ... */);
```

#### Stop Listening

```js
Echo.private(`orders.${this.order.id}`)
    .stopListening('OrderShipmentStatusUpdated');
```

### Leaving a Channel

```js
Echo.leaveChannel(`orders.${this.order.id}`);
Echo.leave(`orders.${this.order.id}`);
```

### Namespaces

Configure root namespace:

```js
window.Echo = new Echo({
    broadcaster: 'pusher',
    namespace: 'App.Other.Namespace'
});
```

Or prefix event classes with `.` for fully-qualified names:

```js
Echo.channel('orders')
    .listen('.Namespace\\Event\\Class', (e) => {
        // ...
    });
```

### Using React or Vue

```js
// React
import { useEcho } from "@laravel/echo-react";

useEcho(`orders.${orderId}`, "OrderShipmentStatusUpdated", (e) => {
    console.log(e.order);
});
```

```vue
// Vue
<script setup lang="ts">
import { useEcho } from "@laravel/echo-vue";

useEcho(`orders.${orderId}`, "OrderShipmentStatusUpdated", (e) => {
    console.log(e.order);
});
</script>
```

Listen to multiple events:

```js
useEcho(`orders.${orderId}`, ["OrderShipmentStatusUpdated", "OrderShipped"], (e) => {
    console.log(e.order);
});
```

With TypeScript types:

```ts
type OrderData = {
    order: { id: number; user: { id: number; name: string }; created_at: string };
};

useEcho<OrderData>(`orders.${orderId}`, "OrderShipmentStatusUpdated", (e) => {
    console.log(e.order.id);
});
```

Control listening programmatically:

```js
const { leaveChannel, leave, stopListening, listen } = useEcho(
    `orders.${orderId}`, "OrderShipmentStatusUpdated", (e) => { console.log(e.order); }
);

stopListening();  // Stop listening without leaving channel
listen();         // Start listening again
leaveChannel();   // Leave channel
leave();          // Leave channel and associated private/presence channels
```

#### Public Channels

```js
import { useEchoPublic } from "@laravel/echo-react";

useEchoPublic("posts", "PostPublished", (e) => {
    console.log(e.post);
});
```

#### Presence Channels

```js
import { useEchoPresence } from "@laravel/echo-react";

useEchoPresence("posts", "PostPublished", (e) => {
    console.log(e.post);
});
```

#### Connection Status

```js
import { useConnectionStatus } from "@laravel/echo-react";

function ConnectionIndicator() {
    const status = useConnectionStatus();
    return <div>Connection: {status}</div>;
}
```

Status values: `connected`, `connecting`, `reconnecting`, `disconnected`, `failed`.

## Presence Channels

Presence channels build on private channels with awareness of who is subscribed.

### Authorizing Presence Channels

Return an array of user data (not `true`):

```php
use App\Models\User;

Broadcast::channel('chat.{roomId}', function (User $user, int $roomId) {
    if ($user->canJoinRoom($roomId)) {
        return ['id' => $user->id, 'name' => $user->name];
    }
});
```

### Joining Presence Channels

```js
Echo.join(`chat.${roomId}`)
    .here((users) => { /* ... */ })
    .joining((user) => { console.log(user.name); })
    .leaving((user) => { console.log(user.name); })
    .error((error) => { console.error(error); });
```

### Broadcasting to Presence Channels

```php
public function broadcastOn(): array
{
    return [
        new PresenceChannel('chat.'.$this->message->room_id),
    ];
}
```

## Model Broadcasting

Use the `BroadcastsEvents` trait on Eloquent models:

```php
<?php

namespace App\Models;

use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Database\Eloquent\BroadcastsEvents;
use Illuminate\Database\Eloquent\Model;

class Post extends Model
{
    use BroadcastsEvents;

    public function broadcastOn(string $event): array
    {
        return [$this, $this->user];
    }
}
```

Events dispatched automatically for: `created`, `updated`, `deleted`, `trashed`, `restored`.

### Channel Conventions

An `App\Models\User` model with `id` of `1` creates a `PrivateChannel` named `App.Models.User.1`.

### Event Conventions

An update to `App\Models\Post` broadcasts as `PostUpdated` with the model as payload.

Customize with `broadcastAs` and `broadcastWith`:

```php
public function broadcastAs(string $event): string|null
{
    return match ($event) {
        'created' => 'post.created',
        default => null,
    };
}
```

### Listening for Model Broadcasts

```js
Echo.private(`App.Models.User.${this.user.id}`)
    .listen('.UserUpdated', (e) => {
        console.log(e.model);
    });
```

#### Using React or Vue

```js
import { useEchoModel } from "@laravel/echo-react";

useEchoModel("App.Models.User", userId, ["UserUpdated"], (e) => {
    console.log(e.model);
});
```

## Client Events

Broadcast events to other clients without hitting the server (e.g., typing indicators):

```js
Echo.private(`chat.${roomId}`)
    .whisper('typing', { name: this.user.name });
```

Listen for client events:

```js
Echo.private(`chat.${roomId}`)
    .listenForWhisper('typing', (e) => {
        console.log(e.name);
    });
```

## Notifications

Pair broadcasting with Laravel notifications:

```js
Echo.private(`App.Models.User.${userId}`)
    .notification((notification) => {
        console.log(notification.type);
    });
```

Stop listening:

```js
Echo.private(`App.Models.User.${userId}`)
    .stopListeningForNotification(callback);
```
