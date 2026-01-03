# mwguerra Claude Code Plugins

A collection of Claude Code plugins for development workflows.

## Installation

```bash
# Add the marketplace
/plugin marketplace add mwguerra/claude-code-plugins

# Browse and install plugins
/plugin
```

## Available Plugins

### article-writer
Create publication-ready technical articles with author voice profiles, web research, runnable code examples, and multi-language output. Supports interactive single-article creation or autonomous batch processing.

```bash
/plugin install article-writer@mwguerra-marketplace
```

### code
Production readiness toolkit with code cleanup, comprehensive analysis, and automated testing. Removes debug artifacts for clean commits, runs Pest and Playwright tests, and prepares apps for deployment.

```bash
/plugin install code@mwguerra-marketplace
```

### docs-specialist
Generate and maintain documentation from code with drift detection. Validates docs against source, auto-generates from code patterns, syncs outdated content, and provides reusable templates.

```bash
/plugin install docs-specialist@mwguerra-marketplace
```

### docker-local
Expert agent for docker-local (mwguerra/docker-local) Laravel Docker development environment. Manages Docker services, diagnoses issues, checks project conflicts, handles database operations, and troubleshoots environment setup.

```bash
/plugin install docker-local@mwguerra-marketplace
```

### docker-specialist
Docker and Docker Compose expert with complete documentation. Generates Dockerfiles, compose configs, database containers, SSL/TLS setup with Traefik or Nginx, and provides troubleshooting.

```bash
/plugin install docker-specialist@mwguerra-marketplace
```

### e2e-test-specialist
Comprehensive E2E testing using Playwright MCP. Creates detailed test plans, tests all pages for errors, verifies user flows by role, and runs visual browser tests with full coverage.

```bash
/plugin install e2e-test-specialist@mwguerra-marketplace
```

### filament-specialist
Expert FilamentPHP v4 assistant with complete official documentation. Generates resources, forms, tables, actions, widgets, infolists, and Pest tests following v4 patterns.

```bash
/plugin install filament-specialist@mwguerra-marketplace
```

### laravel-filament-package-development-specialist
Scaffold and develop Laravel packages and Filament plugins with full testing support. Creates package structure, configures Pest testing, sets up GitHub Actions CI.

```bash
/plugin install laravel-filament-package-development-specialist@mwguerra-marketplace
```

### post-development
App launch preparation toolkit with SEO analysis, automated screenshots, buyer persona creation, social media ad generation, technical article writing, and landing page proposals.

```bash
/plugin install post-development@mwguerra-marketplace
```

### taskmanager
Plan and execute tasks from PRDs with hierarchical subtasks, dependency tracking, and project memories. Features dashboard visualization, autonomous batch execution, and persistent memory.

```bash
/plugin install taskmanager@mwguerra-marketplace
```

### terminal-specialist
Terminal and shell systems expert with comprehensive documentation. Covers TTY/PTY architecture, stdin/stdout/stderr streams, signals, ANSI escape sequences, job control, and terminal modes.

```bash
/plugin install terminal-specialist@mwguerra-marketplace
```

### test-specialist
Proactive Pest 4 testing for PHP, Laravel, Livewire, and Filament apps. Auto-generates tests for models, controllers, policies, and Livewire components. Analyzes coverage gaps.

```bash
/plugin install test-specialist@mwguerra-marketplace
```

## Reinstall Script

If you need to completely reinstall all marketplace plugins (useful after updates or to fix issues), add this script to `~/.claude/reinstall_marketplace.sh`:

```bash
#!/bin/bash

# Delete marketplaces cleanup script
# Removes marketplace plugins and related configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Cleaning up marketplace plugins..."

# Delete installed_plugins.json
if [ -f "$SCRIPT_DIR/plugins/installed_plugins.json" ]; then
    rm "$SCRIPT_DIR/plugins/installed_plugins.json"
    echo "Deleted: plugins/installed_plugins.json"
else
    echo "Not found: plugins/installed_plugins.json"
fi

# Delete marketplaces folder
if [ -d "$SCRIPT_DIR/plugins/marketplaces" ]; then
    rm -rf "$SCRIPT_DIR/plugins/marketplaces"
    echo "Deleted: plugins/marketplaces/"
else
    echo "Not found: plugins/marketplaces/"
fi

if [ -d "$SCRIPT_DIR/plugins/cache" ]; then
    rm -rf "$SCRIPT_DIR/plugins/cache"
    echo "Deleted: plugins/cache/"
else
    echo "Not found: plugins/cache/"
fi

# Remove enabledPlugins from settings.json using jq or sed
if [ -f "$SCRIPT_DIR/settings.json" ]; then
    if command -v jq &> /dev/null; then
        # Use jq if available
        jq 'del(.enabledPlugins)' "$SCRIPT_DIR/settings.json" > "$SCRIPT_DIR/settings.json.tmp" && \
        mv "$SCRIPT_DIR/settings.json.tmp" "$SCRIPT_DIR/settings.json"
        echo "Removed enabledPlugins from settings.json"
    else
        # Fallback to Python if jq not available
        python3 -c "
import json
with open('$SCRIPT_DIR/settings.json', 'r') as f:
    data = json.load(f)
if 'enabledPlugins' in data:
    del data['enabledPlugins']
with open('$SCRIPT_DIR/settings.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"
        echo "Removed enabledPlugins from settings.json"
    fi
else
    echo "Not found: settings.json"
fi

# Function to reinstall a marketplace and all its plugins
reinstall_marketplace() {
    local marketplace_name="$1"
    local marketplace_repo="$2"
    local marketplace_dir="$SCRIPT_DIR/plugins/marketplaces/$marketplace_name"

    echo "Reinstalling marketplace: $marketplace_name"
    claude plugin marketplace remove "$marketplace_name"
    claude plugin marketplace add "$marketplace_repo"

    if [ -d "$marketplace_dir" ]; then
        echo "Installing plugins from $marketplace_name..."
        for plugin_dir in "$marketplace_dir"/*/; do
            local plugin_name=$(basename "$plugin_dir")
            # Skip hidden directories (like .git, .claude-plugin)
            if [[ "$plugin_name" != .* ]]; then
                echo "Installing: $plugin_name@$marketplace_name"
                claude plugin install "$plugin_name@$marketplace_name"
            fi
        done
    else
        echo "Error: Marketplace directory not found at $marketplace_dir"
        return 1
    fi
}

# Reinstall marketplaces
reinstall_marketplace "mwguerra-marketplace" "mwguerra/claude-code-plugins"

# Make all .sh files executable in plugins directory
echo "Making .sh files executable in plugins directory..."
find "$SCRIPT_DIR/plugins" -name "*.sh" -type f -exec chmod +x {} \;
echo "Done setting permissions."

echo "Done!"
```

**Usage:**

```bash
# Make executable
chmod +x ~/.claude/reinstall_marketplace.sh

# Run to reinstall all plugins
~/.claude/reinstall_marketplace.sh
```

## Requirements

- Claude Code

## License

MIT
