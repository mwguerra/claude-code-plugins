---
name: streams
description: Standard I/O streams reference (stdin, stdout, stderr)
---

# I/O Streams Reference

You are providing I/O streams guidance. Follow these steps:

## 1. Query

The user needs help with: $ARGUMENTS

## 2. Read Documentation

Read the streams documentation:
`skills/terminal-docs/references/02-streams.md`

Also see: `skills/terminal-docs/references/11-redirection.md`

## 3. Stream Overview

| Stream | FD | Purpose |
|--------|-----|---------|
| stdin | 0 | Standard input |
| stdout | 1 | Standard output |
| stderr | 2 | Error output |

## 4. Buffering Behavior

| Stream | TTY | Pipe/File |
|--------|-----|-----------|
| stdin | Line-buffered | Fully-buffered |
| stdout | Line-buffered | Fully-buffered |
| stderr | Unbuffered | Unbuffered |

## 5. Common Operations

### Check if TTY
```bash
[ -t 0 ] && echo "stdin is TTY"
```

```python
import sys
sys.stdin.isatty()
```

### Control Buffering
```bash
stdbuf -oL command  # Line-buffered
stdbuf -o0 command  # Unbuffered
```

### Redirection
```bash
cmd > file      # stdout to file
cmd 2>&1        # stderr to stdout
cmd &> file     # both to file
```

## 6. Provide Response

Based on the user's query:
1. Explain the relevant stream behavior
2. Provide code examples
3. Show redirection patterns
4. Note buffering considerations
5. Include detection/testing code
