---
description: Generate comprehensive Pest 4 tests for Laravel authorization policies and gates
allowed-tools: Bash(./vendor/bin/pest:*), Bash(php:*), Read, Write, Glob, Grep
argument-hint: "[policy] [--model name] [--all] [--roles] [--gates] [--middleware]"
---

# Test Policies

Generate comprehensive Pest 4 tests for Laravel authorization policies, ensuring all permission gates, role-based access controls, and authorization scenarios are thoroughly tested.

## Syntax
```bash
test-specialist:policies [options] [policy]
```

## Options
- `--policy=<name>` - Generate tests for specific policy
- `--model=<name>` - Generate policy tests for specific model
- `--all` - Generate tests for all policies
- `--roles` - Include role-based testing scenarios
- `--gates` - Include gate authorization tests
- `--middleware` - Include middleware authorization tests
- `--force` - Overwrite existing test files

## Documentation Reference Order
1. **Pest 4 Documentation** - Testing syntax and patterns
2. **Laravel Authorization** - https://laravel.com/docs/authorization
3. **Laravel Policies** - https://laravel.com/docs/authorization#creating-policies
4. **Filament Authorization** - https://filamentphp.com/docs/panels/users#authorization

## Policy Test Structure

### Standard Policy Tests
```php
<?php

use App\Models\{User, Post};
use function Pest\Laravel\actingAs;

describe('PostPolicy', function () {
    beforeEach(function () {
        // Setup users with different roles
        $this->admin = User::factory()->create(['role' => 'admin']);
        $this->editor = User::factory()->create(['role' => 'editor']);
        $this->author = User::factory()->create(['role' => 'author']);
        $this->user = User::factory()->create(['role' => 'user']);
        
        // Setup test data
        $this->post = Post::factory()->create(['user_id' => $this->author->id]);
        $this->publishedPost = Post::factory()->published()->create();
        $this->draftPost = Post::factory()->draft()->create();
    });

    describe('viewAny', function () {
        it('allows admins to view any posts', function () {
            expect($this->admin->can('viewAny', Post::class))->toBeTrue();
        });

        it('allows editors to view any posts', function () {
            expect($this->editor->can('viewAny', Post::class))->toBeTrue();
        });

        it('allows authors to view their posts', function () {
            expect($this->author->can('viewAny', Post::class))->toBeTrue();
        });

        it('denies regular users from viewing post management', function () {
            expect($this->user->can('viewAny', Post::class))->toBeFalse();
        });

        it('denies guests from viewing posts', function () {
            expect(app(PostPolicy::class)->viewAny(null))->toBeFalse();
        });
    });

    describe('view', function () {
        it('allows admins to view any post', function () {
            expect($this->admin->can('view', $this->post))->toBeTrue();
            expect($this->admin->can('view', $this->draftPost))->toBeTrue();
        });

        it('allows authors to view their own posts', function () {
            expect($this->author->can('view', $this->post))->toBeTrue();
        });

        it('denies authors from viewing others posts', function () {
            $otherPost = Post::factory()->create(['user_id' => $this->user->id]);
            expect($this->author->can('view', $otherPost))->toBeFalse();
        });

        it('allows anyone to view published posts', function () {
            expect($this->user->can('view', $this->publishedPost))->toBeTrue();
        });

        it('denies users from viewing draft posts', function () {
            expect($this->user->can('view', $this->draftPost))->toBeFalse();
        });
    });

    describe('create', function () {
        it('allows admins to create posts', function () {
            expect($this->admin->can('create', Post::class))->toBeTrue();
        });

        it('allows authors to create posts', function () {
            expect($this->author->can('create', Post::class))->toBeTrue();
        });

        it('allows editors to create posts', function () {
            expect($this->editor->can('create', Post::class))->toBeTrue();
        });

        it('denies regular users from creating posts', function () {
            expect($this->user->can('create', Post::class))->toBeFalse();
        });
    });

    describe('update', function () {
        it('allows admins to update any post', function () {
            expect($this->admin->can('update', $this->post))->toBeTrue();
        });

        it('allows editors to update any post', function () {
            expect($this->editor->can('update', $this->post))->toBeTrue();
        });

        it('allows authors to update their own posts', function () {
            expect($this->author->can('update', $this->post))->toBeTrue();
        });

        it('denies authors from updating others posts', function () {
            $otherPost = Post::factory()->create(['user_id' => $this->user->id]);
            expect($this->author->can('update', $otherPost))->toBeFalse();
        });

        it('denies updating published posts by non-admins', function () {
            expect($this->author->can('update', $this->publishedPost))->toBeFalse();
        });
    });

    describe('delete', function () {
        it('allows admins to delete any post', function () {
            expect($this->admin->can('delete', $this->post))->toBeTrue();
        });

        it('denies editors from deleting posts', function () {
            expect($this->editor->can('delete', $this->post))->toBeFalse();
        });

        it('allows authors to delete their own draft posts', function () {
            $draft = Post::factory()->draft()->create(['user_id' => $this->author->id]);
            expect($this->author->can('delete', $draft))->toBeTrue();
        });

        it('denies authors from deleting published posts', function () {
            $published = Post::factory()->published()->create(['user_id' => $this->author->id]);
            expect($this->author->can('delete', $published))->toBeFalse();
        });
    });

    describe('restore', function () {
        it('allows admins to restore deleted posts', function () {
            $deletedPost = Post::factory()->create();
            $deletedPost->delete();
            
            expect($this->admin->can('restore', $deletedPost))->toBeTrue();
        });

        it('denies non-admins from restoring posts', function () {
            $deletedPost = Post::factory()->create(['user_id' => $this->author->id]);
            $deletedPost->delete();
            
            expect($this->author->can('restore', $deletedPost))->toBeFalse();
        });
    });

    describe('forceDelete', function () {
        it('allows only admins to permanently delete posts', function () {
            $deletedPost = Post::factory()->create();
            $deletedPost->delete();
            
            expect($this->admin->can('forceDelete', $deletedPost))->toBeTrue();
            expect($this->editor->can('forceDelete', $deletedPost))->toBeFalse();
            expect($this->author->can('forceDelete', $deletedPost))->toBeFalse();
        });
    });

    describe('publish', function () {
        it('allows admins to publish any post', function () {
            expect($this->admin->can('publish', $this->draftPost))->toBeTrue();
        });

        it('allows editors to publish any post', function () {
            expect($this->editor->can('publish', $this->draftPost))->toBeTrue();
        });

        it('denies authors from publishing posts', function () {
            expect($this->author->can('publish', $this->draftPost))->toBeFalse();
        });
    });
});
```

