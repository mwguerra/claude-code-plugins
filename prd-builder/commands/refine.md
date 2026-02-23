---
description: Analyze and enhance an existing PRD by identifying gaps and asking targeted questions to fill weak areas
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
argument-hint: "<path-to-existing-prd>"
---

# Refine PRD Command

Analyze an existing PRD document, identify weak or missing sections, and conduct targeted interviews to fill the gaps.

## Execution Flow

### 1. Locate PRD to Refine

If argument provided, use it as path. Otherwise:

```bash
ls docs/prd/*.md 2>/dev/null
```

If multiple PRDs found, ask user to select:
- "Which PRD would you like to refine?"
- List available PRDs as options

If no PRDs found:
- "No existing PRDs found in docs/prd/. Would you like to create a new one with /prd-builder:prd instead?"

### 2. Read and Analyze PRD

Read the entire PRD file and analyze each section for:

**Completeness Checklist:**

| Section | Check For |
|---------|-----------|
| Executive Summary | Clear, concise, covers what/who/why |
| Problem Statement | Specific problem, affected users, current state |
| Users & Personas | Defined personas with attributes |
| Solution Overview | Clear approach, differentiators |
| Features | Detailed requirements, acceptance criteria |
| Technical Architecture | Diagrams, stack decisions, integrations |
| User Experience | Flows, wireframes, accessibility |
| Business Case | Value prop, metrics (if applicable) |
| Risks | Identified risks with mitigations |
| Testing | Strategy, coverage, edge cases |
| Timeline | Milestones (if applicable) |

**Quality Indicators:**

- **Weak**: Section exists but lacks detail
- **Missing**: Section not present or placeholder only
- **Strong**: Section is comprehensive
- **N/A**: Section not applicable for this PRD type

### 3. Generate Gap Analysis

Create a summary of findings:

```markdown
## PRD Gap Analysis: {PRD Title}

### Strong Sections ✓
- {Section}: {brief note on strength}

### Needs Improvement ⚠
- {Section}: {what's missing or weak}

### Missing Sections ✗
- {Section}: {why it's important}
```

Present this analysis to user and ask:
- "I've identified these gaps in your PRD. Would you like to address them now?"
- Options: Yes - all gaps, Yes - select which, No - keep as is

### 4. Conduct Targeted Interview

For each gap identified (in priority order):

Load `prd-interview` skill for question frameworks.

**For weak sections:**
- Ask 1-2 focused questions to strengthen
- Reference existing content as context
- Don't re-ask what's already answered

**For missing sections:**
- Ask 2-3 questions to build the section
- Use appropriate question bank from skill

**Interview Order Priority:**
1. Problem & Context (foundation for everything)
2. Features & Requirements (core deliverables)
3. Technical Implementation (execution clarity)
4. Testing & Quality (verification)
5. Risks & Concerns (risk awareness)
6. Users & Customers (if weak)
7. Business & Value (if applicable)
8. UX & Design (if UI-related)

### 5. Update PRD Document

After gathering new information:

1. Read current PRD content
2. Merge new answers into appropriate sections
3. Preserve existing content that's adequate
4. Add new sections if completely missing
5. Update Mermaid diagrams if technical details changed
6. Update "Last Updated" timestamp

Use Edit tool to make targeted changes, not full rewrites.

### 6. Present Changes

After updating, show summary:
- "I've updated your PRD with the following improvements:"
- List sections modified
- List sections added
- Offer to show diff or read updated sections

### 7. TaskManager Integration

If PRD now has better-defined features, ask:
- "The refined PRD has clearer requirements. Would you like to regenerate tasks?"
- Options: Yes - regenerate, No - keep existing

## Gap Detection Heuristics

**Problem Statement is weak if:**
- Less than 3 sentences
- No mention of who has the problem
- No current state/workaround described

**Features are weak if:**
- No acceptance criteria listed
- Features are just bullet points without detail
- No priority indicators (P0/P1/P2)

**Technical Architecture is weak if:**
- No diagram present
- No stack decisions documented
- No integration points listed

**Testing Strategy is weak if:**
- No test types specified
- No coverage targets
- No edge cases mentioned

**Risks are weak if:**
- Fewer than 3 risks identified
- No mitigation strategies
- No probability/impact assessment

## Interview Guidelines

- Only ask about gaps, not already-documented areas
- Reference existing content when asking follow-ups
- Keep refinement focused (don't expand scope)
- Preserve user's original voice and decisions
- Maximum 5-6 question rounds for refinement

## Output

- Updated PRD file at original location
- Gaps filled with new information
- Existing content preserved
- Ready for task regeneration if needed
