---
description: Open the project with Playwright, demonstrate all basic features with examples, take screenshots, and record the entire navigation session
---

# Showcase Command

Use Playwright to interactively demonstrate the application's features, capturing screenshots and recording the entire session for documentation purposes.

## Usage

```
/code:showcase                     # Full demo with screenshots and recording
/code:showcase --dark              # Force dark mode (default)
/code:showcase --light             # Use light mode instead
/code:showcase --focus=auth        # Focus on specific feature area
/code:showcase --focus=dashboard   # Demo dashboard features only
/code:showcase --no-record         # Skip video recording
/code:showcase --output=./custom   # Custom output directory
```

## What This Command Does

This command launches Playwright to navigate through the application, demonstrating features while capturing visual documentation.

### Prerequisites

Before running, ensure:

1. **Application is running locally**
   ```bash
   php artisan serve
   # or
   npm run dev
   ```

2. **Playwright is available**
   - The browser_subagent tool will handle Playwright interactions
   - Recordings are automatically saved as WebP videos

3. **Test user credentials available**
   - Ensure seeded test users exist for login demonstrations

## Execution Flow

### Phase 1: Environment Setup

1. **Detect application URL**
   - Check for running dev server
   - Default: `http://localhost:8000` or configured URL

2. **Configure browser settings**
   ```
   - Color scheme: dark (default) or light
   - Viewport: 1920x1080 (desktop)
   - Device emulation: None (desktop first)
   ```

3. **Create output directory**
   - Default: `.showcase/[YYYYMMDD_HHMM]_output/`
   - Example: `.showcase/20251219_2048_output/`
   - Contains: auth/, dashboard/, [feature]/, recordings/
   - Each run creates a new timestamped folder for comparison

### Phase 2: Dark Mode Configuration

1. **Set browser to prefer dark mode**
   - Use `prefers-color-scheme: dark` media feature
   - Verify application respects system preference

2. **If application has theme toggle**
   - Locate and toggle to dark mode
   - Capture before/after screenshots

### Phase 3: Feature Discovery

Automatically detect available features:

| Feature Area | Detection Method |
|--------------|------------------|
| Authentication | Look for login/register routes |
| Dashboard | Check for /dashboard or /admin |
| CRUD Operations | Find resource routes |
| User Management | Detect user-related pages |
| Settings | Locate settings/preferences pages |
| Reports | Find report or analytics pages |

### Phase 4: Interactive Demonstration

For each discovered feature:

1. **Navigate to the page**
   - Use browser_subagent to navigate
   - Wait for page load completion

2. **Capture screenshot**
   - Filename: `[feature]-[action]-[timestamp].png`
   - Include full page capture
   - Annotate with feature name

3. **Demonstrate interactions**
   - Fill forms with example data
   - Click buttons and show results
   - Navigate between related pages

4. **Record user flows**
   - Login → Dashboard → Feature → Logout
   - CRUD: Create → Read → Update → Delete
   - Error states and validation

### Phase 5: Core Flows to Demonstrate

#### Authentication Flow
```
1. Navigate to login page → Screenshot
2. Show login form elements → Screenshot
3. Enter credentials and submit → Screenshot
4. Show successful login dashboard → Screenshot
5. Demonstrate logout → Screenshot
```

#### Dashboard Overview
```
1. Navigate to main dashboard → Screenshot
2. Highlight key metrics/widgets → Screenshot
3. Show navigation options → Screenshot
4. Demonstrate sidebar/nav interactions → Screenshot
```

#### CRUD Operations (for each resource)
```
1. Navigate to resource list → Screenshot
2. Click "Create New" → Screenshot form
3. Fill form with example data → Screenshot
4. Submit and show success → Screenshot
5. Edit the created item → Screenshot
6. Show delete confirmation → Screenshot
```

#### User Profile & Settings
```
1. Navigate to profile page → Screenshot
2. Show editable fields → Screenshot
3. Demonstrate settings options → Screenshot
4. Show preferences/theme toggle → Screenshot
```

### Phase 6: Recording Session

The entire session is automatically recorded via browser_subagent:

1. **Recording starts** when browser opens
2. **Continuous capture** of all navigation
3. **Recording saves** as WebP video to artifacts

Recording naming convention:
- `showcase_full_demo.webp` - Complete session
- `showcase_auth_flow.webp` - Authentication demo
- `showcase_crud_[resource].webp` - Per-resource demos

### Phase 7: Output Generation

#### Screenshots Directory Structure
```
.showcase/
└── 20251219_2048_output/
    ├── auth/
    │   ├── login-page.png
    │   ├── login-form-filled.png
    │   └── dashboard-after-login.png
    ├── dashboard/
    │   ├── main-view.png
    │   ├── widgets-detail.png
    │   └── navigation-open.png
    ├── [feature]/
    │   ├── list-view.png
    │   ├── create-form.png
    │   ├── edit-form.png
    │   └── delete-confirm.png
    ├── recordings/
    │   └── full-demo.webp
    └── SHOWCASE-REPORT.md
```

#### Generated Report
Creates `SHOWCASE-REPORT.md`:

```markdown
# Application Showcase Report

Generated: [timestamp]
Mode: Dark Mode
Total Screenshots: [X]
Recording Duration: [X:XX]

## Features Demonstrated

### Authentication
![Login Page](./auth/login-page.png)
- Login flow demonstrated
- Logout flow demonstrated

### Dashboard
![Dashboard](./dashboard/main-view.png)
- Main metrics visible
- Navigation working

### [Feature Name]
![Feature](./[feature]/list-view.png)
- CRUD operations demonstrated
- All validations working

## Recordings

- [Full Demo Recording](./recordings/full-demo.webp)

## Notes
- [Any observations about the UI]
- [Feature suggestions if applicable]
```

## Example Session

```
=== Showcase Session Started ===

Mode: Dark Mode
Output: .showcase/20251219_2048_output/

[1/10] Navigating to login page...
       ✓ Screenshot: auth/login-page.png

[2/10] Logging in as test user...
       ✓ Screenshot: auth/login-success.png

[3/10] Exploring dashboard...
       ✓ Screenshot: dashboard/main-view.png

[4/10] Demonstrating user management...
       ✓ Screenshot: users/list-view.png
       ✓ Screenshot: users/create-form.png
       ✓ Screenshot: users/edit-form.png

...

=== Showcase Complete ===

Screenshots: 24 captured
Recording: full-demo.webp (3:45 duration)
Report: SHOWCASE-REPORT.md generated

All files saved to: .showcase/20251219_2048_output/
```

## Integration

This command works with:
- **browser_subagent** - For Playwright browser control
- **generate_image** - For annotating screenshots if needed
- **view_file** - For reading configuration

## Tips for Best Results

1. **Seed test data first** - Ensure meaningful demo data exists
2. **Clean browser state** - Start fresh for consistent screenshots
3. **Use dark mode** - Better for documentation and presentations
4. **Run in full resolution** - 1920x1080 or higher recommended

## Notes

- All screenshots are captured at full page resolution
- Recordings are automatically saved by browser_subagent
- Dark mode is the default for better visual appearance
- Session can be interrupted; partial output is preserved
