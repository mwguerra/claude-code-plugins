---
description: Create FilamentPHP v4 infolists with entries, layouts, and sections for read-only view pages
allowed-tools: Skill(infolists), Skill(docs), Bash(php:*)
argument-hint: <description> [--resource ResourceName]
---

# Generate FilamentPHP Infolist

Create FilamentPHP v4 infolists for displaying read-only data in view pages and modals.

## Usage

```bash
# Describe the infolist you need
/filament:infolist "post details with title, content, author, status, and dates"

# For a specific resource
/filament:infolist "order details with customer, items, total, status" --resource OrderResource
```

## Process

### 1. Consult Documentation

Before generating, read the infolists documentation:
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/docs/references/infolists/`

### 2. Analyze Requirements

Parse the description to identify:
- Data to display
- Entry types needed
- Layout preferences (sections, tabs, split)
- Relationships to show

### 3. Map to Entry Types

| Data Type | Entry Type |
|-----------|------------|
| Text | TextEntry |
| HTML | TextEntry::html() |
| Date | TextEntry::dateTime() |
| Boolean | IconEntry::boolean() |
| Image | ImageEntry |
| Color | ColorEntry |
| Key-value | KeyValueEntry |
| List | RepeatableEntry |

### 4. Generate Infolist

Create with:
- Proper entry configurations
- Layout structure
- Relationship handling
- Styling

## Output

Complete infolist code with:
- All necessary imports
- Entry configurations
- Layout components
- Styling and formatting

## Example Output

For `/filament:infolist "post details with title, content, author, status, and dates"`:

```php
<?php

declare(strict_types=1);

namespace App\Filament\Resources\PostResource\Pages;

use App\Filament\Resources\PostResource;
use Filament\Actions;
use Filament\Infolists;
use Filament\Infolists\Infolist;
use Filament\Resources\Pages\ViewRecord;
use Filament\Support\Enums\FontWeight;

class ViewPost extends ViewRecord
{
    protected static string $resource = PostResource::class;

