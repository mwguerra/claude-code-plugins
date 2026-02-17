---
description: Orchestrate launch preparation - SEO, screenshots, personas, ads, articles, and landing pages in dependency order
argument-hint: [init|run|status|seo|screenshots|personas|ads|articles|landing] [options]
allowed-tools: Bash, Read, Write, Glob, Grep, Task
---

# Post-Development Command

Master command to orchestrate all post-development tasks for app launch preparation.

## Subcommands

### `init` - Initialize post-development
Creates the `.post-development` folder structure and master plan.

```
/post-dev init [--base-url http://localhost:3000] [--project-type saas|ecommerce|blog|portfolio]
```

### `run` - Execute all pending tasks
Runs all tasks in dependency order. **Auto-initializes if not already set up** — discovers the project, creates the directory structure, and populates the master plan before executing.

```
/post-dev run [--task seo|screenshots|personas|ads|articles|landing] [--parallel] [--force]
```

### `status` - Check task status
Shows progress of all post-development tasks.

```
/post-dev status [--verbose] [--task <task-id>]
```

### Individual Task Commands

```
/post-dev seo          # Run SEO analysis only
/post-dev screenshots  # Capture screenshots only
/post-dev personas     # Create personas only
/post-dev ads          # Generate ads only
/post-dev articles     # Write articles only
/post-dev landing      # Create landing pages only
```

## Instructions

1. Parse the subcommand from `$ARGUMENTS`
2. Load or create the master plan at `.post-development/post-development.json`
3. Execute the appropriate action

### For `init`:

1. Run the **Project Auto-Discovery** steps below
2. Create the directory structure and master plan

### For `run`:

1. **Auto-init if needed**: Check if `.post-development/post-development.json` exists.
   - If it does NOT exist, run the full **Project Auto-Discovery** and **Directory Structure Creation** steps below before proceeding. Do NOT ask the user to run `init` first — just do it automatically.
   - If it DOES exist, load the existing master plan.
2. Build dependency graph:
   - `seo` → no dependencies
   - `screenshots` → no dependencies
   - `personas` → depends on `seo`
   - `ads` → depends on `personas`, `screenshots`
   - `articles` → depends on `personas`, `screenshots`
   - `landing` → depends on `personas`, `screenshots`
3. Execute tasks in topological order
4. Update status after each task
5. Report results

### For individual tasks (`seo`, `screenshots`, `personas`, `ads`, `articles`, `landing`):

1. **Auto-init if needed**: Same check as `run` — if `.post-development/post-development.json` doesn't exist, auto-discover and initialize first.
2. Check that all dependency tasks are complete. If not, run them first.
3. Delegate to the appropriate agent:
   - `seo` → Use SEO Analyst agent
   - `screenshots` → Use Screenshot Planner agent
   - `personas` → Use Persona Strategist agent
   - `ads` → Use Ad Creator agent
   - `articles` → Use Content Writer agent
   - `landing` → Use Landing Page Designer agent

### For `status`:

Display progress table:
```
Post-Development Status
===========================
Project: MyApp (SaaS)
Started: 2025-01-15

Tasks:
  [done]    seo          SEO Analysis           Done     2025-01-15 10:30
  [done]    screenshots  Screenshot Capture     Done     2025-01-15 10:35
  [run]     personas     Persona Creation       Running  -
  [wait]    ads          Ad Generation          Pending  -
  [wait]    articles     Article Writing        Pending  -
  [wait]    landing      Landing Pages          Pending  -

Progress: [====------] 33% (2/6 tasks)
```

---

## Project Auto-Discovery

When initializing (either via `init` or auto-init from `run`), discover everything about the project automatically. Do NOT require the user to provide a base URL or project type — detect them.

### Step 1: Detect Project Type and Tech Stack

Read the project's configuration files to identify the framework and stack:

- **`package.json`** → Node.js project. Check `dependencies` for:
  - `next` → Next.js (SSR/SSG)
  - `react` + `react-router-dom` or `@remix-run` → React SPA/Remix
  - `vue` → Vue.js
  - `nuxt` → Nuxt.js
  - `svelte` or `@sveltejs/kit` → SvelteKit
  - `astro` → Astro
  - `gatsby` → Gatsby
- **`composer.json`** → PHP project. Check `require` for:
  - `laravel/framework` → Laravel
  - `filament/*` → Laravel + Filament
  - `wordpress/*` → WordPress
- **`Gemfile`** → Ruby. Check for `rails` → Ruby on Rails
- **`requirements.txt` / `pyproject.toml`** → Python. Check for `django`, `flask`, `fastapi`
- **`go.mod`** → Go
- **`Cargo.toml`** → Rust

Store the detected tech stack.

### Step 2: Detect Base URL

Try to auto-discover the base URL:

1. Check `.env` or `.env.local` for `APP_URL`, `BASE_URL`, `NEXT_PUBLIC_URL`, `VITE_APP_URL`, `NUXT_PUBLIC_SITE_URL`, or similar
2. Check `package.json` scripts for `--port` flags (e.g., `"dev": "next dev -p 3001"`)
3. Check `vite.config.*` or `next.config.*` for port configuration
4. Check `docker-compose.yml` for port mappings
5. Check `.env` for `APP_PORT` or `PORT`
6. **Fallback**: Use `http://localhost:3000` for Node projects, `http://localhost:8000` for Laravel/Django, `http://localhost:4321` for Astro

### Step 3: Discover Public Routes/Pages

Depending on the framework:

