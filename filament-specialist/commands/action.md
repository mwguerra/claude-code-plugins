---
description: Create FilamentPHP v4 actions with modals, confirmation dialogs, forms, and bulk operations
allowed-tools: Skill(actions), Skill(docs), Skill(forms), Bash(php:*)
argument-hint: <description> [--type row|bulk|header|page] [--modal] [--confirmation]
---

# Generate FilamentPHP Action

Create FilamentPHP v4 actions for tables, pages, or modals with forms and confirmations.

## Usage

```bash
# Simple action
/filament:action "publish post"

# Action with modal form
/filament:action "send email to user with subject and message" --modal

# Bulk action
/filament:action "export selected records to CSV" --type bulk

# Page header action
/filament:action "import data from CSV file" --type header --modal

# Action with confirmation
/filament:action "archive old records" --confirmation
```

## Process

### 1. Consult Documentation

Before generating, read the actions documentation:
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/docs/references/actions/`

### 2. Analyze Requirements

Parse the description to identify:
- Action purpose
- Required inputs (modal form)
- Confirmation needed
- Target (single record, multiple records, page-level)
- Result (notification, redirect, download)

### 3. Determine Action Type

| Type | Use Case |
|------|----------|
| Row Action | Act on single table record |
| Bulk Action | Act on multiple selected records |
| Header Action | Table-level action (create, import) |
| Page Action | Page header action |
| Modal Action | Standalone action with form |

### 4. Generate Action

Create action with:
- Proper icon and color
- Form schema if needed
- Confirmation dialog if needed
- Action logic
- Notification/feedback

## Output

Complete action code with:
- All necessary imports
- Icon and styling
- Form schema (if modal)
- Confirmation (if needed)
- Action handler
- Notifications

## Example Outputs

### Simple Row Action

```php
use Filament\Tables\Actions\Action;
use Filament\Notifications\Notification;

Action::make('publish')
    ->label('Publish')
    ->icon('heroicon-o-check-circle')
    ->color('success')
    ->requiresConfirmation()
    ->modalHeading('Publish Post')
    ->modalDescription('Are you sure you want to publish this post? It will be visible to the public.')
    ->modalSubmitActionLabel('Yes, publish')
    ->action(function (Post $record): void {
        $record->update([
            'status' => 'published',
            'published_at' => now(),
        ]);

        Notification::make()
            ->title('Post published successfully')
            ->success()
            ->send();
    })
    ->visible(fn (Post $record): bool => $record->status !== 'published')
```

### Action with Modal Form

```php
use Filament\Tables\Actions\Action;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\RichEditor;
use Filament\Forms\Components\Select;
use Filament\Notifications\Notification;
use Illuminate\Support\Facades\Mail;

Action::make('send_email')
    ->label('Send Email')
    ->icon('heroicon-o-envelope')
    ->color('info')
    ->form([
        Select::make('template')
            ->label('Email Template')
            ->options([
                'welcome' => 'Welcome Email',
                'reminder' => 'Reminder',
                'promotion' => 'Promotion',
            ])
            ->required()
            ->live(),

        TextInput::make('subject')
            ->label('Subject')
            ->required()
            ->maxLength(255)
            ->default(fn (Get $get) => match ($get('template')) {
                'welcome' => 'Welcome to our platform!',
                'reminder' => 'Don\'t forget!',
                'promotion' => 'Special offer for you',
                default => '',
            }),

        RichEditor::make('body')
            ->label('Message')
            ->required()
            ->columnSpanFull(),
    ])
    ->action(function (User $record, array $data): void {
        Mail::to($record->email)->send(new CustomEmail(
            subject: $data['subject'],
            template: $data['template'],
            body: $data['body'],
        ));

        Notification::make()
            ->title('Email sent successfully')
            ->body("Email sent to {$record->email}")
            ->success()
            ->send();
    })
```

### Bulk Action

```php
use Filament\Tables\Actions\BulkAction;
use Illuminate\Database\Eloquent\Collection;
use Filament\Notifications\Notification;

BulkAction::make('publish_all')
    ->label('Publish Selected')
    ->icon('heroicon-o-check-circle')
    ->color('success')
    ->requiresConfirmation()
    ->modalHeading('Publish Selected Posts')
    ->modalDescription('Are you sure you want to publish all selected posts?')
    ->action(function (Collection $records): void {
        $count = $records->count();

        $records->each(function (Post $post) {
            $post->update([
                'status' => 'published',
                'published_at' => now(),
            ]);
        });

        Notification::make()
            ->title("{$count} posts published")
            ->success()
            ->send();
    })
    ->deselectRecordsAfterCompletion()
```

### Header Action with File Upload

```php
use Filament\Tables\Actions\Action;
use Filament\Forms\Components\FileUpload;
use Filament\Notifications\Notification;

Action::make('import')
    ->label('Import')
    ->icon('heroicon-o-arrow-up-tray')
    ->form([
        FileUpload::make('file')
            ->label('CSV File')
            ->acceptedFileTypes(['text/csv', 'application/vnd.ms-excel'])
            ->required()
            ->disk('local')
            ->directory('imports'),
    ])
    ->action(function (array $data): void {
        $path = storage_path('app/' . $data['file']);

        // Process CSV file
        $rows = array_map('str_getcsv', file($path));
        $headers = array_shift($rows);

        foreach ($rows as $row) {
            $record = array_combine($headers, $row);
            Post::create($record);
        }

        Notification::make()
            ->title('Import completed')
            ->body(count($rows) . ' records imported')
            ->success()
            ->send();
    })
```

### Page Header Action

```php
// In resource page class
protected function getHeaderActions(): array
{
    return [
        Actions\CreateAction::make(),

        Actions\Action::make('export')
            ->label('Export All')
            ->icon('heroicon-o-arrow-down-tray')
            ->color('gray')
            ->action(function () {
                return response()->streamDownload(function () {
                    echo Post::all()->toCsv();
                }, 'posts.csv');
            }),

        Actions\Action::make('settings')
            ->label('Settings')
            ->icon('heroicon-o-cog')
            ->url(route('filament.admin.pages.settings'))
            ->openUrlInNewTab(),
    ];
}
```

### Wizard Action (Multi-step)

```php
use Filament\Actions\Action;
use Filament\Forms\Components\Wizard\Step;

Action::make('create_order')
    ->label('Create Order')
    ->icon('heroicon-o-shopping-cart')
    ->steps([
        Step::make('Customer')
            ->description('Select customer')
            ->schema([
                Select::make('customer_id')
                    ->relationship('customer', 'name')
                    ->searchable()
                    ->required(),
            ]),
        Step::make('Products')
            ->description('Add products')
            ->schema([
                Repeater::make('items')
                    ->schema([
                        Select::make('product_id')
                            ->relationship('product', 'name')
                            ->required(),
                        TextInput::make('quantity')
                            ->numeric()
                            ->default(1)
                            ->required(),
                    ])
                    ->columns(2),
            ]),
        Step::make('Review')
            ->description('Review order')
            ->schema([
                Placeholder::make('summary')
                    ->content(fn (Get $get) => 'Order summary...'),
            ]),
    ])
    ->action(function (array $data) {
        Order::create($data);
    })
```
