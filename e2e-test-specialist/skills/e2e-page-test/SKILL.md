---
name: e2e-page-test
description: Systematically test all pages for errors, functionality, and proper rendering using Playwright MCP
---

# E2E Page Testing Skill

## Overview

This skill systematically tests every page in an application using Playwright MCP. It verifies page loading, element rendering, interaction functionality, and error detection.

## Purpose

Ensure that:
- All pages load without errors
- All expected elements are present
- All interactions work correctly
- No console or network errors occur
- Pages are accessible and functional

## Workflow

### Step 1: Page Inventory

1. **List All Pages**
   - Extract from route definitions
   - Include dynamic route patterns
   - Note authentication requirements

2. **Categorize Pages**
   - Public pages
   - Authenticated pages
   - Admin pages
   - Special pages (error pages, maintenance, etc.)

3. **Define Expected Elements**
   - Navigation elements
   - Main content areas
   - Forms and inputs
   - Action buttons
   - Footer elements

### Step 2: Page Load Testing

For EACH page:

1. **Navigate to Page**
   ```
   browser_navigate({ url: "/page-path" })
   ```

2. **Wait for Load**
   ```
   browser_wait_for({ text: "Expected content" })
   OR
   browser_wait_for({ time: 2 })
   ```

3. **Capture Snapshot**
   ```
   browser_snapshot()
   ```

4. **Check Console Messages**
   ```
   browser_console_messages({ level: "error" })
   ```

5. **Check Network Requests**
   ```
   browser_network_requests()
   ```

### Step 3: Element Verification

For each page, verify:

1. **Navigation**
   - Header present
   - Menu items visible
   - Logo displayed
   - Navigation links work

2. **Main Content**
   - Title/heading present
   - Expected content visible
   - Images loaded
   - Data displayed (if applicable)

3. **Forms (if present)**
   - All inputs visible
   - Labels present
   - Submit button enabled
   - Validation messages work

4. **Footer**
   - Footer visible
   - Links work
   - Copyright present

### Step 4: Interaction Testing

1. **Link Testing**
   ```
   For each link on page:
     browser_click on link
     browser_snapshot to verify destination
     browser_navigate_back
   ```

2. **Button Testing**
   ```
   For each button:
     browser_click on button
     Verify expected action occurs
     Check for errors
   ```

3. **Form Testing**
   ```
   browser_fill_form with test data
   browser_click submit
   Verify success or validation errors
   ```

4. **Dropdown Testing**
   ```
   browser_select_option on dropdowns
   Verify selection applied
   ```

### Step 5: Error Detection

1. **Console Errors**
   ```
   browser_console_messages({ level: "error" })

   Common errors to detect:
   - Uncaught exceptions
   - Failed to load resource
   - CORS errors
   - API errors
   - Component errors
   ```

2. **Network Errors**
   ```
   browser_network_requests()

   Check for:
   - 4xx errors (client errors)
   - 5xx errors (server errors)
   - Failed requests
   - Timeout errors
   ```

3. **Visual Errors**
   ```
   browser_snapshot()

   Look for:
   - Broken layout
   - Missing images
   - Overlapping elements
   - Unreadable text
   ```

### Step 6: Responsive Testing

Test each page at multiple viewports:

1. **Desktop (1920x1080)**
   ```
   browser_resize({ width: 1920, height: 1080 })
   browser_navigate to page
   browser_snapshot
   Verify desktop layout
   ```

2. **Tablet (768x1024)**
   ```
   browser_resize({ width: 768, height: 1024 })
   browser_navigate to page
   browser_snapshot
   Verify tablet layout
   ```

3. **Mobile (375x812)**
   ```
   browser_resize({ width: 375, height: 812 })
   browser_navigate to page
   browser_snapshot
   Verify mobile layout
   Verify mobile menu works
   ```

## Test Patterns

### Basic Page Test
```
1. browser_navigate({ url: "/page" })
2. browser_wait_for({ time: 2 }) // Wait for load
3. snapshot = browser_snapshot()
4. errors = browser_console_messages({ level: "error" })
5. requests = browser_network_requests()

// Verify
Assert: snapshot contains expected elements
Assert: errors is empty
Assert: no failed requests in network
```

### Form Page Test
```
1. browser_navigate({ url: "/form-page" })
2. browser_snapshot() // Verify form present

// Test empty submission
3. browser_click({ element: "Submit button", ref: "[submit-ref]" })
4. browser_snapshot() // Should show validation errors

// Test valid submission
5. browser_fill_form({
     fields: [
       { name: "Name", type: "textbox", ref: "[name-ref]", value: "Test User" },
       { name: "Email", type: "textbox", ref: "[email-ref]", value: "test@example.com" }
     ]
   })
6. browser_click({ element: "Submit button", ref: "[submit-ref]" })
7. browser_wait_for({ text: "Success" })
8. browser_snapshot() // Verify success
```

