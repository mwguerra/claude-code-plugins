#!/usr/bin/env bun
/**
 * Initialize article-writer in the current project
 * Creates .article_writer folder with schemas and empty files
 * Completes missing files without deleting existing data
 * 
 * Usage: bun run init.ts [options]
 * 
 * Options:
 *   --check          Only check what's missing, don't create
 *   --author <json>  Create author from JSON string
 */

import { mkdir, copyFile, writeFile, readFile, stat } from "fs/promises";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = process.env.CLAUDE_PLUGIN_ROOT || dirname(__dirname);

// Project root - use CLAUDE_PROJECT_DIR when available, fall back to process.cwd()
const PROJECT_ROOT = process.env.CLAUDE_PROJECT_DIR || process.cwd();

const CONFIG_DIR = join(PROJECT_ROOT, ".article_writer");
const SCHEMAS_DIR = join(CONFIG_DIR, "schemas");
const CONTENT_DIR = join(PROJECT_ROOT, "content/articles");
const DOCS_DIR = join(PROJECT_ROOT, "docs");

interface InitStatus {
  configDirExists: boolean;
  schemasDirExists: boolean;
  contentDirExists: boolean;
  docsDirExists: boolean;
  tasksSchemaExists: boolean;
  authorsSchemaExists: boolean;
  settingsSchemaExists: boolean;
  tasksFileExists: boolean;
  authorsFileExists: boolean;
  settingsFileExists: boolean;
  missingItems: string[];
  existingItems: string[];
}

async function exists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

async function checkStatus(): Promise<InitStatus> {
  const status: InitStatus = {
    configDirExists: await exists(CONFIG_DIR),
    schemasDirExists: await exists(SCHEMAS_DIR),
    contentDirExists: await exists(CONTENT_DIR),
    docsDirExists: await exists(DOCS_DIR),
    tasksSchemaExists: await exists(join(SCHEMAS_DIR, "article-tasks.schema.json")),
    authorsSchemaExists: await exists(join(SCHEMAS_DIR, "authors.schema.json")),
    settingsSchemaExists: await exists(join(SCHEMAS_DIR, "settings.schema.json")),
    tasksFileExists: await exists(join(CONFIG_DIR, "article_tasks.json")),
    authorsFileExists: await exists(join(CONFIG_DIR, "authors.json")),
    settingsFileExists: await exists(join(CONFIG_DIR, "settings.json")),
    missingItems: [],
    existingItems: []
  };

  // Track what's missing vs existing
  if (!status.configDirExists) status.missingItems.push(CONFIG_DIR);
  else status.existingItems.push(CONFIG_DIR);

  if (!status.schemasDirExists) status.missingItems.push(SCHEMAS_DIR);
  else status.existingItems.push(SCHEMAS_DIR);

  if (!status.contentDirExists) status.missingItems.push(CONTENT_DIR);
  else status.existingItems.push(CONTENT_DIR);

  if (!status.docsDirExists) status.missingItems.push(DOCS_DIR);
  else status.existingItems.push(DOCS_DIR);

  if (!status.tasksSchemaExists) status.missingItems.push("schemas/article-tasks.schema.json");
  else status.existingItems.push("schemas/article-tasks.schema.json");

  if (!status.authorsSchemaExists) status.missingItems.push("schemas/authors.schema.json");
  else status.existingItems.push("schemas/authors.schema.json");

  if (!status.settingsSchemaExists) status.missingItems.push("schemas/settings.schema.json");
  else status.existingItems.push("schemas/settings.schema.json");

  if (!status.tasksFileExists) status.missingItems.push("article_tasks.json");
  else status.existingItems.push("article_tasks.json");

  if (!status.authorsFileExists) status.missingItems.push("authors.json");
  else status.existingItems.push("authors.json");

  if (!status.settingsFileExists) status.missingItems.push("settings.json");
  else status.existingItems.push("settings.json");

  return status;
}

async function copySchema(filename: string, destDir: string): Promise<boolean> {
  const source = join(PLUGIN_ROOT, "schemas", filename);
  const dest = join(destDir, filename);
  
  try {
    await copyFile(source, dest);
    return true;
  } catch (e) {
    // Try to read from plugin schemas directory
    try {
      const content = await readFile(source, "utf-8");
      await writeFile(dest, content);
      return true;
    } catch {
      console.error(`   ✗ Could not copy ${filename}`);
      return false;
    }
  }
}

