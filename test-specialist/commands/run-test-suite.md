---
description: Execute comprehensive Pest 4 test suites for PHP, Laravel, Livewire, and Filament applications
allowed-tools: Bash(./vendor/bin/pest:*), Bash(php:*), Bash(composer:*), Read, Glob, Grep
argument-hint: "[suite] [--filter pattern] [--parallel] [--coverage] [--bail]"
---

# Run Test Suite

Execute comprehensive Pest 4 test suites for PHP, Laravel, Livewire, and Filament applications with various testing strategies and configurations.

## Syntax
```bash
guerra:run-test-suite [options] [suite]
```

## Options
- `--suite=<n>` - Run specific test suite (unit, feature, integration, all)
- `--filter=<pattern>` - Filter tests by name pattern
- `--group=<n>` - Run specific test group
- `--parallel` - Run tests in parallel
- `--coverage` - Include coverage report
- `--profile` - Profile test execution time
- `--bail` - Stop on first failure
- `--retry=<n>` - Retry failed tests n times
- `--ci` - Run in CI mode with optimizations

## Documentation Reference
1. **Pest Documentation** - https://pestphp.com/docs
2. **PHPUnit Documentation** - https://phpunit.de/documentation.html
3. **Laravel Testing** - https://laravel.com/docs/testing

## Test Suite Execution Strategies

### Basic Test Execution
```bash
# Run all tests
./vendor/bin/pest

# Run with coverage
./vendor/bin/pest --coverage --min=80

# Run specific test file
./vendor/bin/pest tests/Feature/PostTest.php

# Run specific test by name
./vendor/bin/pest --filter="can create post"

# Run tests in specific directory
./vendor/bin/pest tests/Feature/Posts
```

### Parallel Test Execution
```bash
# Run tests in parallel (auto-detect cores)
./vendor/bin/pest --parallel

# Run tests with specific number of processes
./vendor/bin/pest --parallel --processes=4

# Parallel with coverage (slower but thorough)
./vendor/bin/pest --parallel --coverage
```

### Group-Based Execution
```php
<?php

// Define test groups
it('can create post', function () {
    // Test implementation
})->group('posts', 'crud');

it('validates required fields', function () {
    // Test implementation
})->group('posts', 'validation');

it('can archive post', function () {
    // Test implementation
})->group('posts', 'actions');
```

```bash
# Run specific group
./vendor/bin/pest --group=posts

# Run multiple groups
./vendor/bin/pest --group=posts,validation

# Exclude specific group
./vendor/bin/pest --exclude-group=slow
```

### Performance Profiling
```bash
# Profile slow tests
./vendor/bin/pest --profile

# Profile with time limit (show tests > 500ms)
./vendor/bin/pest --profile --min=500

# Top 10 slowest tests
./vendor/bin/pest --profile --top=10
```

## Comprehensive Test Suite Structure

### Suite 1: Unit Tests (Fast)
```php
<?php

// tests/Unit/Models/PostTest.php
describe('Post Model', function () {
    it('has correct fillable attributes', function () {
        $post = new Post();
        expect($post->getFillable())->toContain('title', 'content', 'status');
    });

    it('casts attributes correctly', function () {
        $post = Post::factory()->create([
            'published_at' => '2024-01-01 12:00:00',
        ]);
        
        expect($post->published_at)->toBeInstanceOf(Carbon::class);
    });

    it('generates slug from title', function () {
        $post = new Post(['title' => 'Test Post']);
        expect($post->slug)->toBe('test-post');
    });

    it('calculates reading time', function () {
        $post = Post::factory()->create([
            'content' => str_repeat('word ', 500),
        ]);
        
        expect($post->reading_time)->toBe(2);
    });
})->group('unit', 'models', 'fast');

// tests/Unit/Services/PostServiceTest.php
describe('PostService', function () {
    it('can create post with tags', function () {
        $service = app(PostService::class);
        $tags = Tag::factory()->count(3)->create();
        
        $post = $service->create([
            'title' => 'Test Post',
            'content' => 'Test Content',
            'tag_ids' => $tags->pluck('id')->toArray(),
        ]);
        
        expect($post->tags)->toHaveCount(3);
    });

    it('publishes post and sends notifications', function () {
        Notification::fake();
        
        $service = app(PostService::class);
        $post = Post::factory()->draft()->create();
        
        $service->publish($post);
        
        expect($post->refresh()->status)->toBe('published');
        Notification::assertSentTo($post->user, PostPublished::class);
    });
})->group('unit', 'services', 'fast');
```

