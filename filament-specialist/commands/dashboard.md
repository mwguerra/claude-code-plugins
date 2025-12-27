---
description: Create FilamentPHP v4 dashboard pages with single-tab or multi-tab layouts, message callouts, and widgets
allowed-tools: Skill(filament-dashboard), Skill(filament-widgets), Skill(filament-docs), Bash(php:*)
argument-hint: <page-name> [--panel Admin] [--tabs overview,users,revenue] [--single]
---

# Generate FilamentPHP Dashboard Page

Create FilamentPHP v4 dashboard pages with tabbed navigation, color-coded messages, and widget integration.

## Usage

```bash
# Multi-tab dashboard
/filament:dashboard "Analytics" --tabs overview,users,revenue

# Single-tab dashboard (no tabs UI)
/filament:dashboard "BillingOverview" --single

# Dashboard in specific panel
/filament:dashboard "SupportDashboard" --panel Support --tabs tickets,agents,metrics

# With detailed tab configuration
/filament:dashboard "ReportingDashboard" --tabs "overview:Overview:heroicon-o-home,sales:Sales:heroicon-o-currency-dollar"
```

## Process

### 1. Consult Documentation

Before generating, read the dashboard and widgets documentation:
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/filament-docs/references/general/06-navigation/`
- Read `/home/mwguerra/projects/mwguerra/claude-code-plugins/filament-specialist/skills/filament-docs/references/widgets/`

### 2. Analyze Requirements

Parse the request to identify:
- Page class name (PascalCase)
- Panel (Admin, Support, etc.)
- Single-tab vs multi-tab mode
- Tab definitions (key, title, icon)
- Widget requirements per tab
- Navigation configuration

### 3. Determine Page Mode

| Mode | Use Case | Tabs UI |
|------|----------|---------|
| Multi-tab | Multiple data views | Visible tab navigation |
| Single-tab | Single focused view | No tabs navigation |

### 4. Generate Files

**For multi-tab:**
1. PHP Page class with `getTabs()` returning multiple tabs
2. Blade view with tabs navigation bar

**For single-tab:**
1. PHP Page class with `getTabs()` returning single `main` tab
2. Blade view without tabs navigation

### 5. Create View Directory

Ensure the Blade view directory exists:
```bash
mkdir -p resources/views/filament/{panel}/pages/
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| page-name | Yes | - | PascalCase class name |
| --panel | No | Admin | Target panel |
| --tabs | No | main | Comma-separated tab keys |
| --single | No | false | Single-tab mode (no tabs UI) |
| --group | No | Dashboard | Navigation group |
| --icon | No | heroicon-o-chart-bar | Navigation icon |
| --sort | No | 10 | Navigation sort order |

## Tab Format

Tabs can be specified in two formats:

**Simple:** `overview,users,revenue`
- Auto-generates titles from keys (ucfirst)
- No icons

**Detailed:** `overview:Overview:heroicon-o-home,users:Users:heroicon-o-users`
- Format: `key:title:icon`
- Full control over display

## Output

### Multi-Tab Dashboard

**PHP Class:** `app/Filament/{Panel}/Pages/{PageName}.php`

```php
<?php

declare(strict_types=1);

namespace App\Filament\Admin\Pages;

use BackedEnum;
use Filament\Pages\Page;

class Analytics extends Page
{
    protected static string $view = 'filament.admin.pages.analytics';

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-chart-bar';
    protected static ?string $navigationLabel = 'Analytics';
    protected static \UnitEnum|string|null $navigationGroup = 'Dashboard';
    protected static ?int $navigationSort = 10;

    public string $activeTab = 'overview';

    /**
     * @return array<int, array{
     *   key: string,
     *   title: string,
     *   icon?: string,
     *   message?: string,
     *   messageColor?: string,
     *   widgets?: array<int, class-string>
     * }>
     */
    public function getTabs(): array
    {
        return [
            [
                'key' => 'overview',
                'icon' => 'heroicon-o-home',
                'title' => 'Overview',
                'message' => '<strong>Overview:</strong> Key metrics at a glance.',
                'messageColor' => 'blue',
                'widgets' => [
                    // TODO: Add widget classes
                    // \App\Filament\Admin\Widgets\StatsOverview::class,
                ],
            ],
            [
                'key' => 'users',
                'icon' => 'heroicon-o-users',
                'title' => 'Users',
                'messageColor' => 'green',
                'widgets' => [
                    // TODO: Add widget classes
                ],
            ],
            [
                'key' => 'revenue',
                'icon' => 'heroicon-o-currency-dollar',
                'title' => 'Revenue',
                'messageColor' => 'purple',
                'widgets' => [
                    // TODO: Add widget classes
                ],
            ],
        ];
    }

    public function getActiveTabData(): ?array
    {
        return collect($this->getTabs())->firstWhere('key', $this->activeTab);
    }
}
```

