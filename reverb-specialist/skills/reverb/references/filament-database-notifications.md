# Filament Database Notifications

> Source: https://filamentphp.com/docs/5.x/notifications/database-notifications

## Setting Up the Notifications Database Table

Before we start, make sure that the Laravel notifications table is added to your database:

```bash
php artisan make:notifications-table
```

> If you're using PostgreSQL, make sure that the `data` column in the migration is using `json()`: `$table->json('data')`.

> If you're using UUIDs for your `User` model, make sure that your `notifiable` column is using `uuidMorphs()`: `$table->uuidMorphs('notifiable')`.

## Enabling Database Notifications in a Panel

If you'd like to receive database notifications in a panel, you can enable them in the configuration:

```php
use Filament\Panel;

public function panel(Panel $panel): Panel
{
    return $panel
        // ...
        ->databaseNotifications();
}
```

## Sending Database Notifications

### Using the fluent API

```php
use Filament\Notifications\Notification;

$recipient = auth()->user();

Notification::make()
    ->title('Saved successfully')
    ->sendToDatabase($recipient);
```

### Using the notify() method

```php
use Filament\Notifications\Notification;

$recipient = auth()->user();

$recipient->notify(
    Notification::make()
        ->title('Saved successfully')
        ->toDatabase(),
);
```

> Laravel sends database notifications using the queue. Ensure your queue is running in order to receive the notifications.

### Using a traditional Laravel notification class

```php
use App\Models\User;
use Filament\Notifications\Notification;

public function toDatabase(User $notifiable): array
{
    return Notification::make()
        ->title('Saved successfully')
        ->getDatabaseMessage();
}
```

## Moving the Database Notifications Trigger to the Panel Sidebar

By default, the database notifications trigger is positioned in the topbar. You can move it to the sidebar:

```php
use Filament\Enums\DatabaseNotificationsPosition;
use Filament\Panel;

public function panel(Panel $panel): Panel
{
    return $panel
        // ...
        ->databaseNotifications(position: DatabaseNotificationsPosition::Sidebar);
}
```

## Receiving Database Notifications

Without any setup, new database notifications will only be received when the page is first loaded.

### Polling for New Database Notifications

Polling periodically makes a request to the server to check for new notifications. By default, Livewire polls every 30 seconds:

```php
use Filament\Panel;

public function panel(Panel $panel): Panel
{
    return $panel
        // ...
        ->databaseNotifications()
        ->databaseNotificationsPolling('30s');
}
```

Disable polling:

```php
use Filament\Panel;

public function panel(Panel $panel): Panel
{
    return $panel
        // ...
        ->databaseNotifications()
        ->databaseNotificationsPolling(null);
}
```

### Using Echo to Receive New Database Notifications with WebSockets

WebSockets are a more efficient way to receive new notifications in real-time. To set up websockets, you must configure it in the panel first (see broadcast notifications - setting up websockets in a panel).

Once websockets are set up, you can automatically dispatch a `DatabaseNotificationsSent` event by setting the `isEventDispatched` parameter to `true` when sending the notification. This will trigger the immediate fetching of new notifications for the user:

```php
use Filament\Notifications\Notification;

$recipient = auth()->user();

Notification::make()
    ->title('Saved successfully')
    ->sendToDatabase($recipient, isEventDispatched: true);
```

## Marking Database Notifications as Read

There is a button at the top of the modal to mark all notifications as read at once. You may also add Actions to notifications to mark individual notifications as read:

```php
use Filament\Actions\Action;
use Filament\Notifications\Notification;

Notification::make()
    ->title('Saved successfully')
    ->success()
    ->body('Changes to the post have been saved.')
    ->actions([
        Action::make('view')
            ->button()
            ->markAsRead(),
    ])
    ->send();
```

Mark as unread:

```php
use Filament\Actions\Action;
use Filament\Notifications\Notification;

Notification::make()
    ->title('Saved successfully')
    ->success()
    ->body('Changes to the post have been saved.')
    ->actions([
        Action::make('markAsUnread')
            ->button()
            ->markAsUnread(),
    ])
    ->send();
```

## Opening the Database Notifications Modal

You can open the database notifications modal from anywhere by dispatching an `open-modal` browser event:

```blade
<button
    x-data="{}"
    x-on:click="$dispatch('open-modal', { id: 'database-notifications' })"
    type="button"
>
    Notifications
</button>
```
