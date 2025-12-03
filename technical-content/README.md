# Technical Content Plugin

Create high-quality technical articles with full research, documentation, and quality checks.

## Commands

```
/technical-content:article <topic>    # Create a new article
/technical-content:voice setup        # Create voice profile
/technical-content:voice show         # Show current profile
```

## Skills

- **technical-content** - Full article creation workflow (auto-invoked)
- **timestamp** - Cross-platform timestamp generation

## What It Does

1. **Creates article folder structure** with templates for research, drafts, and reviews
2. **Manages voice profile** to ensure consistent writing tone
3. **Guides you through the process**:
   - Planning (audience, type, outline)
   - Research (sources, fact verification)
   - Drafting (following voice profile)
   - Review (quality checklists)
   - Finalization

## Folder Structure Created

```
docs/articles/YYYY_MM_DD_<slug>/
├── 00_context/           # Voice, history
├── 01_planning/          # Classification, outline
├── 02_research/          # Sources, notes, code
├── 03_drafts/            # Draft versions
├── 04_review/            # Checklists
├── 05_assets/            # Images
└── <slug>.md             # FINAL ARTICLE
```

## Requirements

- Bun runtime (for scripts)