### Navigation Test
```
1. browser_navigate({ url: "/" })
2. browser_snapshot() // Get all navigation refs

For each nav link:
3. browser_click({ element: "Nav link", ref: "[link-ref]" })
4. browser_snapshot() // Verify correct page loaded
5. browser_navigate_back()
```

### Dynamic Content Test
```
1. browser_navigate({ url: "/data-page" })
2. browser_wait_for({ text: "Loading..." }) // Wait for loading state
3. browser_wait_for({ textGone: "Loading..." }) // Wait for content
4. browser_snapshot() // Verify data displayed
5. browser_console_messages({ level: "error" }) // Check for errors
```

## Common Page Types

### Home Page
```markdown
Expected Elements:
- Hero section with headline
- Feature highlights
- Call-to-action buttons
- Navigation header
- Footer

Tests:
- [ ] Hero content visible
- [ ] CTA buttons clickable
- [ ] Navigation works
- [ ] Footer links work
```

### Login Page
```markdown
Expected Elements:
- Email/username field
- Password field
- Submit button
- Forgot password link
- Register link

Tests:
- [ ] Form displays correctly
- [ ] Empty submission shows errors
- [ ] Invalid credentials show error
- [ ] Valid credentials redirect
- [ ] Forgot password link works
```

### Dashboard Page
```markdown
Expected Elements:
- Welcome message
- Statistics/widgets
- Navigation sidebar
- User menu
- Action buttons

Tests:
- [ ] Loads for authenticated users
- [ ] Redirects unauthenticated users
- [ ] Widgets display data
- [ ] Actions are functional
```

### List Page
```markdown
Expected Elements:
- Data table or list
- Pagination
- Search/filter
- Action buttons (edit, delete)

Tests:
- [ ] Data displays correctly
- [ ] Pagination works
- [ ] Search filters data
- [ ] Actions are functional
- [ ] Empty state handled
```

### Form Page
```markdown
Expected Elements:
- Form fields
- Labels
- Validation messages
- Submit button
- Cancel button

Tests:
- [ ] All fields editable
- [ ] Validation works
- [ ] Submit saves data
- [ ] Cancel returns to list
- [ ] Required fields enforced
```

## Output Format

### Page Test Results
```markdown
# Page Test Results

## Summary
- Total Pages: 25
- Passed: 23
- Failed: 2
- Skipped: 0

## Detailed Results

### Public Pages

#### Home (/)
- Status: PASSED
- Load Time: 1.2s
- Console Errors: 0
- Network Errors: 0
- Elements Verified:
  - [x] Header navigation
  - [x] Hero section
  - [x] Feature cards
  - [x] Footer

#### About (/about)
- Status: PASSED
- Load Time: 0.8s
- Console Errors: 0
- Network Errors: 0
- Elements Verified:
  - [x] Page title
  - [x] Content sections
  - [x] Team members

### Authenticated Pages

#### Dashboard (/dashboard)
- Status: FAILED
- Load Time: 2.5s
- Console Errors: 1
  - Error: "Cannot read property 'name' of undefined"
- Network Errors: 0
- Elements Verified:
  - [x] Welcome message
  - [ ] Statistics widget - MISSING
  - [x] Recent activity

#### Profile (/profile)
- Status: PASSED
- Load Time: 1.1s
- Console Errors: 0
- Network Errors: 0
- Elements Verified:
  - [x] User information
  - [x] Edit button
  - [x] Avatar

### Responsive Tests

#### Home Page
- Desktop (1920x1080): PASSED
- Tablet (768x1024): PASSED
- Mobile (375x812): FAILED
  - Issue: Navigation menu overlaps content

## Errors Found

1. **Dashboard Widget Error**
   - Page: /dashboard
   - Error: Cannot read property 'name' of undefined
   - Likely Cause: User data not loaded before rendering

2. **Mobile Navigation Issue**
   - Page: /home
   - Issue: Navigation overlaps on mobile
   - Likely Cause: CSS media query issue

## Recommendations

1. Fix Dashboard data loading sequence
2. Adjust mobile navigation CSS
3. Add loading states for async data
```

## Best Practices

1. **Wait for Page Load** - Don't check elements too quickly
2. **Use Snapshots** - Capture state at each step
3. **Check Console/Network** - Look for hidden errors
4. **Test All Viewports** - Responsive issues are common
5. **Document Everything** - Note all elements tested
6. **Test Interactions** - Don't just check static content
7. **Handle Dynamic Content** - Wait for data to load