### Multi-Model Relationship Policy Tests
```php
<?php

use App\Models\{User, Team, Project};

describe('ProjectPolicy with Team Context', function () {
    beforeEach(function () {
        $this->team = Team::factory()->create();
        $this->owner = User::factory()->create();
        $this->member = User::factory()->create();
        $this->outsider = User::factory()->create();
        
        $this->team->users()->attach($this->owner, ['role' => 'owner']);
        $this->team->users()->attach($this->member, ['role' => 'member']);
        
        $this->project = Project::factory()->create([
            'team_id' => $this->team->id
        ]);
    });

    it('allows team owners to manage projects', function () {
        expect($this->owner->can('update', $this->project))->toBeTrue();
        expect($this->owner->can('delete', $this->project))->toBeTrue();
    });

    it('allows team members to view projects', function () {
        expect($this->member->can('view', $this->project))->toBeTrue();
    });

    it('denies team members from managing projects', function () {
        expect($this->member->can('update', $this->project))->toBeFalse();
        expect($this->member->can('delete', $this->project))->toBeFalse();
    });

    it('denies outsiders from accessing team projects', function () {
        expect($this->outsider->can('view', $this->project))->toBeFalse();
    });
});
```

### Gate Authorization Tests
```php
<?php

use App\Models\User;
use Illuminate\Support\Facades\Gate;

describe('Authorization Gates', function () {
    beforeEach(function () {
        $this->superAdmin = User::factory()->create(['is_super_admin' => true]);
        $this->admin = User::factory()->create(['role' => 'admin']);
        $this->user = User::factory()->create();
    });

    describe('access-admin-panel', function () {
        it('allows super admins', function () {
            expect(Gate::forUser($this->superAdmin)->allows('access-admin-panel'))->toBeTrue();
        });

        it('allows admins', function () {
            expect(Gate::forUser($this->admin)->allows('access-admin-panel'))->toBeTrue();
        });

        it('denies regular users', function () {
            expect(Gate::forUser($this->user)->denies('access-admin-panel'))->toBeTrue();
        });
    });

    describe('manage-users', function () {
        it('allows super admins', function () {
            expect(Gate::forUser($this->superAdmin)->allows('manage-users'))->toBeTrue();
        });

        it('denies admins', function () {
            expect(Gate::forUser($this->admin)->denies('manage-users'))->toBeTrue();
        });
    });

    describe('view-analytics', function () {
        it('allows users with analytics permission', function () {
            $this->admin->givePermissionTo('view-analytics');
            expect(Gate::forUser($this->admin)->allows('view-analytics'))->toBeTrue();
        });

        it('denies users without analytics permission', function () {
            expect(Gate::forUser($this->user)->denies('view-analytics'))->toBeTrue();
        });
    });
});
```