async function createEmptyTasks(): Promise<void> {
  const emptyTasks = {
    $schema: "./schemas/article-tasks.schema.json",
    metadata: {
      version: "1.0.0",
      last_updated: new Date().toISOString(),
      total_count: 0
    },
    articles: []
  };
  await writeFile(
    join(CONFIG_DIR, "article_tasks.json"), 
    JSON.stringify(emptyTasks, null, 2)
  );
}

async function createEmptyAuthors(): Promise<void> {
  const emptyAuthors = {
    $schema: "./schemas/authors.schema.json",
    metadata: {
      version: "1.0.0",
      last_updated: new Date().toISOString()
    },
    authors: []
  };
  await writeFile(
    join(CONFIG_DIR, "authors.json"), 
    JSON.stringify(emptyAuthors, null, 2)
  );
}

async function createDefaultSettings(): Promise<void> {
  const defaultSettings = {
    $schema: "./schemas/settings.schema.json",
    example_defaults: {
      code: {
        technologies: ["Laravel 12", "Pest 4", "SQLite"],
        has_tests: true,
        path: "code/",
        scaffold_command: "composer create-project laravel/laravel code --prefer-dist",
        post_scaffold: [
          "cd code",
          "composer require pestphp/pest pestphp/pest-plugin-laravel --dev --with-all-dependencies",
          "php artisan pest:install",
          "sed -i 's/DB_CONNECTION=.*/DB_CONNECTION=sqlite/' .env",
          "touch database/database.sqlite"
        ],
        verification: {
          install_command: "composer install",
          setup_commands: [
            "cp .env.example .env",
            "php artisan key:generate",
            "touch database/database.sqlite",
            "php artisan migrate"
          ],
          run_command: "php artisan serve",
          test_command: "php artisan test",
          success_indicators: {
            install: "vendor/ directory exists",
            run: "Server starts on localhost:8000",
            test: "Tests: X passed (0 failures)"
          }
        },
        env_setup: {
          DB_CONNECTION: "sqlite",
          DB_DATABASE: "database/database.sqlite"
        },
        required_structure: [
          "app/",
          "bootstrap/",
          "config/",
          "database/migrations/",
          "database/seeders/",
          "public/",
          "resources/views/",
          "routes/",
          "storage/",
          "tests/Feature/",
          "tests/Unit/",
          ".env.example",
          "artisan",
          "composer.json",
          "README.md"
        ],
        notes: "Create COMPLETE Laravel applications. MUST run verification commands and confirm all pass before marking complete."
      },
      node: {
        technologies: ["Node.js", "Jest"],
        has_tests: true,
        path: "code/",
        scaffold_command: "npm init -y",
        post_scaffold: [
          "npm install express",
          "npm install --save-dev jest"
        ],
        verification: {
          install_command: "npm install",
          setup_commands: [],
          run_command: "npm start",
          test_command: "npm test",
          success_indicators: {
            install: "node_modules/ directory exists",
            run: "Server starts without errors",
            test: "Tests passed"
          }
        },
        required_structure: [
          "src/",
          "tests/",
          "package.json",
          "README.md"
        ],
        notes: "Create COMPLETE Node.js applications. MUST run verification commands and confirm all pass."
      },
      python: {
        technologies: ["Python", "pytest"],
        has_tests: true,
        path: "code/",
        scaffold_command: "python -m venv venv",
        post_scaffold: [
          "source venv/bin/activate",
          "pip install pytest"
        ],
        verification: {
          install_command: "pip install -r requirements.txt",
          setup_commands: ["source venv/bin/activate"],
          run_command: "python src/main.py",
          test_command: "pytest",
          success_indicators: {
            install: "All packages installed",
            run: "Script executes without errors",
            test: "X passed"
          }
        },
        required_structure: [
          "src/",
          "tests/",
          "requirements.txt",
          "README.md"
        ],
        notes: "Create COMPLETE Python applications. MUST run verification commands and confirm all pass."
      },
      document: {
        technologies: ["Markdown"],
        has_tests: false,
        path: "code/",
        verification: {
          install_command: null,
          run_command: null,
          test_command: null,
          manual_checks: [
            "All sections are complete",
            "Placeholders are clearly marked",
            "At least one filled example exists"
          ]
        },
        required_structure: [
          "templates/",
          "examples/",
          "README.md"
        ],
        notes: "Include both empty templates AND filled examples. Documents must be complete and usable."
      },
      diagram: {
        technologies: ["Mermaid"],
        has_tests: false,
        path: "code/",
        verification: {
          install_command: null,
          run_command: null,
          test_command: null,
          manual_checks: [
            "Diagrams render correctly in Mermaid preview",
            "All components are labeled",
            "Comments explain complex parts"
          ]
        },
        required_structure: [
          "diagrams/",
          "README.md"
        ],
        notes: "Diagrams must be valid Mermaid syntax and render correctly."
      },
      config: {
        technologies: ["Docker", "Docker Compose", "YAML"],
        has_tests: false,
        path: "code/",
        verification: {
          install_command: null,
          setup_commands: ["cp .env.example .env"],
          run_command: "docker-compose up -d",
          test_command: "docker-compose ps",
          success_indicators: {
            run: "Containers start successfully",
            test: "All containers show 'Up' status"
          }
        },
        required_structure: [
          "docker/",
          "docker-compose.yml",
          ".env.example",
          "README.md"
        ],
        notes: "Config examples must be self-contained and runnable with docker-compose up."
      },
      script: {
        technologies: ["Bash", "Shell"],
        has_tests: false,
        path: "code/",
        verification: {
          install_command: null,
          setup_commands: ["chmod +x scripts/*.sh"],
          run_command: "./scripts/main.sh --help",
          test_command: null,
          success_indicators: {
            run: "Script executes and shows help/output"
          }
        },
        required_structure: [
          "scripts/",
          "lib/",
          "README.md"
        ],
        notes: "Scripts must be executable, have proper shebangs, and include error handling."
      },
      spreadsheet: {
        technologies: ["Excel", "CSV"],
        has_tests: false,
        path: "code/",
        verification: {
          install_command: null,
          run_command: null,
          test_command: null,
          manual_checks: [
            "Spreadsheet opens without errors",
            "Formulas calculate correctly",
            "Sample data is present"
          ]
        },
        required_structure: [
          "spreadsheets/",
          "csv/",
          "README.md"
        ],
        notes: "Include formulas and formatting. Provide CSV versions for portability."
      },
      template: {
        technologies: ["Markdown", "YAML"],
        has_tests: false,
        path: "code/",
        verification: {
          install_command: null,
          run_command: null,
          test_command: null,
          manual_checks: [
            "Templates have clear placeholders",
            "At least one generated example exists",
            "Instructions are complete"
          ]
        },
        required_structure: [
          "templates/",
          "generated/",
          "README.md"
        ],
        notes: "Templates should have clear placeholders and instructions."
      },
      dataset: {
        technologies: ["JSON", "CSV", "SQL"],
        has_tests: false,
        path: "code/",
        verification: {
          install_command: null,
          run_command: null,
          test_command: null,
          manual_checks: [
            "Data files are valid (JSON parses, CSV has headers)",
            "Schema matches data",
            "Import instructions work"
          ]
        },
        required_structure: [
          "data/",
          "schemas/",
          "README.md"
        ],
        notes: "Include schema definitions alongside sample data."
      },
      other: {
        technologies: [],
        has_tests: false,
        path: "code/",
        verification: {
          install_command: null,
          run_command: null,
          test_command: null,
          manual_checks: [
            "Example is complete and self-contained",
            "README explains usage clearly"
          ]
        },
        required_structure: [
          "README.md"
        ],
        notes: "Document thoroughly as the example type may not be obvious."
      }
    },
    metadata: {
      version: "1.0.0",
      last_updated: new Date().toISOString()
    }
  };
  await writeFile(
    join(CONFIG_DIR, "settings.json"),
    JSON.stringify(defaultSettings, null, 2)
  );
}

