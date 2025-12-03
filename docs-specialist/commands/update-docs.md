# Update Project Documentation

Analyze and update all project documentation, reorganizing it according to best practices while maintaining tool accessibility.

## Task Overview
$ARGUMENTS

## Process

### Phase 1: Documentation Discovery & Analysis
1. **Scan the entire project** for all markdown files:
   - README files at all levels
   - All .md files in the project
   - Document their current locations and purposes

2. **Categorize documentation**:
   - AI/Tool-specific markdown (keep in place for tool access)
   - Project documentation (to be reorganized into /docs)
   - PRD and architecture docs
   - Legacy/outdated documentation

3. **Analyze current code** to identify:
   - Outdated documentation claims
   - Missing documentation
   - Incorrect technical details
   - Architecture changes not reflected in docs

### Phase 2: Code-to-Documentation Validation
1. **Cross-reference each markdown file** against actual codebase:
   - Verify API endpoints, function signatures, component structures
   - Check installation instructions against package.json/requirements
   - Validate configuration examples
   - Confirm architecture diagrams match implementation

2. **Identify discrepancies** and create an update plan:
   - List specific files that need updates
   - Note what needs to change and why
   - Prioritize by impact (critical > important > minor)

### Phase 3: Documentation Reorganization
1. **Create/update docs folder structure**:
   ```
   docs/
   ├── README.md (overview and navigation)
   ├── architecture/
   │   └── prd.md (main architecture doc)
   ├── guides/
   ├── api/
   ├── development/
   └── deployment/
   ```

2. **Preserve AI tool accessibility**:
   - Keep CLAUDE.md, .cursorrules, and similar files in root or .claude/
   - Maintain any agent-specific markdown in their designated folders
   - Document which files stayed in place and why

3. **Move and update files**:
   - Migrate general documentation to appropriate /docs subdirectories
   - Update all internal links and references
   - Ensure no broken links remain

### Phase 4: Content Updates
1. **Update PRD.md** with:
   - Current architecture (verify against codebase)
   - Active features and their implementation status
   - Development processes and workflows
   - Technical decisions and rationale
   - Future roadmap items

2. **Refresh all documentation** to reflect:
   - Current dependencies and versions
   - Accurate setup/installation steps
   - Working code examples
   - Current API structures
   - Updated architecture diagrams

3. **Improve documentation quality**:
   - Add missing sections
   - Remove deprecated content
   - Enhance clarity and organization
   - Include practical examples
   - Add troubleshooting sections where needed

### Phase 5: Validation & Consistency
1. **Verify all documentation**:
   - Test all code examples
   - Validate all links (internal and external)
   - Ensure consistent formatting and style
   - Check for completeness

2. **Create documentation index**:
   - Update main README with documentation structure
   - Add navigation/linking between related docs
   - Create quick-start guides

3. **Generate change summary**:
   - List all files moved/updated
   - Document breaking changes in documentation structure
   - Provide migration guide for team members

## Output Requirements

1. **Updated Documentation Structure**:
   - All docs organized in /docs folder (except AI tool files)
   - Consistent naming conventions
   - Clear hierarchy and navigation

2. **Refreshed Content**:
   - PRD.md fully updated with current architecture
   - All READMEs accurate and current
   - No outdated or incorrect information

3. **Change Report**:
   - Summary of all changes made
   - List of files moved and their new locations
   - Known issues or areas needing manual review

## Special Considerations

- **AI Tool Files**: Keep CLAUDE.md, agent configs, and tool-specific markdown in their original locations
- **Link Updates**: Update ALL internal references when files are moved
- **Backward Compatibility**: Consider creating redirects or notes for moved documentation
- **Version Control**: Commit changes in logical groups (discovery → reorganization → content updates)

## Success Criteria

✓ All documentation reflects current codebase
✓ Docs are organized in logical /docs structure
✓ AI tool files remain accessible in original locations
✓ No broken links or references
✓ PRD.md is comprehensive and current
✓ Team can easily find and understand documentation
