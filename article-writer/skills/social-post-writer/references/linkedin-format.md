# LinkedIn Post Format Reference

## Constraints

| Parameter | Value |
|-----------|-------|
| **Word count** | 200-1300 words (default target: 600) |
| **Hard max** | 1300 words |
| **Hashtags** | 3-5, placed at end |
| **Tone shift** | Formality +1 from base |
| **CTA** | Required |
| **Companion project** | No (link to blog's if derived) |

## Structure Template

```
[HOOK - 2-3 lines that stop the scroll]

[BODY - Main content organized in short paragraphs]
- Use line breaks between paragraphs
- Keep paragraphs to 2-3 sentences max
- Use bullet points for lists
- Bold or CAPS for emphasis (sparingly)

[CTA - Call to action]
- Ask a question
- Invite discussion
- Suggest next step

[HASHTAGS]
#Tag1 #Tag2 #Tag3 #Tag4 #Tag5
```

## Hook Patterns

1. **Contrarian opener**: "Everyone says X. They're wrong."
2. **Story opener**: "Last week, I [specific event]..."
3. **Data opener**: "X% of developers still [surprising stat]."
4. **Question opener**: "What if [provocative question]?"
5. **Bold claim**: "[Strong statement]. Here's why."

## Body Guidelines

- **Paragraph length**: 1-3 sentences maximum
- **Line breaks**: Double line break between paragraphs
- **Lists**: Use • or numbered lists for scanability
- **Length**: Most engagement at 600-800 words
- **Personal anecdotes**: Include at least one
- **Data/examples**: Support claims with specifics

## CTA Patterns

- "What's your experience with [topic]? Drop a comment."
- "If this resonated, repost to help others."
- "Follow for more [topic area] insights."
- "Link in comments for the full deep-dive."

## Output File

```
{slug}.linkedin.{lang}.md
```

### Frontmatter

```yaml
---
platform: linkedin
author: {author_id}
derived_from: {source_id or null}
created_at: {ISO timestamp}
word_count: {count}
hashtags: [tag1, tag2, tag3]
---
```

## Example

```markdown
---
platform: linkedin
author: mwguerra
created_at: 2026-02-17T10:00:00Z
word_count: 620
hashtags: [Laravel, RateLimiting, WebDev, PHP, BackendDev]
---

Your API has no rate limiting.

That means one angry script can take down your entire production server. I've seen it happen — twice.

Here's what I learned building rate limiting for a Laravel API serving 50k requests/day:

**1. Start with middleware, not packages**

Laravel ships with ThrottleRequests middleware. Most devs skip it because they think they need Redis. You don't.

The default file driver works fine up to ~10k RPM. Only switch to Redis when you actually hit that ceiling.

**2. Think in tiers, not global limits**

Don't apply one rate limit to everything. Your login endpoint needs different limits than your search endpoint.

• Authentication: 5 attempts/minute
• API reads: 60 requests/minute
• API writes: 20 requests/minute

**3. Return useful headers**

Always include X-RateLimit-Remaining and Retry-After. Your API consumers will thank you.

The biggest mistake? Waiting until you're already under attack. Rate limiting is like insurance — boring until you need it.

What rate limiting strategy are you using? I'd love to hear what's working for your team.

#Laravel #RateLimiting #WebDev #PHP #BackendDev
```
