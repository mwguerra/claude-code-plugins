# Filament Notifications Overview

> Source: https://filamentphp.com/docs/5.x/notifications/overview

## Introduction

Notifications are sent using a `Notification` object that's constructed through a fluent API. Calling the `send()` method on the `Notification` object will dispatch the notification and display it in your application. As the session is used to flash notifications, they can be sent from anywhere in your code, including JavaScript, not just Livewire components.

```php
<?php

namespace App\Livewire;

use Filament\Notifications\Notification;
use Livewire\Component;

class EditPost extends Component
{
    public function save(): void
    {
        // ...

        Notification::make()
            ->title('Saved successfully')
            ->success()
            ->send();
    }
}
```

## Setting a Title

```php
use Filament\Notifications\Notification;

Notification::make()
    ->title('Saved successfully')
    ->send();
```

The title text can contain basic, safe HTML elements. To generate safe HTML with Markdown: `title(Str::markdown('Saved **successfully**'))`

With JavaScript:

```js
new FilamentNotification()
    .title('Saved successfully')
    .send()
```

## Setting an Icon

```php
use Filament\Notifications\Notification;

Notification::make()
    ->title('Saved successfully')
    ->icon('heroicon-o-document-text')
    ->iconColor('success')
    ->send();
```

### Status Shortcuts

Instead of manually setting icons and colors, use status methods:

```php
use Filament\Notifications\Notification;

Notification::make()
    ->title('Saved successfully')
    ->success()
    ->send();
```

Available statuses: `success()`, `warning()`, `danger()`, `info()`.

## Setting a Background Color

```php
use Filament\Notifications\Notification;

Notification::make()
    ->title('Saved successfully')
    ->color('success')
    ->send();
```

## Setting a Duration

Default: 6 seconds. Customize in milliseconds:

```php
Notification::make()
    ->title('Saved successfully')
    ->success()
    ->duration(5000)
    ->send();
```

Or in seconds:

```php
Notification::make()
    ->title('Saved successfully')
    ->success()
    ->seconds(5)
    ->send();
```

Persistent (no auto-close):

```php
Notification::make()
    ->title('Saved successfully')
    ->success()
    ->persistent()
    ->send();
```

## Setting Body Text

```php
Notification::make()
    ->title('Saved successfully')
    ->success()
    ->body('Changes to the post have been saved.')
    ->send();
```

Body text can contain basic, safe HTML. Use `Str::markdown()` for Markdown.

## Adding Actions to Notifications

Actions are buttons rendered below the notification content:

```php
use Filament\Actions\Action;
use Filament\Notifications\Notification;

Notification::make()
    ->title('Saved successfully')
    ->success()
    ->body('Changes to the post have been saved.')
    ->actions([
        Action::make('view')
            ->button(),
        Action::make('undo')
            ->color('gray'),
    ])
    ->send();
```

With JavaScript:

```js
new FilamentNotification()
    .title('Saved successfully')
    .success()
    .body('Changes to the post have been saved.')
    .actions([
        new FilamentNotificationAction('view')
            .button(),
        new FilamentNotificationAction('undo')
            .color('gray'),
    ])
    .send()
```

### Opening URLs from Notification Actions

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
            ->url(route('posts.show', $post), shouldOpenInNewTab: true),
        Action::make('undo')
            ->color('gray'),
    ])
    ->send();
```

### Dispatching Livewire Events from Notification Actions

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
            ->url(route('posts.show', $post), shouldOpenInNewTab: true),
        Action::make('undo')
            ->color('gray')
            ->dispatch('undoEditingPost', [$post->id]),
    ])
    ->send();
```

Also available: `dispatchSelf()` and `dispatchTo()`.

### Closing Notifications from Actions

```php
Action::make('undo')
    ->color('gray')
    ->dispatch('undoEditingPost', [$post->id])
    ->close(),
```

## Using the JavaScript Objects

The JavaScript objects (`FilamentNotification` and `FilamentNotificationAction`) are assigned to `window.FilamentNotification` and `window.FilamentNotificationAction`.

Import in bundled JavaScript:

```js
import { Notification, NotificationAction } from '../../vendor/filament/notifications/dist/index.js'
```

## Closing a Notification with JavaScript

Dispatch a `close-notification` browser event with the notification ID:

```php
use Filament\Notifications\Notification;

$notification = Notification::make()
    ->title('Hello')
    ->persistent()
    ->send()

$notificationId = $notification->getId()
```

Close from Livewire:

```php
$this->dispatch('close-notification', id: $notificationId);
```

Close from Alpine.js:

```blade
<button x-on:click="$dispatch('close-notification', { id: notificationId })" type="button">
    Close Notification
</button>
```

Custom IDs:

```php
Notification::make('greeting')
    ->title('Hello')
    ->persistent()
    ->send()
```

## Positioning Notifications

Configure alignment in a service provider or middleware:

```php
use Filament\Notifications\Livewire\Notifications;
use Filament\Support\Enums\Alignment;
use Filament\Support\Enums\VerticalAlignment;

Notifications::alignment(Alignment::Start);
Notifications::verticalAlignment(VerticalAlignment::End);
```