**Blade View:** `resources/views/filament/admin/pages/analytics.blade.php`

```blade
<x-filament-panels::page>
    @php
        $tabs = $this->getTabs();
        $activeTabData = $this->getActiveTabData();

        if (! $activeTabData && count($tabs) > 0) {
            $this->activeTab = $tabs[0]['key'];
            $activeTabData = $tabs[0];
        }
    @endphp

    <div class="space-y-6">
        {{-- Tabs Navigation --}}
        <div class="border-b border-gray-200 dark:border-gray-700">
            <nav class="-mb-px flex flex-wrap gap-x-8" aria-label="Tabs">
                @foreach($tabs as $tab)
                    <button
                        type="button"
                        wire:click="$set('activeTab', '{{ $tab['key'] }}')"
                        @class([
                            'flex items-center gap-2 whitespace-nowrap border-b-2 py-4 px-1 text-sm font-medium',
                            'border-primary-500 text-primary-600 dark:border-primary-400 dark:text-primary-400' => $activeTab === $tab['key'],
                            'border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:border-gray-600 dark:hover:text-gray-300' => $activeTab !== $tab['key'],
                        ])
                    >
                        @if(!empty($tab['icon']))
                            <x-filament::icon :icon="$tab['icon']" class="h-5 w-5" />
                        @endif

                        {{ $tab['title'] }}
                    </button>
                @endforeach
            </nav>
        </div>

        {{-- Tab Content --}}
        @if($activeTabData)
            <div class="space-y-6">
                @if(!empty($activeTabData['message']))
                    @php $color = $activeTabData['messageColor'] ?? 'gray'; @endphp

                    <div @class([
                        'rounded-lg p-4 border',
                        'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800' => $color === 'blue',
                        'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800' => $color === 'green',
                        'bg-purple-50 dark:bg-purple-900/20 border-purple-200 dark:border-purple-800' => $color === 'purple',
                        'bg-orange-50 dark:bg-orange-900/20 border-orange-200 dark:border-orange-800' => $color === 'orange',
                        'bg-indigo-50 dark:bg-indigo-900/20 border-indigo-200 dark:border-indigo-800' => $color === 'indigo',
                        'bg-gray-50 dark:bg-gray-900/20 border-gray-200 dark:border-gray-800' => $color === 'gray',
                    ])>
                        <p @class([
                            'text-sm',
                            'text-blue-700 dark:text-blue-300' => $color === 'blue',
                            'text-green-700 dark:text-green-300' => $color === 'green',
                            'text-purple-700 dark:text-purple-300' => $color === 'purple',
                            'text-orange-700 dark:text-orange-300' => $color === 'orange',
                            'text-indigo-700 dark:text-indigo-300' => $color === 'indigo',
                            'text-gray-700 dark:text-gray-300' => $color === 'gray',
                        ])>
                            {!! $activeTabData['message'] !!}
                        </p>
                    </div>
                @endif

                @if(!empty($activeTabData['widgets']))
                    <x-filament-widgets::widgets :widgets="$activeTabData['widgets']" />
                @endif
            </div>
        @endif
    </div>
</x-filament-panels::page>
```

### Single-Tab Dashboard

**PHP Class:** `app/Filament/{Panel}/Pages/{PageName}.php`

