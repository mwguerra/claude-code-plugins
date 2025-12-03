# guerra:analyze-coverage

## Command Overview
Analyze test coverage for PHP, Laravel, Livewire, and Filament projects using Pest 4, identifying gaps and suggesting improvements.

## Syntax
```bash
guerra:analyze-coverage [options] [target]
```

## Options
- `--path=<n>` - Analyze specific path or file
- `--min=<n>` - Set minimum coverage threshold (default: 80)
- `--report=<type>` - Generate report (html, text, clover, xml)
- `--missing` - Show only missing coverage
- `--detailed` - Show detailed line-by-line coverage
- `--suggest` - Suggest tests for uncovered code
- `--save` - Save report to file

## Documentation Reference
1. **Pest Coverage** - https://pestphp.com/docs/coverage
2. **PHPUnit Coverage** - https://phpunit.de/manual/current/en/code-coverage-analysis.html
3. **Laravel Testing** - https://laravel.com/docs/testing

## Coverage Analysis Implementation

### Step 1: Run Coverage Analysis
```bash
# Basic coverage
./vendor/bin/pest --coverage

# Coverage with minimum threshold
./vendor/bin/pest --coverage --min=80

# Coverage with HTML report
./vendor/bin/pest --coverage --coverage-html=coverage-report

# Coverage for specific path
./vendor/bin/pest --coverage tests/Feature/Posts

# Coverage with detailed output
./vendor/bin/pest --coverage --coverage-text
```

### Step 2: Analyze Coverage Report
```php
<?php

// Coverage analysis structure
[
    'summary' => [
        'lines_covered' => 850,
        'lines_total' => 1000,
        'percentage' => 85.0,
        'methods_covered' => 120,
        'methods_total' => 150,
        'classes_covered' => 25,
        'classes_total' => 30,
    ],
    'by_directory' => [
        'app/Models' => [
            'percentage' => 95.0,
            'lines' => [850, 900],
        ],
        'app/Http/Controllers' => [
            'percentage' => 75.0,
            'lines' => [600, 800],
        ],
        'app/Policies' => [
            'percentage' => 60.0,
            'lines' => [120, 200],
        ],
    ],
    'uncovered_files' => [
        'app/Services/PaymentService.php',
        'app/Helpers/StringHelper.php',
    ],
]
```

### Step 3: Identify Coverage Gaps
```php
<?php

// Example: Identify untested methods
class CoverageAnalyzer
{
    public function findUncoveredMethods(): array
    {
        return [
            'PostController::archive' => [
                'file' => 'app/Http/Controllers/PostController.php',
                'lines' => [45, 52],
                'complexity' => 3,
                'priority' => 'high',
            ],
            'PostPolicy::publish' => [
                'file' => 'app/Policies/PostPolicy.php',
                'lines' => [78, 85],
                'complexity' => 2,
                'priority' => 'high',
            ],
            'Post::getExcerpt' => [
                'file' => 'app/Models/Post.php',
                'lines' => [156, 160],
                'complexity' => 1,
                'priority' => 'medium',
            ],
        ];
    }

    public function findUncoveredBranches(): array
    {
        return [
            'PostController::update' => [
                'uncovered_conditions' => [
                    'if ($request->has("publish"))' => 'line 67',
                    'elseif ($post->isLocked())' => 'line 72',
                ],
            ],
        ];
    }

    public function findCriticalUncovered(): array
    {
        return [
            'authentication' => [
                'LoginController::attempt',
                'RegisterController::create',
            ],
            'authorization' => [
                'PostPolicy::forceDelete',
                'UserPolicy::impersonate',
            ],
            'payment_processing' => [
                'PaymentService::refund',
                'PaymentService::capture',
            ],
        ];
    }
}
```

## Coverage Report Formats

### Text Report
```text
Code Coverage Report:
  2024-10-27 10:30:45

Summary:
  Classes:  83.33% (25/30)
  Methods:  80.00% (120/150)
  Lines:    85.00% (850/1000)

app/Models
  Post.php                     95.00%
  User.php                     90.00%
  Comment.php                  85.00%
  Category.php                 70.00%

app/Http/Controllers
  PostController.php           80.00%
  UserController.php           75.00%
  CommentController.php        65.00%

app/Policies
  PostPolicy.php               70.00%
  UserPolicy.php               65.00%
  CommentPolicy.php            55.00%

Uncovered Files:
  app/Services/PaymentService.php
  app/Services/NotificationService.php
  app/Helpers/StringHelper.php
```