- **Next.js (App Router)**: Glob `app/**/page.{tsx,jsx,ts,js}`, exclude `(api)`, `_`, and route groups starting with `(`
- **Next.js (Pages Router)**: Glob `pages/**/*.{tsx,jsx,ts,js}`, exclude `_app`, `_document`, `api/`
- **React Router**: Search for `<Route path=` patterns in source files
- **Vue Router**: Read `router/index.{ts,js}` or search for `path:` in router config
- **Laravel**: Run `php artisan route:list --json` if available, or search `routes/web.php` for `Route::get` patterns
- **Rails**: Parse `config/routes.rb` for `get` and `root` declarations
- **Astro**: Glob `src/pages/**/*.{astro,md,mdx}`
- **Static**: Glob `*.html`, `public/*.html`

Filter out:
- Admin/dashboard routes (`/admin`, `/dashboard`, `/panel`)
- Auth routes (`/login`, `/register`, `/password`)
- API routes (`/api/*`)
- Internal routes (`/_next`, `/_nuxt`)

### Step 4: Extract Product Information

Read these files for product context:

- **`README.md`** → Project name, description, features
- **`package.json`** → `name`, `description`
- **`composer.json`** → `name`, `description`
- **Landing page / homepage component** → Headlines, value propositions, feature lists
- **`CLAUDE.md`** → Project-specific context

### Step 5: Detect Existing Branding

Search for branding assets:

- Logo files: Glob `**/*logo*`, `**/brand*`, `public/images/*`
- Color configuration: Search for theme config in `tailwind.config.*`, CSS custom properties in `globals.css` or `:root`
- Fonts: Check `<link>` tags or `@font-face` in CSS, or font imports in layout files

### Step 6: Determine Project Type

Based on routes, features, and documentation, classify the project:

- **SaaS**: Has `/pricing`, `/features`, auth system, dashboard
- **E-commerce**: Has `/products`, `/cart`, `/checkout`, payment integration
- **Blog/Content**: Has `/posts`, `/articles`, `/blog`, content management
- **Portfolio**: Has `/projects`, `/work`, `/about`, `/contact`
- **Documentation**: Has `/docs`, uses MDX/markdown content
- **Landing Page**: Single page or few pages, heavy on marketing copy
- **API/Tool**: Has `/api`, developer documentation, integration guides

### Step 7: Create Directory Structure and Master Plan

1. Create the full directory structure:
   ```
   .post-development/
   ├── seo/
   │   ├── pages/
   │   └── assets/
   │       ├── favicons/
   │       └── og-images/
   ├── screenshots/
   ├── personas/
   │   ├── strategies/
   │   └── cta/
   ├── ads/
   │   ├── instagram/
   │   ├── facebook/
   │   ├── linkedin/
   │   └── twitter/
   ├── articles/
   │   ├── article-1/
   │   ├── article-2/
   │   └── article-3/
   ├── landing-pages/
   └── post-development.json
   ```

2. Write `post-development.json` with all discovered data:
   ```json
   {
     "project": {
       "name": "<detected>",
       "description": "<from README or package>",
       "type": "<detected: saas|ecommerce|blog|portfolio|docs|landing|api>",
       "techStack": ["<detected frameworks and libraries>"],
       "baseUrl": "<detected or fallback>",
       "routes": ["<discovered public routes>"],
       "branding": {
         "logoPath": "<if found>",
         "colors": { "primary": "<if found>", "secondary": "<if found>" },
         "fonts": ["<if found>"]
       },
       "analyzedAt": "<current ISO timestamp>"
     },
     "tasks": {
       "seo": { "status": "pending", "dependsOn": [] },
       "screenshots": { "status": "pending", "dependsOn": [] },
       "personas": { "status": "pending", "dependsOn": ["seo"] },
       "ads": { "status": "pending", "dependsOn": ["personas", "screenshots"] },
       "articles": { "status": "pending", "dependsOn": ["personas", "screenshots"] },
       "landing": { "status": "pending", "dependsOn": ["personas", "screenshots"] }
     },
     "config": {
       "baseUrl": "<detected>",
       "outputDir": ".post-development",
       "targetMarkets": ["<inferred from project type>"]
     },
     "progress": {
       "completedTasks": 0,
       "totalTasks": 6,
       "startedAt": null,
       "completedAt": null
     }
   }
   ```

3. Report what was discovered:
   ```
   Post-Development Auto-Discovery
   ================================
   Project:    MyApp
   Type:       SaaS
   Stack:      Next.js, TypeScript, Tailwind CSS
   Base URL:   http://localhost:3000
   Routes:     / /features /pricing /about /blog /docs
   Branding:   Logo found, Tailwind theme detected

   Ready to run. Executing tasks...
   ```

---

## Task Dependencies

```
        +-------------+
        |    seo      |
        +------+------+
               |
        +------v------+     +-------------+
        |  personas   |     | screenshots |
        +------+------+     +------+------+
               |                   |
    +----------+-------------------+
    |          |                   |
+---v---+  +--v----+         +----v----+
|  ads  |  |articles|         | landing |
+-------+  +-------+         +---------+
```

## Output

After each operation, report:
- Tasks completed
- Tasks pending
- Any errors encountered
- Next steps

## Quick Start Example

```bash
# Just run everything — auto-discovers and initializes
/post-dev run

# Or initialize first with explicit options
/post-dev init --base-url http://localhost:3000

# Run a specific task (auto-inits if needed)
/post-dev seo

# Check progress
/post-dev status
```
