---
description: Remove debug logs, resolved TODOs, fix comments, and development artifacts to prepare code for clean commits
allowed-tools: Read, Edit, Glob, Grep
argument-hint: "[path/to/dir] [--dry-run]"
---

# Code Cleanup Command

Prepare code for public commit by removing development artifacts.

## Usage

```
/cleanup              # Clean current directory
/cleanup path/to/dir  # Clean specific path
```

## What to Remove

### 1. Debug Logging Statements
- `console.log()`, `console.debug()`, `console.warn()` used for debugging
- `print()` statements for debugging (Python)
- `dd()`, `dump()`, `var_dump()` (PHP)
- `Log.d()`, `Log.v()` (Android/Java)
- `NSLog()`, `debugPrint()` (iOS/Swift)
- Keep intentional logging (error handling, production logs)

### 2. Fix-Related Comments
Remove comments containing patterns like:
- `// FIX:`, `// FIXED:`, `// BUGFIX:`
- `// This fixes...`, `// Fixed the issue...`
- `// Previous bug was...`, `// The problem was...`
- `// Workaround for...` (unless still needed)
- `// Hack:` or `// HACK:` (evaluate if still needed)

### 3. Resolved TODO/FIXME Comments
Remove:
- `// TODO: done`, `// TODO (completed)`
- `// FIXME: fixed`, `// FIXME: resolved`
- TODOs with dates that are clearly old and resolved
- Keep active TODOs that are still relevant

### 4. Debugging Code
- Commented-out code blocks from debugging sessions
- Temporary test values or hardcoded debug data
- Debug-only conditionals (`if (DEBUG)`, `if __name__ == '__main__'` test blocks)
- Unused imports added during debugging

### 5. Development Artifacts
- Excessive blank lines (normalize to max 2 consecutive)
- Trailing whitespace
- Debug environment variables in code
- Temporary file references

## Execution Process

1. **Scan** the target directory for code files
2. **Identify** file types and apply language-appropriate cleaning
3. **Preview** changes before applying (show diff)
4. **Confirm** with user before modifying files
5. **Apply** changes and report summary

## File Types to Process

| Extension | Language |
|-----------|----------|
| `.js`, `.jsx`, `.ts`, `.tsx` | JavaScript/TypeScript |
| `.py` | Python |
| `.php` | PHP |
| `.java`, `.kt` | Java/Kotlin |
| `.swift` | Swift |
| `.rb` | Ruby |
| `.go` | Go |
| `.rs` | Rust |
| `.c`, `.cpp`, `.h` | C/C++ |
| `.vue`, `.svelte` | Vue/Svelte |

## Safety Rules

1. **Never auto-delete** - Always show preview and get confirmation
2. **Preserve semantics** - Don't remove comments that explain complex logic
3. **Keep documentation** - JSDoc, docstrings, API docs stay
4. **Respect gitignore** - Skip files in .gitignore
5. **Skip node_modules, vendor, dist** - Only clean source code
6. **Create backup** - Optionally create .bak files before changes

## Example Patterns

### Before Cleanup
```javascript
// FIXED: was causing null pointer
// console.log('debug value:', x);
const result = processData(input); // TODO: done - add validation
console.log('checking result:', result); // debug
// Previous implementation that was buggy:
// const old = badFunction(x);
return result;
```

### After Cleanup
```javascript
const result = processData(input);
return result;
```

## Output Format

After cleanup, provide:
1. Number of files processed
2. Number of lines removed
3. Summary of changes by category
4. Any items that need manual review
