# PRD Builder Plugin

An interactive Product Requirements Document (PRD) builder for Claude Code that transforms rough ideas into comprehensive, actionable plans through structured interviews.

## Features

- **Deep Interview Process**: 8 comprehensive categories covering all aspects of product/feature planning
- **Smart Branching**: Adaptive questions based on previous answers
- **Multiple PRD Types**: Full product, feature, and bugfix documentation
- **Gap Analysis**: Refine existing PRDs by identifying and filling weak areas
- **Session Persistence**: Save progress and continue long interviews later
- **TaskManager Integration**: Auto-generate hierarchical tasks from completed PRDs
- **Mermaid Diagrams**: Visual architecture and flow diagrams

## Commands

| Command | Description |
|---------|-------------|
| `/prd-builder:prd` | Start a comprehensive product PRD interview |
| `/prd-builder:feature` | Create a feature-focused PRD (lighter weight) |
| `/prd-builder:bugfix` | Document a bug fix with problem analysis |
| `/prd-builder:refine` | Analyze and enhance an existing PRD |

## Interview Categories

1. **Problem & Context** - What problem exists, pain points, why now
2. **Users & Customers** - Target users, personas, customer segments
3. **Solution & Features** - Proposed solution, feature list, MVP scope
4. **Technical Implementation** - Architecture, stack, integrations
5. **Business & Value** - Value proposition, pricing, ROI
6. **UX & Design** - User flows, wireframes, accessibility
7. **Risks & Concerns** - Technical risks, dependencies, assumptions
8. **Testing & Quality** - Test strategies, acceptance criteria, edge cases

## Output

- PRD files saved to: `docs/prd/prd-{slug}.md`
- Session state saved to: `.taskmanager/prd-state.json`

## Usage

```bash
# Start a new product PRD
/prd

# Create a feature PRD
/prd-builder:feature

# Document a bug fix
/prd-builder:bugfix

# Improve an existing PRD
/prd-builder:refine docs/prd/prd-user-auth.md
```

## TaskManager Integration

After completing a PRD, you'll be asked if you want to generate tasks. The plugin will:

1. Parse all features from the PRD
2. Create hierarchical tasks (parent features with implementation subtasks)
3. Optionally start executing tasks autonomously

## Proactive Agent

The plugin includes a `prd-interviewer` agent that triggers automatically when you describe product ideas:

```
"I want to build a user authentication system"
→ Agent offers to conduct PRD interview

"I'm thinking about adding a dashboard to track metrics"
→ Agent suggests structured discovery before implementation

"Before we start coding, let's document the requirements"
→ Agent launches full PRD interview
```

## Session Persistence

Long interviews can be resumed:

1. State is saved to `.taskmanager/prd-state.json` after each question round
2. If you stop mid-interview, running `/prd-builder:prd` again offers to resume
3. Choose "Start fresh" to begin a new interview instead

## PRD Document Structure

Generated PRDs include:

- Executive Summary
- Problem Statement
- Users & Personas (with tables)
- Solution Overview
- Features & Requirements (P0/P1/P2 with acceptance criteria)
- Technical Architecture (with Mermaid diagrams)
- User Experience (flows, accessibility)
- Business Case (if applicable)
- Risks & Mitigations
- Testing Strategy
- Timeline & Milestones
- Open Questions

## Installation

Add to your Claude Code plugins directory or use `--plugin-dir` flag:

```bash
claude --plugin-dir /path/to/prd-builder
```

## Plugin Structure

```
prd-builder/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── prd-interviewer.md
├── commands/
│   ├── prd.md
│   ├── feature.md
│   ├── bugfix.md
│   └── refine.md
├── skills/
│   └── prd-interview/
│       ├── SKILL.md
│       ├── references/
│       │   └── question-bank.md
│       └── templates/
│           └── prd-template.md
└── README.md
```