    public function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Infolists\Components\Split::make([
                    // Main content
                    Infolists\Components\Group::make([
                        Infolists\Components\Section::make('Post Details')
                            ->schema([
                                Infolists\Components\TextEntry::make('title')
                                    ->size(Infolists\Components\TextEntry\TextEntrySize::Large)
                                    ->weight(FontWeight::Bold)
                                    ->columnSpanFull(),

                                Infolists\Components\TextEntry::make('slug')
                                    ->icon('heroicon-o-link')
                                    ->iconColor('gray')
                                    ->copyable()
                                    ->copyMessage('Slug copied!'),

                                Infolists\Components\TextEntry::make('excerpt')
                                    ->placeholder('No excerpt')
                                    ->columnSpanFull(),
                            ])
                            ->columns(2),

                        Infolists\Components\Section::make('Content')
                            ->schema([
                                Infolists\Components\TextEntry::make('content')
                                    ->html()
                                    ->prose()
                                    ->hiddenLabel()
                                    ->columnSpanFull(),
                            ])
                            ->collapsible(),

                        Infolists\Components\Section::make('Comments')
                            ->schema([
                                Infolists\Components\RepeatableEntry::make('comments')
                                    ->schema([
                                        Infolists\Components\ImageEntry::make('author.avatar')
                                            ->circular()
                                            ->size(40)
                                            ->hiddenLabel(),

                                        Infolists\Components\Group::make([
                                            Infolists\Components\TextEntry::make('author.name')
                                                ->weight(FontWeight::SemiBold)
                                                ->hiddenLabel(),
                                            Infolists\Components\TextEntry::make('created_at')
                                                ->since()
                                                ->color('gray')
                                                ->hiddenLabel(),
                                        ]),

                                        Infolists\Components\TextEntry::make('content')
                                            ->hiddenLabel()
                                            ->columnSpanFull(),
                                    ])
                                    ->columns(3)
                                    ->contained(false),
                            ])
                            ->collapsible()
                            ->collapsed(fn ($record) => $record->comments->count() === 0),
                    ]),

                    // Sidebar
                    Infolists\Components\Group::make([
                        Infolists\Components\Section::make('Status')
                            ->schema([
                                Infolists\Components\TextEntry::make('status')
                                    ->badge()
                                    ->color(fn (string $state): string => match ($state) {
                                        'draft' => 'gray',
                                        'pending' => 'warning',
                                        'published' => 'success',
                                        default => 'gray',
                                    }),

                                Infolists\Components\IconEntry::make('is_featured')
                                    ->label('Featured')
                                    ->boolean(),
                            ]),

                        Infolists\Components\Section::make('Author')
                            ->schema([
                                Infolists\Components\ImageEntry::make('author.avatar')
                                    ->circular()
                                    ->size(60)
                                    ->hiddenLabel(),

                                Infolists\Components\TextEntry::make('author.name')
                                    ->label('Name')
                                    ->icon('heroicon-o-user'),

                                Infolists\Components\TextEntry::make('author.email')
                                    ->label('Email')
                                    ->icon('heroicon-o-envelope')
                                    ->copyable(),
                            ]),

                        Infolists\Components\Section::make('Category & Tags')
                            ->schema([
                                Infolists\Components\TextEntry::make('category.name')
                                    ->label('Category')
                                    ->icon('heroicon-o-folder')
                                    ->placeholder('Uncategorized'),

                                Infolists\Components\TextEntry::make('tags.name')
                                    ->label('Tags')
                                    ->badge()
                                    ->color('info')
                                    ->separator(',')
                                    ->placeholder('No tags'),
                            ]),

                        Infolists\Components\Section::make('Featured Image')
                            ->schema([
                                Infolists\Components\ImageEntry::make('featured_image')
                                    ->hiddenLabel()
                                    ->height(200)
                                    ->extraImgAttributes([
                                        'class' => 'rounded-lg',
                                    ]),
                            ])
                            ->visible(fn ($record) => $record->featured_image),

                        Infolists\Components\Section::make('Dates')
                            ->schema([
                                Infolists\Components\TextEntry::make('published_at')
                                    ->label('Published')
                                    ->dateTime('F j, Y \a\t g:i A')
                                    ->icon('heroicon-o-calendar')
                                    ->placeholder('Not published'),

                                Infolists\Components\TextEntry::make('created_at')
                                    ->label('Created')
                                    ->dateTime('F j, Y')
                                    ->icon('heroicon-o-clock'),

                                Infolists\Components\TextEntry::make('updated_at')
                                    ->label('Last Updated')
                                    ->since()
                                    ->icon('heroicon-o-arrow-path'),
                            ]),

                        Infolists\Components\Section::make('Statistics')
                            ->schema([
                                Infolists\Components\TextEntry::make('views_count')
                                    ->label('Views')
                                    ->icon('heroicon-o-eye')
                                    ->numeric(),

                                Infolists\Components\TextEntry::make('comments_count')
                                    ->label('Comments')
                                    ->icon('heroicon-o-chat-bubble-left')
                                    ->numeric()
                                    ->state(fn ($record) => $record->comments->count()),
                            ]),
                    ])
                    ->grow(false),
                ])
                ->from('md')
                ->columnSpanFull(),
            ]);
    }

    protected function getHeaderActions(): array
    {
        return [
            Actions\EditAction::make(),
            Actions\DeleteAction::make(),

            Actions\Action::make('preview')
                ->label('View on Site')
                ->icon('heroicon-o-arrow-top-right-on-square')
                ->url(fn () => route('posts.show', $this->record))
                ->openUrlInNewTab(),
        ];
    }
}
```

## Entry Examples

### Text Entries
```php
TextEntry::make('title')
    ->size(TextEntrySize::Large)
    ->weight(FontWeight::Bold);

TextEntry::make('content')
    ->html()
    ->prose();

TextEntry::make('price')
    ->money('usd');

TextEntry::make('created_at')
    ->dateTime('F j, Y')
    ->since();
```

### Icon Entries
```php
IconEntry::make('is_active')
    ->boolean();

IconEntry::make('status')
    ->icon(fn ($state) => match ($state) {
        'draft' => 'heroicon-o-pencil',
        'published' => 'heroicon-o-check-circle',
    });
```

### Image Entries
```php
ImageEntry::make('avatar')
    ->circular()
    ->size(80);

ImageEntry::make('gallery')
    ->stacked()
    ->limit(3);
```

### Repeatable Entries
```php
RepeatableEntry::make('items')
    ->schema([
        TextEntry::make('name'),
        TextEntry::make('quantity'),
        TextEntry::make('price')->money('usd'),
    ])
    ->columns(3);
```

### Layout Components
```php
Section::make('Details')
    ->description('Additional information')
    ->icon('heroicon-o-information-circle')
    ->collapsible()
    ->schema([...]);

Tabs::make('Tabs')
    ->tabs([
        Tab::make('Overview')->schema([...]),
        Tab::make('Details')->schema([...]),
    ]);

Split::make([
    Group::make([...])->grow(),
    Group::make([...])->grow(false),
])->from('md');
```