### Middleware Authorization Tests
```php
<?php

use App\Models\User;
use function Pest\Laravel\{actingAs, get};

describe('Authorization Middleware', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        $this->user = User::factory()->create();
    });

    describe('admin middleware', function () {
        it('allows admins to access protected routes', function () {
            actingAs($this->admin)
                ->get('/admin/dashboard')
                ->assertSuccessful();
        });

        it('denies non-admins from accessing protected routes', function () {
            actingAs($this->user)
                ->get('/admin/dashboard')
                ->assertForbidden();
        });

        it('redirects guests to login', function () {
            get('/admin/dashboard')
                ->assertRedirect('/login');
        });
    });

    describe('permission middleware', function () {
        it('allows users with specific permission', function () {
            $this->user->givePermissionTo('edit-posts');
            
            actingAs($this->user)
                ->get('/posts/1/edit')
                ->assertSuccessful();
        });

        it('denies users without permission', function () {
            actingAs($this->user)
                ->get('/posts/1/edit')
                ->assertForbidden();
        });
    });

    describe('role middleware', function () {
        it('allows users with required role', function () {
            $editor = User::factory()->create(['role' => 'editor']);
            
            actingAs($editor)
                ->get('/editor/dashboard')
                ->assertSuccessful();
        });

        it('denies users with different role', function () {
            actingAs($this->user)
                ->get('/editor/dashboard')
                ->assertForbidden();
        });
    });
});
```

### Filament Resource Authorization Tests
```php
<?php

use App\Filament\Resources\PostResource;
use App\Models\{User, Post};
use function Pest\Livewire\livewire;

describe('Filament Resource Authorization', function () {
    beforeEach(function () {
        $this->admin = User::factory()->admin()->create();
        $this->editor = User::factory()->editor()->create();
        $this->user = User::factory()->create();
        $this->post = Post::factory()->create();
    });

    describe('Resource Access', function () {
        it('allows admins to access post resource', function () {
            actingAs($this->admin);
            
            livewire(PostResource\Pages\ListPosts::class)
                ->assertSuccessful();
        });

        it('allows editors to access post resource', function () {
            actingAs($this->editor);
            
            livewire(PostResource\Pages\ListPosts::class)
                ->assertSuccessful();
        });

        it('denies regular users from accessing post resource', function () {
            actingAs($this->user);
            
            livewire(PostResource\Pages\ListPosts::class)
                ->assertForbidden();
        });
    });

    describe('Record Actions', function () {
        it('shows delete action for admins', function () {
            actingAs($this->admin);
            
            livewire(PostResource\Pages\EditPost::class, [
                'record' => $this->post->getRouteKey(),
            ])
                ->assertActionVisible('delete');
        });

        it('hides delete action for editors', function () {
            actingAs($this->editor);
            
            livewire(PostResource\Pages\EditPost::class, [
                'record' => $this->post->getRouteKey(),
            ])
                ->assertActionHidden('delete');
        });
    });
});
```