```php
<?php

declare(strict_types=1);

namespace App\Filament\Admin\Pages;

use BackedEnum;
use Filament\Pages\Page;

class BillingOverview extends Page
{
    protected static string $view = 'filament.admin.pages.billing-overview';

    protected static string|BackedEnum|null $navigationIcon = 'heroicon-o-credit-card';
    protected static ?string $navigationLabel = 'Billing';
    protected static \UnitEnum|string|null $navigationGroup = 'Dashboard';
    protected static ?int $navigationSort = 20;

    public string $activeTab = 'main';

    public function getTabs(): array
    {
        return [
            [
                'key' => 'main',
                'title' => 'Billing Overview',
                'message' => '<strong>Billing:</strong> Monitor subscriptions, invoices, and payment status.',
                'messageColor' => 'blue',
                'widgets' => [
                    // TODO: Add widget classes
                    // \App\Filament\Admin\Widgets\BillingStats::class,
                    // \App\Filament\Admin\Widgets\RecentInvoices::class,
                ],
            ],
        ];
    }

    public function getActiveTabData(): ?array
    {
        return $this->getTabs()[0] ?? null;
    }
}
```

**Blade View:** `resources/views/filament/admin/pages/billing-overview.blade.php`

```blade
<x-filament-panels::page>
    @php
        $activeTabData = $this->getActiveTabData();
    @endphp

    <div class="space-y-6">
        @if($activeTabData)
            @if(!empty($activeTabData['message']))
                @php $color = $activeTabData['messageColor'] ?? 'gray'; @endphp

                <div @class([
                    'rounded-lg p-4 border',
                    'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800' => $color === 'blue',
                    'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800' => $color === 'green',
                    'bg-purple-50 dark:bg-purple-900/20 border-purple-200 dark:border-purple-800' => $color === 'purple',
                    'bg-orange-50 dark:bg-orange-900/20 border-orange-200 dark:border-orange-800' => $color === 'orange',
                    'bg-indigo-50 dark:bg-indigo-900/20 border-indigo-200 dark:border-indigo-800' => $color === 'indigo',
                    'bg-gray-50 dark:bg-gray-900/20 border-gray-200 dark:border-gray-800' => $color === 'gray',
                ])>
                    <p @class([
                        'text-sm',
                        'text-blue-700 dark:text-blue-300' => $color === 'blue',
                        'text-green-700 dark:text-green-300' => $color === 'green',
                        'text-purple-700 dark:text-purple-300' => $color === 'purple',
                        'text-orange-700 dark:text-orange-300' => $color === 'orange',
                        'text-indigo-700 dark:text-indigo-300' => $color === 'indigo',
                        'text-gray-700 dark:text-gray-300' => $color === 'gray',
                    ])>
                        {!! $activeTabData['message'] !!}
                    </p>
                </div>
            @endif

            @if(!empty($activeTabData['widgets']))
                <x-filament-widgets::widgets :widgets="$activeTabData['widgets']" />
            @endif
        @endif
    </div>
</x-filament-panels::page>
```

## Message Colors

Available colors for the message callout:

| Color | Use Case |
|-------|----------|
| `blue` | Informational, neutral |
| `green` | Success, positive metrics |
| `purple` | Premium, revenue |
| `orange` | Warnings, attention needed |
| `indigo` | Special features |
| `gray` | Secondary, muted |

## Checklist

After generation, verify:

- [ ] `$view` path matches Blade file location
- [ ] `$activeTab` default matches first tab key
- [ ] Each tab has unique `key` and `title`
- [ ] Widget classes exist or have TODO comments
- [ ] Blade view directory exists
- [ ] Navigation shows in correct group
- [ ] Tab switching works (Livewire reactive)
- [ ] Message callouts display correctly
- [ ] Dark mode styles work

## Integration with Widgets

After creating the dashboard page, use `/filament:widget` to generate widgets:

```bash
# Stats overview for dashboard
/filament:widget "Dashboard stats" --type stats

# Chart for analytics tab
/filament:widget "Revenue chart" --type chart

# Table widget for recent items
/filament:widget "Latest orders" --type table
```

Then add the widget class references to the appropriate tabs.