### HTML Report Structure
```html
<!DOCTYPE html>
<html>
<head>
    <title>Coverage Report</title>
    <style>
        .covered { background: #d4edda; }
        .uncovered { background: #f8d7da; }
        .partially { background: #fff3cd; }
    </style>
</head>
<body>
    <h1>Coverage Report: 85.00%</h1>
    
    <table>
        <tr>
            <th>File</th>
            <th>Coverage</th>
            <th>Lines</th>
            <th>Methods</th>
        </tr>
        <tr class="covered">
            <td>app/Models/Post.php</td>
            <td>95.00%</td>
            <td>190/200</td>
            <td>18/20</td>
        </tr>
        <tr class="partially">
            <td>app/Policies/PostPolicy.php</td>
            <td>70.00%</td>
            <td>70/100</td>
            <td>7/10</td>
        </tr>
    </table>
</body>
</html>
```

## Test Suggestions Based on Coverage

### Generate Test Stubs for Uncovered Code
```php
<?php

// For uncovered controller method
describe('PostController archive method', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        $this->post = Post::factory()->published()->create();
        actingAs($this->admin);
    });

    it('can archive published post', function () {
        post("/posts/{$this->post->id}/archive")
            ->assertRedirect()
            ->assertSessionHas('success');

        expect($this->post->refresh()->status)->toBe('archived');
    });

    it('prevents archiving already archived post', function () {
        $this->post->update(['status' => 'archived']);

        post("/posts/{$this->post->id}/archive")
            ->assertSessionHasErrors();

        expect($this->post->refresh()->status)->toBe('archived');
    });

    it('dispatches post archived event', function () {
        Event::fake();

        post("/posts/{$this->post->id}/archive");

        Event::assertDispatched(PostArchived::class);
    });
});

// For uncovered policy method
describe('PostPolicy publish method', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        $this->editor = User::factory()->editor()->create();
        $this->author = User::factory()->author()->create();
        $this->post = Post::factory()->draft()->create();
    });

    it('allows admins to publish posts', function () {
        expect($this->admin->can('publish', $this->post))->toBeTrue();
    });

    it('allows editors to publish posts', function () {
        expect($this->editor->can('publish', $this->post))->toBeTrue();
    });

    it('denies authors from publishing posts', function () {
        expect($this->author->can('publish', $this->post))->toBeFalse();
    });

    it('prevents publishing already published posts', function () {
        $this->post->update(['status' => 'published']);
        expect($this->admin->can('publish', $this->post))->toBeFalse();
    });
});

// For uncovered model method
describe('Post getExcerpt method', function () {
    it('returns first 150 characters', function () {
        $post = Post::factory()->create([
            'content' => str_repeat('a', 200),
        ]);

        expect($post->getExcerpt())
            ->toHaveLength(150)
            ->toEndWith('...');
    });

    it('returns full content if shorter than 150 characters', function () {
        $post = Post::factory()->create([
            'content' => 'Short content',
        ]);

        expect($post->getExcerpt())
            ->toBe('Short content')
            ->not->toEndWith('...');
    });

    it('strips HTML tags from excerpt', function () {
        $post = Post::factory()->create([
            'content' => '<p>Content with <strong>HTML</strong> tags</p>',
        ]);

        expect($post->getExcerpt())
            ->not->toContain('<')
            ->not->toContain('>');
    });
});
```

## Priority-Based Test Generation

### Critical Priority (Must Test)
```php
// Authentication & Authorization
- Login/logout flows
- Password reset
- Registration
- Policy methods
- Gate definitions
- Middleware authorization

// Payment & Transactions
- Payment processing
- Refunds
- Transaction logging
- Invoice generation

// Data Integrity
- Database migrations
- Model relationships
- Validation rules
- Soft deletes
```

### High Priority (Should Test)
```php
// Business Logic
- Core workflows
- State transitions
- Event dispatching
- Job processing

// API Endpoints
- Request validation
- Response formatting
- Error handling
- Rate limiting

// User Interactions
- Form submissions
- File uploads
- AJAX requests
- Real-time updates
```

