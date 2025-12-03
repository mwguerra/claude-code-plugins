---
description: Create a new technical article with full research and documentation
allowed-tools: Skill(technical-content), Skill(timestamp)
argument-hint: <topic>
---

# Create Article

Start a new technical article on the specified topic.

## Arguments

- `$1`: The topic for the article

## Examples

```
/technical-content:article implementing rate limiting in Laravel
/technical-content:article PostgreSQL query optimization
/technical-content:article should startups use microservices
```

## Process

1. Creates article folder at `docs/articles/YYYY_MM_DD_<slug>/`
2. Loads or creates voice profile at `docs/voice_profile.md`
3. Guides through planning, research, drafting, and review
4. Produces publication-ready article

## Checkpoints

You'll be asked for input at:
- Confirm audience and article type
- Approve outline before research
- Review research findings
- Approve draft sections
- Confirm ready for finalization

## Output

Final article: `docs/articles/YYYY_MM_DD_<slug>/<slug>.md`
