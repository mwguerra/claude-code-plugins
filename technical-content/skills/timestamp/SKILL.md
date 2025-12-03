---
name: timestamp
description: Create timestamps for files, directories, and resources in format YYYY-MM-DD-HH-MM-SS or YYYY_MM_DD. Use when naming files or folders that need date/time prefixes.
allowed-tools: Bash(bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/timestamp.ts:*)
---

# Timestamp

Generate timestamps for file and folder naming.

## Usage

```bash
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/timestamp.ts
```

**Output:** `2025-01-15-14-30-45`

For folder format:

```bash
bun run "${CLAUDE_PLUGIN_ROOT}"/scripts/timestamp.ts --folder
```

**Output:** `2025_01_15`