### Medium Priority (Nice to Test)
```php
// UI Components
- Livewire components
- Vue components
- Blade components

// Utility Functions
- Helper methods
- Service classes
- Formatting functions

// Admin Features
- Filament resources
- Custom actions
- Widgets
```

## Coverage Improvement Strategies

### Strategy 1: Fill Coverage Gaps
```bash
# Identify files with < 50% coverage
guerra:analyze-coverage --min=50 --missing

# Generate tests for identified gaps
guerra:generate-pest-test --path=app/Services/PaymentService.php

# Re-run coverage
guerra:analyze-coverage --path=app/Services/PaymentService.php
```

### Strategy 2: Increase Branch Coverage
```php
// Before: Only happy path tested
it('can update post', function () {
    $post = Post::factory()->create();
    
    put("/posts/{$post->id}", [
        'title' => 'Updated Title',
    ])->assertRedirect();
});

// After: All branches tested
describe('Post update', function () {
    it('can update post with valid data', function () {
        // Happy path
    });

    it('validates required fields', function () {
        // Validation branch
    });

    it('prevents unauthorized updates', function () {
        // Authorization branch
    });

    it('handles concurrent updates', function () {
        // Edge case branch
    });
});
```

### Strategy 3: Test Edge Cases
```php
describe('Edge cases for post creation', function () {
    it('handles maximum title length', function () {
        // Test boundary
    });

    it('handles empty content', function () {
        // Test empty state
    });

    it('handles special characters in slug', function () {
        // Test special inputs
    });

    it('handles duplicate slugs', function () {
        // Test uniqueness
    });

    it('handles concurrent creations', function () {
        // Test race conditions
    });
});
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Test Coverage

on: [push, pull_request]

jobs:
  coverage:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          coverage: xdebug
      
      - name: Install Dependencies
        run: composer install
      
      - name: Run Tests with Coverage
        run: ./vendor/bin/pest --coverage --min=80
      
      - name: Generate Coverage Report
        run: ./vendor/bin/pest --coverage-html=coverage
      
      - name: Upload Coverage
        uses: actions/upload-artifact@v2
        with:
          name: coverage-report
          path: coverage/
```

## Best Practices
1. **Set minimum thresholds** - Enforce coverage standards
2. **Focus on critical paths** - Prioritize important code
3. **Test edge cases** - Don't just test happy paths
4. **Review regularly** - Check coverage in code reviews
5. **Improve incrementally** - Don't try to reach 100% at once
6. **Ignore generated code** - Exclude migrations, configs
7. **Track trends** - Monitor coverage over time
8. **Use coverage to find gaps** - Not as a goal itself

## Quality Checklist
- [ ] Overall coverage meets minimum threshold (80%+)
- [ ] Critical paths have 100% coverage
- [ ] All policies tested
- [ ] All controllers tested
- [ ] All models tested
- [ ] Edge cases covered
- [ ] Branch coverage adequate
- [ ] No untested public methods
- [ ] Coverage report generated
- [ ] Trends tracked over time

## Coverage Configuration

### PHPUnit.xml Coverage Settings
```xml
<phpunit>
    <coverage>
        <include>
            <directory suffix=".php">./app</directory>
        </include>
        <exclude>
            <directory>./app/Console</directory>
            <file>./app/Providers/RouteServiceProvider.php</file>
        </exclude>
        <report>
            <html outputDirectory="coverage-report"/>
            <text outputFile="php://stdout"/>
            <clover outputFile="coverage.xml"/>
        </report>
    </coverage>
</phpunit>
```

## Interpreting Coverage Metrics

### Coverage Percentages
- **90-100%**: Excellent - Comprehensive testing
- **80-89%**: Good - Solid coverage, minor gaps
- **70-79%**: Fair - Some important areas uncovered
- **60-69%**: Poor - Significant gaps
- **< 60%**: Critical - Major testing needed

### What Coverage Doesn't Tell You
- ❌ Quality of assertions
- ❌ Test maintainability
- ❌ Edge case handling
- ❌ Integration quality
- ❌ Real-world usage patterns

### Balanced Approach
✅ Use coverage as a guide, not a goal
✅ Focus on meaningful tests
✅ Prioritize critical code paths
✅ Don't sacrifice quality for coverage
✅ Review tests, not just numbers
