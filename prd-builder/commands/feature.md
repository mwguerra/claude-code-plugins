---
description: Create a feature-focused PRD with lighter interview process optimized for new features within existing products
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
argument-hint: "[feature description]"
---

# Feature PRD Command

Conduct a focused interview to document a new feature within an existing product context.

## Differences from Full PRD

| Aspect | Full PRD | Feature PRD |
|--------|----------|-------------|
| Interview rounds | 10-15 | 5-8 |
| Business & Value | Full coverage | Minimal (unless monetized) |
| Problem & Context | Comprehensive | Brief (product context assumed) |
| Technical | Full | Focus on feature scope |
| UX & Design | Full | As needed |

## Execution Flow

### 1. Initialize Session

Check for existing session:

```bash
cat .taskmanager/prd-state.json 2>/dev/null
```

Handle resume/fresh start as with `/prd-builder:prd`.

### 2. Capture Feature Description

If argument provided, use it. Otherwise ask:

"What feature would you like to document? Describe what it should do."

### 3. Generate Slug

Create kebab-case slug prefixed with feature context:
- Example: "Add dark mode toggle" → `dark-mode-toggle`
- Example: "Export to PDF button" → `export-pdf`

### 4. Create State File

```json
{
  "sessionId": "<uuid>",
  "prdType": "feature",
  "slug": "<generated-slug>",
  "startedAt": "<ISO timestamp>",
  "lastUpdatedAt": "<ISO timestamp>",
  "currentCategory": "problem-context",
  "completedCategories": [],
  "answers": {},
  "initialPrompt": "<user's description>"
}
```

### 5. Conduct Focused Interview

Load `prd-interview` skill. Work through categories with feature-appropriate depth:

**1. Problem & Context (1 round)**
- What user need does this address?
- How do users currently handle this?

**2. Users & Customers (1 round)**
- Who benefits most from this feature?
- What's the expected usage frequency?

**3. Solution & Features (2 rounds)**
- Core functionality details
- Edge cases and variations
- What's explicitly out of scope?

**4. Technical Implementation (2 rounds)**
- How does this integrate with existing architecture?
- What components need modification?
- Any new dependencies?

**5. Business & Value (1 round - optional)**
- Skip if internal feature
- Ask only if feature has pricing/monetization implications

**6. UX & Design (1-2 rounds)**
- User flow for the feature
- UI placement and interaction
- Skip for backend-only features

**7. Risks & Concerns (1 round)**
- Technical risks
- Dependencies on other work
- Breaking changes?

**8. Testing & Quality (1 round)**
- Acceptance criteria
- Key test scenarios
- Performance considerations

### 6. Generate Feature PRD

Create simplified PRD document:
- Shorter executive summary
- Focus on feature details, not product overview
- Include integration points with existing system
- Mermaid diagrams for feature flow

Save to: `docs/prd/prd-{slug}.md`

### 7. TaskManager Integration

Same as `/prd-builder:prd`:
- Offer to generate tasks
- Parse feature into implementation subtasks
- Optionally start autonomous execution

## Interview Guidelines

- Maximum 2-3 questions per round
- Skip Business & Value for internal features
- Assume product context exists
- Focus on integration with existing system
- Lighter documentation, same rigor on technical details

## Output

- PRD file: `docs/prd/prd-{slug}.md`
- Focused on feature scope within existing product
- Ready for taskmanager integration
