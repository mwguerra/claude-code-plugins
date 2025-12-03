# Validate Documentation

Run comprehensive checks on project documentation to ensure quality, accuracy, and consistency.

## Task
Perform a thorough validation of all project documentation and report issues.

## Validation Areas

### 1. Structure & Organization

**Check:**
- [ ] Documentation follows established hierarchy
- [ ] All docs are in appropriate locations
- [ ] Naming conventions are consistent
- [ ] No orphaned or misplaced files
- [ ] docs/ folder structure is logical

**Commands to run:**
```bash
# List all markdown files and their locations
find . -name "*.md" -type f -not -path "*/node_modules/*" -not -path "*/.git/*"

# Check for docs outside of expected locations
find . -name "*.md" -type f -not -path "./docs/*" -not -path "./.claude/*" -not -path "*/node_modules/*" -not -path "*/.git/*" | grep -v "README.md\|CLAUDE.md\|CONTRIBUTING.md\|LICENSE.md\|CHANGELOG.md"
```

### 2. Link Validation

**Check:**
- [ ] All internal links resolve correctly
- [ ] No broken cross-references
- [ ] External links are accessible (sample check)
- [ ] Anchor links work

**Commands to run:**
```bash
# Find all markdown links
rg "\[.*?\]\(.*?\)" --type md -o

# Find internal links that might be broken
rg "\[.*?\]\([^http].*?\)" --type md

# Find absolute paths (should use relative)
rg "\[.*?\]\(/[^http].*?\)" --type md
```

### 3. Code Examples

**Check:**
- [ ] All code blocks specify language
- [ ] Examples are syntactically valid
- [ ] Import statements are included
- [ ] Examples are up-to-date with current API

**Commands to run:**
```bash
# Find code blocks without language specification
rg "^\`\`\`$" --type md

# Extract code examples for validation
rg -U "^\`\`\`\w+\n.*?\n^\`\`\`" --type md
```

### 4. Technical Accuracy

**Check:**
- [ ] API endpoints match actual implementation
- [ ] Configuration examples are current
- [ ] Dependencies match package files
- [ ] Installation instructions are accurate
- [ ] Architecture docs reflect codebase

**Process:**
1. Extract all technical claims from documentation
2. Cross-reference with actual code
3. Verify against:
   - package.json / requirements.txt / go.mod
   - API route definitions
   - Configuration files
   - Environment variables
4. Flag mismatches

### 5. Completeness

**Check:**
- [ ] README exists and is comprehensive
- [ ] All major features documented
- [ ] API endpoints have documentation
- [ ] Setup/installation covered
- [ ] Common issues addressed
- [ ] Contributing guidelines present

**Areas to verify:**
- Getting started guide
- Architecture overview
- API reference
- Development setup
- Deployment procedures
- Troubleshooting

### 6. Consistency

**Check:**
- [ ] Consistent terminology throughout
- [ ] Uniform formatting style
- [ ] Consistent code block styling
- [ ] Standardized headers structure
- [ ] Uniform file naming

**Commands to run:**
```bash
# Check header consistency
rg "^#{1,6}\s" --type md

# Find different naming patterns
find docs/ -name "*.md" -type f | sed 's/.*\///' | sort

# Check for inconsistent terminology
# (Manual review of common terms)
```

### 7. Maintenance

**Check:**
- [ ] Documentation has recent updates
- [ ] Deprecated content is marked
- [ ] Version information is current
- [ ] Changelog is maintained
- [ ] Last modified dates present

**Commands to run:**
```bash
# Find docs not modified recently
find docs/ -name "*.md" -type f -mtime +180

# Check for "deprecated" markers
rg -i "deprecate|obsolete|outdated" --type md
```

### 8. Accessibility & Clarity

**Check:**
- [ ] Headers form logical hierarchy
- [ ] Lists are properly formatted
- [ ] Tables are readable
- [ ] No excessive nesting
- [ ] Clear navigation

**Review:**
- Readability level appropriate for audience
- Technical jargon is explained
- Examples progress from simple to complex
- Clear next steps provided

### 9. Tool-Specific Files

**Check:**
- [ ] CLAUDE.md in root directory
- [ ] .claude/commands/ populated
- [ ] .claude/agents/ configured
- [ ] Tool configs in correct locations
- [ ] No tool files moved to /docs

**Verify locations:**
```bash
# Check for AI tool files
ls -la CLAUDE.md .cursorrules 2>/dev/null
ls -la .claude/commands/ .claude/agents/ 2>/dev/null
```

### 10. Meta-Documentation

**Check:**
- [ ] Documentation README exists
- [ ] Index/table of contents current
- [ ] Contributing guide for docs
- [ ] Style guide present
- [ ] Templates available

## Validation Report Format

Generate a report with the following structure:

```markdown
# Documentation Validation Report
Date: [Current Date]

## Executive Summary
- Total markdown files: X
- Issues found: Y
- Critical issues: Z
- Recommendations: N

## Critical Issues (Fix Immediately)
1. [Issue description with location and fix]
2. ...

## Important Issues (Fix Soon)
1. [Issue description with location and fix]
2. ...

## Minor Issues (Nice to Fix)
1. [Issue description with location and fix]
2. ...

## Detailed Findings

### Structure & Organization
[Results]

### Link Validation
[Results with list of broken links]

### Code Examples
[Results with invalid examples]

### Technical Accuracy
[Results with mismatches]

### Completeness
[Results with missing documentation]

### Consistency
[Results with inconsistencies]

### Maintenance
[Results with stale content]

### Accessibility & Clarity
[Results with readability issues]

### Tool-Specific Files
[Results with misplaced files]

### Meta-Documentation
[Results]

## Recommendations

### High Priority
1. [Action item]
2. ...

### Medium Priority
1. [Action item]
2. ...

### Low Priority
1. [Action item]
2. ...

## Statistics

- Total files: X
- Files with issues: Y
- Total issues: Z
- Average issues per file: A
- Documentation coverage: X%

## Next Steps

1. [Immediate action]
2. [Follow-up action]
3. [Long-term improvement]
```

## Execution Process

1. **Run all validation checks** systematically
2. **Collect findings** in structured format
3. **Prioritize issues** by impact (critical > important > minor)
4. **Generate report** with actionable recommendations
5. **Suggest fixes** for top issues
6. **Provide commands** to resolve common problems

## Common Quick Fixes

### Fix Code Block Languages
```bash
# Pattern to identify code blocks without language
rg "^\`\`\`$" --type md -l
```

### Update Internal Links
```bash
# Find and update moved file references
# (Requires manual review and correction)
```

### Standardize Headers
```bash
# Ensure consistent header formatting
# (Use consistent ATX style)
```

## Success Criteria

Documentation passes validation when:
- ✅ Zero broken links
- ✅ All code examples valid
- ✅ Technical accuracy confirmed
- ✅ Complete coverage of features
- ✅ Consistent formatting
- ✅ Recent updates (< 6 months old)
- ✅ All tool files in correct locations

## Usage Examples

```bash
# Run full validation
/validate-docs

# Validate specific area
/validate-docs focus on API documentation links

# Quick health check
/validate-docs quick check for broken links and outdated content

# Before release
/validate-docs comprehensive validation for version 2.0 release
```

## Notes

- Use @docs-specialist agent for complex validation tasks
- Run validation before major releases
- Integrate into CI/CD for continuous validation
- Schedule regular documentation audits (quarterly)
- Track validation metrics over time

## After Validation

Once validation is complete:
1. Review the report with the team
2. Create issues for critical problems
3. Assign owners for fixes
4. Set deadlines for important issues
5. Schedule follow-up validation
