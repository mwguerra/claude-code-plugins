# Review Checklists

## Accuracy Checklist

```markdown
# Accuracy Review

## Code
- [ ] All code blocks tested and working
- [ ] Output comments match actual output
- [ ] Versions specified and current
- [ ] No deprecated methods used
- [ ] Error handling included where appropriate

## Facts
- [ ] All claims have source attribution
- [ ] Statistics are current (< 2 years old)
- [ ] Version numbers verified
- [ ] Links are working
- [ ] No outdated information

## Technical Correctness
- [ ] Terminology used correctly
- [ ] No oversimplifications that mislead
- [ ] Edge cases mentioned
- [ ] Security implications noted if relevant
```

## Readability Checklist

```markdown
# Readability Review

## Structure
- [ ] Hook within first 150 words
- [ ] Clear H2 sections (scannable)
- [ ] Logical flow between sections
- [ ] Conclusion summarizes key points

## Paragraphs
- [ ] No paragraph exceeds 4 sentences
- [ ] One idea per paragraph
- [ ] Transition sentences between topics

## Language
- [ ] Technical terms explained on first use
- [ ] Consistent terminology throughout
- [ ] Active voice preferred
- [ ] No jargon without explanation

## Visual
- [ ] Code blocks properly formatted
- [ ] Lists used for 3+ items
- [ ] Tables for comparisons
- [ ] Images have alt text
```

## Voice Checklist

```markdown
# Voice Review

## Tone Match
- [ ] Formality level matches profile
- [ ] Opinion strength matches profile
- [ ] Consistent throughout article

## Vocabulary
- [ ] Uses "allowed" terms freely
- [ ] Explains terms marked "always explain"
- [ ] Avoids forbidden phrases

## Style
- [ ] Signature phrases used naturally
- [ ] No anti-pattern phrases
- [ ] Opinions stated confidently (if opinionated profile)
- [ ] Appropriate hedging (if neutral profile)
```

## SEO Checklist

```markdown
# SEO Review

## Title
- [ ] Under 60 characters
- [ ] Primary keyword included
- [ ] Compelling/clickable

## Meta Description
- [ ] 150-160 characters
- [ ] Includes primary keyword
- [ ] Clear value proposition

## Content
- [ ] Primary keyword in first paragraph
- [ ] Primary keyword in at least one H2
- [ ] Natural keyword density (not stuffed)
- [ ] Internal links to related content
- [ ] External links to authoritative sources

## Technical
- [ ] Proper heading hierarchy (H1 → H2 → H3)
- [ ] Alt text on all images
- [ ] URL slug is clean and keyword-rich
```

## Example Checklist

```markdown
# Example Review

## Completeness (CRITICAL)
- [ ] Example is a FULL project (not snippets)
- [ ] For code: Created via scaffold command (composer create-project, etc.)
- [ ] Example runs without errors
- [ ] README.md explains setup and usage completely
- [ ] All dependencies listed in package file

## Verification (REQUIRED)
- [ ] Fresh clone test: Can be cloned and installed fresh
- [ ] Dependencies install without errors (composer install / npm install)
- [ ] Application starts (php artisan serve / npm start)
- [ ] Can be accessed in browser at documented URL
- [ ] All tests pass (php artisan test / npm test)
- [ ] Marked as verified=true in article_tasks.json

## Quality
- [ ] Well-commented (references article sections)
- [ ] Follows coding standards
- [ ] Uses SQLite for database (no external DB needed)
- [ ] Tests cover main concepts (Pest for PHP)
- [ ] Only article-specific code added to scaffolded project

## Integration
- [ ] Code snippets in article match example files exactly
- [ ] File paths in article are correct
- [ ] Run instructions are accurate and complete
- [ ] Example demonstrates all key concepts from article

## Documentation
- [ ] README has complete setup instructions
- [ ] README lists all requirements
- [ ] Key files are documented with their purpose
- [ ] Article sections referenced in code comments
- [ ] Example purpose is clear
```

## Final Review

```markdown
# Final Review

| Category | Status | Notes |
|----------|--------|-------|
| Accuracy | [ ] | |
| Readability | [ ] | |
| Voice | [ ] | |
| Example | [ ] | |
| SEO | [ ] | |

## Flow Review
- [ ] Narrative flows logically
- [ ] Concepts introduced before use
- [ ] Example appears at the right time
- [ ] Transitions are smooth

## Example Integration
- [ ] Code snippets match example files
- [ ] Example tests pass
- [ ] Run instructions work
- [ ] Example is referenced throughout article

## Pre-Publication
- [ ] Spell check completed
- [ ] Grammar check completed
- [ ] Read aloud for flow
- [ ] Mobile preview checked
- [ ] All images optimized

## Ready for Publication
- [ ] All checklists passed
- [ ] Example runs correctly
- [ ] Author reviewed final draft
- [ ] Scheduled/published
```
