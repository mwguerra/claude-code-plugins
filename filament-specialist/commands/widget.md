---
description: Create FilamentPHP v4 widgets for dashboards - stats overviews, charts, tables, or custom components
allowed-tools: Skill(filament-widgets), Skill(filament-docs), Skill(filament-tables), Bash(php:*)
argument-hint: <description> [--type stats|chart|table|custom] [--resource ResourceName]
---

# Generate FilamentPHP Widget

Create FilamentPHP v4 dashboard widgets for stats, charts, tables, or custom content.

## Usage

```bash
# Stats widget
/filament:widget "overview stats with total users, orders, and revenue"

# Chart widget
/filament:widget "monthly revenue line chart" --type chart

# Table widget
/filament:widget "latest 5 orders" --type table

# Custom widget
/filament:widget "pending tasks checklist" --type custom

# Resource widget
/filament:widget "post statistics" --resource PostResource
```

## Process

### 1. Consult Documentation

Before generating, read the widgets documentation:
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/docs/references/widgets/`

### 2. Analyze Requirements

Parse the description to identify:
- Widget type (stats, chart, table, custom)
- Data to display
- Interactivity (filters, actions)
- Refresh requirements

### 3. Determine Widget Type

| Type | Use Case | Base Class |
|------|----------|------------|
| Stats | KPI overview | StatsOverviewWidget |
| Line Chart | Trends over time | ChartWidget |
| Bar Chart | Comparisons | ChartWidget |
| Pie/Doughnut | Distribution | ChartWidget |
| Table | Recent records | TableWidget |
| Custom | Special layouts | Widget |

### 4. Generate Widget

```bash
# Generate with artisan
php artisan make:filament-widget WidgetName --stats-overview
php artisan make:filament-widget WidgetName --chart
php artisan make:filament-widget WidgetName --table
```

Customize with:
- Data fetching logic
- Styling and colors
- Filters (for charts)
- Column configuration (for tables)

## Output

Complete widget code with:
- Proper base class
- Data methods
- Styling configuration
- Sort order
- Column span settings

## Example Outputs

### Stats Overview Widget

```php
<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Models\Order;
use App\Models\User;
use App\Models\Product;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class StatsOverview extends BaseWidget
{
    protected static ?int $sort = 1;
    protected static ?string $pollingInterval = '30s';

    protected function getStats(): array
    {
        $usersThisMonth = User::whereMonth('created_at', now()->month)->count();
        $usersLastMonth = User::whereMonth('created_at', now()->subMonth()->month)->count();
        $usersTrend = $usersLastMonth > 0
            ? round(($usersThisMonth - $usersLastMonth) / $usersLastMonth * 100)
            : 100;

        $revenueThisMonth = Order::whereMonth('created_at', now()->month)->sum('total');
        $revenueLastMonth = Order::whereMonth('created_at', now()->subMonth()->month)->sum('total');
        $revenueTrend = $revenueLastMonth > 0
            ? round(($revenueThisMonth - $revenueLastMonth) / $revenueLastMonth * 100)
            : 100;

        return [
            Stat::make('Total Users', number_format(User::count()))
                ->description($usersTrend >= 0 ? "{$usersTrend}% increase" : abs($usersTrend) . '% decrease')
                ->descriptionIcon($usersTrend >= 0 ? 'heroicon-m-arrow-trending-up' : 'heroicon-m-arrow-trending-down')
                ->color($usersTrend >= 0 ? 'success' : 'danger')
                ->chart([7, 3, 4, 5, 6, 3, 5, 8]),

            Stat::make('Total Orders', number_format(Order::count()))
                ->description('All time orders')
                ->descriptionIcon('heroicon-o-shopping-cart')
                ->color('primary'),

            Stat::make('Revenue', '$' . number_format($revenueThisMonth, 2))
                ->description($revenueTrend >= 0 ? "{$revenueTrend}% increase" : abs($revenueTrend) . '% decrease')
                ->descriptionIcon($revenueTrend >= 0 ? 'heroicon-m-arrow-trending-up' : 'heroicon-m-arrow-trending-down')
                ->color($revenueTrend >= 0 ? 'success' : 'danger')
                ->chart([1200, 1400, 1100, 1800, 2200, 1900, 2400]),

            Stat::make('Active Products', Product::where('is_active', true)->count())
                ->description(Product::where('is_active', false)->count() . ' inactive')
                ->descriptionIcon('heroicon-o-cube')
                ->color('info'),
        ];
    }
}
```

### Line Chart Widget

```php
<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Models\Order;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Carbon;

class RevenueChart extends ChartWidget
{
    protected static ?string $heading = 'Monthly Revenue';
    protected static ?int $sort = 2;
    protected int | string | array $columnSpan = 'full';

    public ?string $filter = 'year';

    protected function getFilters(): ?array
    {
        return [
            'week' => 'Last 7 days',
            'month' => 'This month',
            'quarter' => 'This quarter',
            'year' => 'This year',
        ];
    }

