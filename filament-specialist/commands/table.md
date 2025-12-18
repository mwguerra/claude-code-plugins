---
description: Create FilamentPHP v4 tables with columns, filters, search, sorting, and row/bulk actions
allowed-tools: Skill(filament-tables), Skill(filament-docs), Skill(filament-actions), Bash(php:*)
argument-hint: <description> [--resource ResourceName] [--for widget|relation-manager]
---

# Generate FilamentPHP Table Configuration

Create a FilamentPHP v4 table configuration with columns, filters, actions, and bulk operations.

## Usage

```bash
# Describe the table you need
/filament:table "posts with title, author, status badge, published date, and actions"

# For a specific resource
/filament:table "orders with customer, items count, total, status" --resource OrderResource

# For a widget
/filament:table "recent orders showing last 5" --for widget

# For a relation manager
/filament:table "comments with author, content, date" --for relation-manager
```

## Process

### 1. Consult Documentation

Before generating, read the tables documentation:
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/filament-docs/references/tables/`
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/filament-docs/references/tables/02-columns/`
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/filament-docs/references/tables/03-filters/`

### 2. Analyze Requirements

Parse the description to identify:
- Columns to display
- Which columns are searchable
- Which columns are sortable
- Filter requirements
- Row actions
- Bulk actions

### 3. Map to Column Types

| Data Type | Column Type |
|-----------|-------------|
| Text | TextColumn |
| Boolean | IconColumn::boolean() |
| Status | BadgeColumn |
| Image | ImageColumn |
| Date | TextColumn::dateTime() |
| Money | TextColumn::money() |
| Color | ColorColumn |
| Editable toggle | ToggleColumn |
| Relationship | TextColumn with dot notation |
| Count | TextColumn with ->counts() |

### 4. Generate Table Configuration

Create table with:
- Properly configured columns
- Searchable and sortable settings
- Filters
- Row actions
- Bulk actions
- Empty state

## Output

Complete table configuration code with:
- All necessary imports
- Column definitions
- Filter configurations
- Action definitions
- Performance optimizations

## Example Output

For `/filament:table "posts with title, author, status badge, published date, and actions"`:

```php
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\BadgeColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Actions\ActionGroup;
use Filament\Tables\Actions\ViewAction;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Actions\DeleteAction;
use Filament\Tables\Actions\BulkActionGroup;
use Filament\Tables\Actions\DeleteBulkAction;

public static function table(Table $table): Table
{
    return $table
        ->columns([
            ImageColumn::make('featured_image')
                ->label('Image')
                ->circular()
                ->size(40)
                ->defaultImageUrl(url('/images/placeholder.png')),

            TextColumn::make('title')
                ->label('Title')
                ->searchable()
                ->sortable()
                ->limit(50)
                ->tooltip(fn ($record) => $record->title)
                ->weight(\Filament\Support\Enums\FontWeight::Bold),

            TextColumn::make('author.name')
                ->label('Author')
                ->searchable()
                ->sortable()
                ->icon('heroicon-o-user'),

            BadgeColumn::make('status')
                ->label('Status')
                ->colors([
                    'gray' => 'draft',
                    'warning' => 'pending',
                    'success' => 'published',
                ])
                ->icons([
                    'heroicon-o-pencil' => 'draft',
                    'heroicon-o-clock' => 'pending',
                    'heroicon-o-check-circle' => 'published',
                ]),

            TextColumn::make('published_at')
                ->label('Published')
                ->dateTime('M j, Y')
                ->sortable()
                ->placeholder('Not published'),

            TextColumn::make('created_at')
                ->label('Created')
                ->dateTime()
                ->sortable()
                ->toggleable(isToggledHiddenByDefault: true),
        ])
        ->filters([
            SelectFilter::make('status')
                ->options([
                    'draft' => 'Draft',
                    'pending' => 'Pending',
                    'published' => 'Published',
                ]),

            SelectFilter::make('author')
                ->relationship('author', 'name')
                ->searchable()
                ->preload(),

            TernaryFilter::make('is_featured')
                ->label('Featured')
                ->boolean()
                ->trueLabel('Featured only')
                ->falseLabel('Not featured'),

            Tables\Filters\Filter::make('published_at')
                ->form([
                    \Filament\Forms\Components\DatePicker::make('published_from'),
                    \Filament\Forms\Components\DatePicker::make('published_until'),
                ])
                ->query(function ($query, array $data) {
                    return $query
                        ->when($data['published_from'], fn ($q, $date) =>
                            $q->whereDate('published_at', '>=', $date))
                        ->when($data['published_until'], fn ($q, $date) =>
                            $q->whereDate('published_at', '<=', $date));
                }),
        ])
        ->actions([
            ActionGroup::make([
                ViewAction::make(),
                EditAction::make(),
                DeleteAction::make()
                    ->requiresConfirmation(),
            ])->dropdown(),
        ])
        ->bulkActions([
            BulkActionGroup::make([
                DeleteBulkAction::make(),
                Tables\Actions\BulkAction::make('publish')
                    ->label('Publish Selected')
                    ->icon('heroicon-o-check-circle')
                    ->color('success')
                    ->requiresConfirmation()
                    ->action(fn ($records) => $records->each->update(['status' => 'published']))
                    ->deselectRecordsAfterCompletion(),
            ]),
        ])
        ->defaultSort('created_at', 'desc')
        ->striped()
        ->paginated([10, 25, 50, 100])
        ->emptyStateHeading('No posts yet')
        ->emptyStateDescription('Create your first post to get started.')
        ->emptyStateIcon('heroicon-o-document-text')
        ->emptyStateActions([
            Tables\Actions\CreateAction::make()
                ->label('Create Post'),
        ]);
}
```

## Column Examples

### Text Columns
```php
TextColumn::make('name')
    ->searchable()
    ->sortable();

TextColumn::make('email')
    ->copyable()
    ->copyMessage('Copied!');

TextColumn::make('price')
    ->money('usd')
    ->sortable();

TextColumn::make('created_at')
    ->dateTime('M j, Y H:i')
    ->since();  // Shows "2 hours ago"
```

### Badge Columns
```php
BadgeColumn::make('status')
    ->colors([
        'danger' => 'failed',
        'warning' => 'pending',
        'success' => 'completed',
    ]);
```

### Relationship Columns
```php
TextColumn::make('author.name')
    ->label('Author');

TextColumn::make('comments_count')
    ->counts('comments')
    ->label('Comments');

TextColumn::make('tags.name')
    ->badge()
    ->separator(',');
```

### Editable Columns
```php
ToggleColumn::make('is_active');

SelectColumn::make('status')
    ->options([...]);

TextInputColumn::make('sort_order')
    ->rules(['required', 'numeric']);
```