async function addAuthor(authorJson: string): Promise<void> {
  const authorsPath = join(CONFIG_DIR, "authors.json");
  
  let authorsData: any;
  try {
    const content = await readFile(authorsPath, "utf-8");
    authorsData = JSON.parse(content);
  } catch {
    authorsData = {
      $schema: "./schemas/authors.schema.json",
      metadata: { version: "1.0.0", last_updated: new Date().toISOString() },
      authors: []
    };
  }

  const newAuthor = JSON.parse(authorJson);
  
  // Check if author with same ID exists
  const existingIndex = authorsData.authors.findIndex((a: any) => a.id === newAuthor.id);
  if (existingIndex >= 0) {
    authorsData.authors[existingIndex] = newAuthor;
    console.log(`✅ Updated existing author: ${newAuthor.name} (${newAuthor.id})`);
  } else {
    authorsData.authors.push(newAuthor);
    console.log(`✅ Added new author: ${newAuthor.name} (${newAuthor.id})`);
  }

  authorsData.metadata.last_updated = new Date().toISOString();
  await writeFile(authorsPath, JSON.stringify(authorsData, null, 2));
}

async function init(checkOnly: boolean = false): Promise<void> {
  console.log("\n🚀 Article Writer Initialization\n");

  const status = await checkStatus();

  // Report existing items
  if (status.existingItems.length > 0) {
    console.log("✅ Already exists (will not modify):");
    for (const item of status.existingItems) {
      console.log(`   • ${item}`);
    }
    console.log("");
  }

  // Report missing items
  if (status.missingItems.length === 0) {
    console.log("✅ Article Writer is fully initialized!\n");
    
    // Check if authors.json has any authors
    try {
      const authorsContent = await readFile(join(CONFIG_DIR, "authors.json"), "utf-8");
      const authors = JSON.parse(authorsContent);
      if (!authors.authors || authors.authors.length === 0) {
        console.log("⚠️  No authors configured yet.");
        console.log("   Run /article-writer:author add to create your first author.\n");
      } else {
        console.log(`📝 ${authors.authors.length} author(s) configured.`);
        console.log("   Run /article-writer:author list to see them.\n");
      }
    } catch {}
    
    return;
  }

  console.log("📋 Missing items to create:");
  for (const item of status.missingItems) {
    console.log(`   • ${item}`);
  }
  console.log("");

  if (checkOnly) {
    console.log("Run without --check to create missing items.\n");
    return;
  }

  // Create missing directories
  console.log("📁 Creating directories...");
  if (!status.configDirExists || !status.schemasDirExists) {
    await mkdir(SCHEMAS_DIR, { recursive: true });
    console.log(`   ✓ ${SCHEMAS_DIR}/`);
  }
  if (!status.contentDirExists) {
    await mkdir(CONTENT_DIR, { recursive: true });
    console.log(`   ✓ ${CONTENT_DIR}/`);
  }
  if (!status.docsDirExists) {
    await mkdir(DOCS_DIR, { recursive: true });
    console.log(`   ✓ ${DOCS_DIR}/`);
  }

  // Copy schema files
  console.log("\n📋 Setting up schema files...");
  if (!status.tasksSchemaExists) {
    if (await copySchema("article-tasks.schema.json", SCHEMAS_DIR)) {
      console.log("   ✓ article-tasks.schema.json");
    }
  }
  if (!status.authorsSchemaExists) {
    if (await copySchema("authors.schema.json", SCHEMAS_DIR)) {
      console.log("   ✓ authors.schema.json");
    }
  }
  if (!status.settingsSchemaExists) {
    if (await copySchema("settings.schema.json", SCHEMAS_DIR)) {
      console.log("   ✓ settings.schema.json");
    }
  }

  // Create empty data files
  console.log("\n📝 Creating data files...");
  if (!status.tasksFileExists) {
    await createEmptyTasks();
    console.log("   ✓ article_tasks.json");
  }
  if (!status.authorsFileExists) {
    await createEmptyAuthors();
    console.log("   ✓ authors.json");
  }
  if (!status.settingsFileExists) {
    await createDefaultSettings();
    console.log("   ✓ settings.json (with example defaults)");
  }

  // Summary
  console.log("\n" + "─".repeat(50));
  console.log("✅ Article Writer initialized!\n");
  console.log("Next step: Create your first author profile:");
  console.log("   /article-writer:author add\n");
}

// Parse arguments
const args = process.argv.slice(2);
const checkOnly = args.includes("--check");
const authorIndex = args.indexOf("--author");

if (authorIndex >= 0 && args[authorIndex + 1]) {
  // Add author mode
  await addAuthor(args[authorIndex + 1]);
} else {
  // Init mode
  await init(checkOnly);
}