    protected function getData(): array
    {
        $data = match ($this->filter) {
            'week' => $this->getWeeklyData(),
            'month' => $this->getMonthlyData(),
            'quarter' => $this->getQuarterlyData(),
            'year' => $this->getYearlyData(),
        };

        return [
            'datasets' => [
                [
                    'label' => 'Revenue',
                    'data' => $data['values'],
                    'borderColor' => '#10b981',
                    'backgroundColor' => 'rgba(16, 185, 129, 0.1)',
                    'fill' => true,
                    'tension' => 0.3,
                ],
            ],
            'labels' => $data['labels'],
        ];
    }

    protected function getType(): string
    {
        return 'line';
    }

    protected function getOptions(): array
    {
        return [
            'plugins' => [
                'legend' => [
                    'display' => false,
                ],
            ],
            'scales' => [
                'y' => [
                    'beginAtZero' => true,
                    'ticks' => [
                        'callback' => '(value) => "$" + value.toLocaleString()',
                    ],
                ],
            ],
        ];
    }

    private function getYearlyData(): array
    {
        $values = collect(range(1, 12))->map(fn ($month) =>
            Order::whereMonth('created_at', $month)
                ->whereYear('created_at', now()->year)
                ->sum('total')
        );

        return [
            'values' => $values->toArray(),
            'labels' => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
        ];
    }

    private function getQuarterlyData(): array
    {
        // Implementation
    }

    private function getMonthlyData(): array
    {
        // Implementation
    }

    private function getWeeklyData(): array
    {
        $values = collect(range(6, 0))->map(fn ($daysAgo) =>
            Order::whereDate('created_at', now()->subDays($daysAgo))->sum('total')
        );

        $labels = collect(range(6, 0))->map(fn ($daysAgo) =>
            now()->subDays($daysAgo)->format('D')
        );

        return [
            'values' => $values->toArray(),
            'labels' => $labels->toArray(),
        ];
    }
}
```

### Table Widget

```php
<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Models\Order;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;

class LatestOrders extends BaseWidget
{
    protected static ?string $heading = 'Latest Orders';
    protected static ?int $sort = 3;
    protected int | string | array $columnSpan = 'full';

    public function table(Table $table): Table
    {
        return $table
            ->query(
                Order::query()
                    ->with(['customer', 'items'])
                    ->latest()
            )
            ->columns([
                Tables\Columns\TextColumn::make('number')
                    ->label('Order #')
                    ->searchable()
                    ->weight(\Filament\Support\Enums\FontWeight::Bold),

                Tables\Columns\TextColumn::make('customer.name')
                    ->label('Customer')
                    ->searchable(),

                Tables\Columns\TextColumn::make('items_count')
                    ->counts('items')
                    ->label('Items'),

                Tables\Columns\TextColumn::make('total')
                    ->money('usd')
                    ->sortable(),

                Tables\Columns\BadgeColumn::make('status')
                    ->colors([
                        'warning' => 'pending',
                        'primary' => 'processing',
                        'success' => 'completed',
                        'danger' => 'cancelled',
                    ]),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Date')
                    ->dateTime('M j, Y H:i')
                    ->sortable(),
            ])
            ->actions([
                Tables\Actions\Action::make('view')
                    ->url(fn (Order $record): string =>
                        route('filament.admin.resources.orders.view', $record))
                    ->icon('heroicon-o-eye'),
            ])
            ->paginated([5, 10, 25])
            ->defaultPaginationPageOption(5);
    }
}
```

### Custom Widget

```php
<?php

declare(strict_types=1);

namespace App\Filament\Widgets;

use App\Models\Task;
use Filament\Widgets\Widget;
use Livewire\Attributes\On;

class PendingTasks extends Widget
{
    protected static string $view = 'filament.widgets.pending-tasks';
    protected static ?int $sort = 4;
    protected int | string | array $columnSpan = 1;

    public array $tasks = [];

    public function mount(): void
    {
        $this->loadTasks();
    }

    public function loadTasks(): void
    {
        $this->tasks = Task::query()
            ->where('user_id', auth()->id())
            ->whereNull('completed_at')
            ->orderBy('due_date')
            ->limit(5)
            ->get()
            ->toArray();
    }

    public function completeTask(int $taskId): void
    {
        Task::find($taskId)?->update(['completed_at' => now()]);
        $this->loadTasks();

        $this->dispatch('task-completed');
    }

    #[On('task-created')]
    public function refreshTasks(): void
    {
        $this->loadTasks();
    }
}
```

Blade view:
```blade
<x-filament-widgets::widget>
    <x-filament::section>
        <x-slot name="heading">
            Pending Tasks
        </x-slot>

        <ul class="divide-y divide-gray-200 dark:divide-gray-700">
            @forelse ($tasks as $task)
                <li class="py-3 flex items-center justify-between gap-4">
                    <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                            {{ $task['title'] }}
                        </p>
                        @if ($task['due_date'])
                            <p class="text-xs text-gray-500 dark:text-gray-400">
                                Due: {{ \Carbon\Carbon::parse($task['due_date'])->format('M j') }}
                            </p>
                        @endif
                    </div>
                    <x-filament::icon-button
                        icon="heroicon-o-check"
                        wire:click="completeTask({{ $task['id'] }})"
                        color="success"
                        size="sm"
                    />
                </li>
            @empty
                <li class="py-6 text-center text-sm text-gray-500 dark:text-gray-400">
                    No pending tasks
                </li>
            @endforelse
        </ul>
    </x-filament::section>
</x-filament-widgets::widget>
```
