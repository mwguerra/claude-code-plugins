---
name: prd
description: Start a comprehensive PRD interview to transform an idea into a complete Product Requirements Document
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - Bash
  - Task
  - Skill
argument-hint: "[initial idea or prompt]"
---

# PRD Interview Command

Conduct a comprehensive interview to create a Product Requirements Document from a rough idea.

## Execution Flow

### 1. Initialize Session

Check for existing session state:

```bash
cat .taskmanager/prd-state.json 2>/dev/null
```

If state exists with incomplete session, ask:
- "Resume previous PRD session for '{slug}'?"
- Options: Resume, Start fresh

### 2. Capture Initial Idea

If argument provided, use it as the initial prompt. Otherwise ask:

"What product or major feature would you like to document? Describe the core idea in your own words."

### 3. Generate Slug

From the initial idea, generate a kebab-case slug for the PRD filename:
- Example: "User authentication system" → `user-authentication`
- Example: "Dashboard for sales metrics" → `sales-dashboard`

### 4. Create State File

Ensure `.taskmanager/` directory exists, then create state:

```json
{
  "sessionId": "<uuid>",
  "prdType": "product",
  "slug": "<generated-slug>",
  "startedAt": "<ISO timestamp>",
  "lastUpdatedAt": "<ISO timestamp>",
  "currentCategory": "problem-context",
  "completedCategories": [],
  "answers": {},
  "initialPrompt": "<user's description>"
}
```

### 5. Conduct Interview

Load the `prd-interview` skill for question frameworks.

Work through all 8 categories in order:
1. Problem & Context
2. Users & Customers
3. Solution & Features
4. Technical Implementation
5. Business & Value
6. UX & Design
7. Risks & Concerns
8. Testing & Quality

For each category:
- Use AskUserQuestion with 2-4 questions per round
- Apply adaptive branching (skip irrelevant questions)
- Save answers to state file after each round
- Summarize category findings before moving to next

### 6. Generate PRD Document

After completing all categories:

1. Create output directory: `mkdir -p docs/prd`
2. Read template from skill: `$CLAUDE_PLUGIN_ROOT/skills/prd-interview/templates/prd-template.md`
3. Fill template with interview answers
4. Generate appropriate Mermaid diagrams
5. Write to: `docs/prd/prd-{slug}.md`

### 7. TaskManager Integration

After PRD is saved, ask:

"PRD saved to `docs/prd/prd-{slug}.md`. Would you like to generate tasks from this PRD?"

Options:
- Yes - generate and start tasks
- Yes - generate tasks only
- No - I'll handle tasks manually

If generating tasks:
- Parse features from the PRD
- Create hierarchical task structure (parent per feature, children for implementation)
- Use `/taskmanager:plan docs/prd/prd-{slug}.md`

If starting tasks:
- After plan is created, invoke `/taskmanager:run-tasks`

### 8. Cleanup

After successful PRD generation:
- Archive or delete the state file
- Confirm completion to user

## Interview Guidelines

- Ask 2-4 questions per AskUserQuestion call
- Use multiSelect for non-mutually-exclusive choices
- Provide concrete options when possible
- Keep headers under 12 characters
- Summarize after each category
- Save state after each question round

## Error Handling

If user wants to stop mid-interview:
- Save current state
- Inform user they can resume with `/prd` later

If state file is corrupted:
- Offer to start fresh
- Back up corrupted state first

## Output

- PRD file: `docs/prd/prd-{slug}.md`
- State file: `.taskmanager/prd-state.json` (during interview)
- Tasks: Created via taskmanager if requested