### Suite 2: Feature Tests (Medium)
```php
<?php

// tests/Feature/Posts/CreatePostTest.php
describe('Create Post Feature', function () {
    beforeEach(function () {
        $this->author = User::factory()->author()->create();
        actingAs($this->author);
    });

    it('displays create post form', function () {
        get('/posts/create')
            ->assertSuccessful()
            ->assertSee('Create Post');
    });

    it('can create post with valid data', function () {
        post('/posts', [
            'title' => 'Test Post',
            'content' => 'Test Content',
            'status' => 'draft',
        ])
            ->assertRedirect('/posts')
            ->assertSessionHas('success');

        expect(Post::count())->toBe(1);
    });

    it('validates required fields', function () {
        post('/posts', [])
            ->assertSessionHasErrors(['title', 'content']);
    });

    it('sanitizes content', function () {
        post('/posts', [
            'title' => 'Test Post',
            'content' => '<script>alert("xss")</script><p>Safe content</p>',
        ]);

        $post = Post::first();
        expect($post->content)
            ->not->toContain('<script>')
            ->toContain('<p>');
    });

    it('associates post with authenticated user', function () {
        post('/posts', [
            'title' => 'Test Post',
            'content' => 'Test Content',
        ]);

        $post = Post::first();
        expect($post->user_id)->toBe($this->author->id);
    });
})->group('feature', 'posts', 'crud', 'medium');

// tests/Feature/Auth/LoginTest.php
describe('Login Feature', function () {
    it('displays login form', function () {
        get('/login')
            ->assertSuccessful()
            ->assertSee('Login');
    });

    it('can login with valid credentials', function () {
        $user = User::factory()->create([
            'password' => bcrypt('password'),
        ]);

        post('/login', [
            'email' => $user->email,
            'password' => 'password',
        ])
            ->assertRedirect('/dashboard');

        expect(auth()->check())->toBeTrue();
        expect(auth()->id())->toBe($user->id);
    });

    it('fails with invalid credentials', function () {
        post('/login', [
            'email' => 'wrong@example.com',
            'password' => 'wrong',
        ])
            ->assertSessionHasErrors();

        expect(auth()->check())->toBeFalse();
    });

    it('throttles login attempts', function () {
        $user = User::factory()->create();

        for ($i = 0; $i < 5; $i++) {
            post('/login', [
                'email' => $user->email,
                'password' => 'wrong',
            ]);
        }

        post('/login', [
            'email' => $user->email,
            'password' => 'wrong',
        ])
            ->assertStatus(429);
    });
})->group('feature', 'auth', 'security', 'medium');
```

### Suite 3: Integration Tests (Slow)
```php
<?php

// tests/Integration/PostPublishingWorkflowTest.php
describe('Post Publishing Workflow', function () {
    it('completes full publishing workflow', function () {
        // Setup
        $author = User::factory()->author()->create();
        $editor = User::factory()->editor()->create();
        actingAs($author);

        // Author creates draft
        post('/posts', [
            'title' => 'Test Post',
            'content' => 'Test Content',
            'status' => 'draft',
        ]);

        $post = Post::first();
        expect($post->status)->toBe('draft');

        // Author submits for review
        actingAs($author);
        post("/posts/{$post->id}/submit-review");
        
        expect($post->refresh()->status)->toBe('pending_review');

        // Editor reviews and approves
        actingAs($editor);
        post("/posts/{$post->id}/approve");
        
        expect($post->refresh()->status)->toBe('approved');

        // Editor publishes
        post("/posts/{$post->id}/publish");
        
        $post = $post->refresh();
        expect($post->status)->toBe('published');
        expect($post->published_at)->not->toBeNull();

        // Verify notifications sent
        Notification::assertSentTo($author, PostPublished::class);

        // Verify post appears on public site
        get('/blog')
            ->assertSee($post->title);
    });
})->group('integration', 'workflows', 'slow');

// tests/Integration/UserRegistrationWorkflowTest.php
describe('User Registration and Onboarding', function () {
    it('completes full registration workflow', function () {
        Mail::fake();
        Queue::fake();

        // Register
        post('/register', [
            'name' => 'John Doe',
            'email' => 'john@example.com',
            'password' => 'password',
            'password_confirmation' => 'password',
        ])
            ->assertRedirect('/dashboard');

        $user = User::where('email', 'john@example.com')->first();
        expect($user)->not->toBeNull();

        // Email verification sent
        Mail::assertSent(VerifyEmail::class);

        // Verify email
        $verificationUrl = URL::temporarySignedRoute(
            'verification.verify',
            now()->addMinutes(60),
            ['id' => $user->id, 'hash' => sha1($user->email)]
        );

        get($verificationUrl)
            ->assertRedirect('/dashboard');

        expect($user->refresh()->email_verified_at)->not->toBeNull();

        // Onboarding job dispatched
        Queue::assertPushed(ProcessOnboarding::class);
    });
})->group('integration', 'workflows', 'slow');
```

