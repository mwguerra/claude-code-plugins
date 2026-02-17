# Filament Broadcast Notifications

> Source: https://filamentphp.com/docs/5.x/notifications/broadcast-notifications

## Introduction

By default, Filament will send flash notifications via the Laravel session. However, you may wish that your notifications are "broadcast" to a user in real-time, instead. This could be used to send a temporary success notification from a queued job after it has finished processing.

We have a native integration with Laravel Echo. Make sure Echo is installed, as well as a server-side websockets integration like Pusher.

## Sending Broadcast Notifications

### Using the fluent API

```php
use Filament\Notifications\Notification;

$recipient = auth()->user();

Notification::make()
    ->title('Saved successfully')
    ->broadcast($recipient);
```

### Using the notify() method

```php
use Filament\Notifications\Notification;

$recipient = auth()->user();

$recipient->notify(
    Notification::make()
        ->title('Saved successfully')
        ->toBroadcast(),
)
```

### Using a traditional Laravel notification class

Return the notification from the `toBroadcast()` method:

```php
use App\Models\User;
use Filament\Notifications\Notification;
use Illuminate\Notifications\Messages\BroadcastMessage;

public function toBroadcast(User $notifiable): BroadcastMessage
{
    return Notification::make()
        ->title('Saved successfully')
        ->getBroadcastMessage();
}
```

## Setting Up WebSockets in a Panel

The Panel Builder comes with a level of inbuilt support for real-time broadcast and database notifications. However there are a number of areas you will need to install and configure to wire everything up and get it working.

### Step-by-step setup

1. If you haven't already, read up on [broadcasting](https://laravel.com/docs/broadcasting) in the Laravel documentation.

2. Install and configure broadcasting to use a server-side websockets integration like Pusher.

3. If you haven't already, publish the Filament package configuration:

```bash
php artisan vendor:publish --tag=filament-config
```

4. Edit the configuration at `config/filament.php` and uncomment the `broadcasting.echo` section - ensuring the settings are correctly configured according to your broadcasting installation.

5. Ensure the relevant `VITE_*` entries exist in your `.env` file.

6. Clear relevant caches with `php artisan route:clear` and `php artisan config:clear` to ensure your new configuration takes effect.

Your panel should now be connecting to your broadcasting service. For example, if you log into the Pusher debug console you should see an incoming connection each time you load a page.