### Permission-Based Policy Tests
```php
<?php

use App\Models\{User, Post};
use Spatie\Permission\Models\{Role, Permission};

describe('Permission-Based Authorization', function () {
    beforeEach(function () {
        // Create permissions
        Permission::create(['name' => 'create posts']);
        Permission::create(['name' => 'edit posts']);
        Permission::create(['name' => 'delete posts']);
        Permission::create(['name' => 'publish posts']);
        
        // Create roles with permissions
        $adminRole = Role::create(['name' => 'admin']);
        $adminRole->givePermissionTo(Permission::all());
        
        $editorRole = Role::create(['name' => 'editor']);
        $editorRole->givePermissionTo(['create posts', 'edit posts', 'publish posts']);
        
        $authorRole = Role::create(['name' => 'author']);
        $authorRole->givePermissionTo(['create posts', 'edit posts']);
        
        // Create users
        $this->admin = User::factory()->create();
        $this->admin->assignRole('admin');
        
        $this->editor = User::factory()->create();
        $this->editor->assignRole('editor');
        
        $this->author = User::factory()->create();
        $this->author->assignRole('author');
        
        $this->post = Post::factory()->create();
    });

    it('allows users with create permission to create posts', function () {
        expect($this->admin->can('create', Post::class))->toBeTrue();
        expect($this->editor->can('create', Post::class))->toBeTrue();
        expect($this->author->can('create', Post::class))->toBeTrue();
    });

    it('allows users with publish permission to publish posts', function () {
        expect($this->admin->can('publish', $this->post))->toBeTrue();
        expect($this->editor->can('publish', $this->post))->toBeTrue();
        expect($this->author->can('publish', $this->post))->toBeFalse();
    });

    it('allows only users with delete permission to delete posts', function () {
        expect($this->admin->can('delete', $this->post))->toBeTrue();
        expect($this->editor->can('delete', $this->post))->toBeFalse();
        expect($this->author->can('delete', $this->post))->toBeFalse();
    });

    it('respects direct permissions over role permissions', function () {
        $this->author->givePermissionTo('delete posts');
        
        expect($this->author->can('delete', $this->post))->toBeTrue();
    });
});
```

## Testing Ownership and Relationships
```php
describe('Ownership-Based Authorization', function () {
    beforeEach(function () {
        $this->owner = User::factory()->create();
        $this->otherUser = User::factory()->create();
        $this->post = Post::factory()->create(['user_id' => $this->owner->id]);
    });

    it('allows owners to update their content', function () {
        expect($this->owner->can('update', $this->post))->toBeTrue();
    });

    it('denies non-owners from updating content', function () {
        expect($this->otherUser->can('update', $this->post))->toBeFalse();
    });

    it('allows owners to delete their content', function () {
        expect($this->owner->can('delete', $this->post))->toBeTrue();
    });
});
```

## Best Practices
1. **Test all policy methods** - Don't skip any authorization logic
2. **Test all user roles** - Verify each role's permissions
3. **Test edge cases** - Include ownership, guests, soft deletes
4. **Test relationships** - Verify related model authorization
5. **Test custom gates** - Don't forget Gate::define() declarations
6. **Test middleware** - Verify route protection
7. **Test Filament resources** - Check admin panel authorization
8. **Use descriptive names** - Make intent clear in test names

## Quality Checklist
- [ ] All policy methods have tests
- [ ] All user roles are tested
- [ ] Guest access scenarios covered
- [ ] Ownership validation tested
- [ ] Gates and abilities tested
- [ ] Middleware authorization verified
- [ ] Filament resource access tested
- [ ] Edge cases covered
- [ ] Tests use proper Pest 4 syntax
- [ ] All tests pass successfully

## Common Policy Patterns to Test
- ✅ CRUD operations (view, create, update, delete)
- ✅ Bulk operations (viewAny, deleteAny)
- ✅ Soft delete operations (restore, forceDelete)
- ✅ Custom actions (publish, archive, approve)
- ✅ Ownership checks
- ✅ Role-based access
- ✅ Permission-based access
- ✅ Relationship-based access
- ✅ Status-based access (draft, published, archived)

## Error Handling
If policy tests fail:
1. Verify policy is registered in AuthServiceProvider
2. Check Gate::define() declarations
3. Verify model relationships
4. Check role and permission seeding
5. Review middleware configuration
6. Validate Filament resource policies