### Suite 4: Browser Tests (Very Slow)
```php
<?php

// tests/Browser/PostManagementTest.php
use Laravel\Dusk\Browser;

describe('Post Management Browser Tests', function () {
    it('can create, edit, and delete post via UI', function () {
        $this->browse(function (Browser $browser) {
            $user = User::factory()->admin()->create();

            $browser->loginAs($user)
                ->visit('/admin/posts')
                ->assertSee('Posts')
                ->clickLink('New Post')
                ->type('title', 'Browser Test Post')
                ->type('content', 'Browser Test Content')
                ->select('status', 'draft')
                ->press('Save')
                ->assertPathIs('/admin/posts')
                ->assertSee('Post created successfully')
                ->assertSee('Browser Test Post');

            // Edit
            $browser->click('@edit-post')
                ->type('title', 'Updated Title')
                ->press('Save')
                ->assertSee('Updated Title');

            // Delete
            $browser->click('@delete-post')
                ->whenAvailable('.modal', function ($modal) {
                    $modal->press('Confirm');
                })
                ->assertDontSee('Updated Title');
        });
    })->group('browser', 'e2e', 'very-slow');
})->skip(fn() => !env('RUN_BROWSER_TESTS'));
```

## Test Execution Configurations

### Local Development
```bash
# Quick feedback loop (unit tests only)
./vendor/bin/pest --group=fast

# Feature tests
./vendor/bin/pest --group=feature

# Skip slow tests
./vendor/bin/pest --exclude-group=slow
```

### Pre-Commit
```bash
# Run all except browser tests
./vendor/bin/pest --exclude-group=browser --parallel

# With coverage
./vendor/bin/pest --exclude-group=browser --coverage --min=80
```

### CI/CD Pipeline
```bash
# Stage 1: Fast tests
./vendor/bin/pest --group=fast --parallel --bail

# Stage 2: Feature tests
./vendor/bin/pest --group=feature --parallel

# Stage 3: Integration tests
./vendor/bin/pest --group=integration

# Stage 4: Coverage report
./vendor/bin/pest --coverage --min=80 --coverage-html=coverage

# Stage 5: Browser tests (optional)
./vendor/bin/pest --group=browser
```

## Custom Test Commands

### PHP Script for Advanced Execution
```php
#!/usr/bin/env php
<?php

// guerra-test-suite.php
require __DIR__.'/vendor/autoload.php';

class TestSuiteRunner
{
    protected array $suites = [
        'quick' => ['--group=fast', '--parallel'],
        'full' => ['--exclude-group=browser'],
        'critical' => ['--group=auth,payment,security'],
        'coverage' => ['--coverage', '--min=80'],
    ];

    public function run(string $suite): int
    {
        $options = $this->suites[$suite] ?? [];
        $command = './vendor/bin/pest ' . implode(' ', $options);
        
        echo "Running: $command\n";
        passthru($command, $exitCode);
        
        return $exitCode;
    }
}

$runner = new TestSuiteRunner();
$suite = $argv[1] ?? 'full';
exit($runner->run($suite));
```

```bash
# Usage
php guerra-test-suite.php quick
php guerra-test-suite.php full
php guerra-test-suite.php critical
php guerra-test-suite.php coverage
```

## Performance Optimization

### Speed Up Tests
1. **Use in-memory SQLite**
```xml
<!-- phpunit.xml -->
<php>
    <env name="DB_CONNECTION" value="sqlite"/>
    <env name="DB_DATABASE" value=":memory:"/>
</php>
```

2. **Disable unnecessary features**
```php
// tests/TestCase.php
protected function setUp(): void
{
    parent::setUp();
    
    $this->withoutVite();
    $this->withoutMix();
}
```

3. **Use parallel execution**
```bash
./vendor/bin/pest --parallel --processes=8
```

4. **Mock external services**
```php
beforeEach(function () {
    Http::fake();
    Mail::fake();
    Queue::fake();
});
```

## Continuous Integration Examples

### GitHub Actions
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        php: [8.2, 8.3]
        
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: ${{ matrix.php }}
          
      - name: Install Dependencies
        run: composer install
        
      - name: Run Fast Tests
        run: ./vendor/bin/pest --group=fast --parallel
        
      - name: Run Feature Tests
        run: ./vendor/bin/pest --group=feature --parallel
        
      - name: Run Integration Tests
        run: ./vendor/bin/pest --group=integration
        
      - name: Coverage Report
        run: ./vendor/bin/pest --coverage --min=80
```

### GitLab CI
```yaml
test:
  stage: test
  image: php:8.3
  
  before_script:
    - composer install
    
  script:
    - ./vendor/bin/pest --exclude-group=browser --parallel
    - ./vendor/bin/pest --coverage --min=80
    
  coverage: '/^\s*Lines:\s*\d+.\d+\%/'
  
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
```

## Best Practices
1. **Run fast tests frequently** - Quick feedback
2. **Run full suite before commits** - Catch issues early
3. **Use parallel execution** - Save time
4. **Group tests logically** - Easy to target
5. **Profile slow tests** - Optimize bottlenecks
6. **Skip external dependencies** - Use fakes/mocks
7. **Maintain test independence** - Avoid flaky tests
8. **Monitor test trends** - Track performance over time

## Quality Checklist
- [ ] All test groups defined
- [ ] Fast tests run in < 10 seconds
- [ ] Feature tests run in < 2 minutes
- [ ] Integration tests complete successfully
- [ ] Parallel execution configured
- [ ] CI/CD pipeline optimized
- [ ] Coverage meets threshold
- [ ] No flaky tests
- [ ] Test performance tracked
- [ ] Documentation up to date
