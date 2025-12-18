---
description: Guide to terminal modes - canonical, raw, and cbreak with termios configuration
---

# Terminal Modes Guide

You are explaining terminal modes. Follow these steps:

## 1. Query

The user wants to understand: $ARGUMENTS

## 2. Read Documentation

Read the terminal modes documentation:
`skills/terminal-docs/references/06-modes.md`

## 3. Mode Overview

### Canonical Mode (Cooked)
- Default mode
- Line-by-line input
- Backspace, line editing works
- Input delivered on Enter

### Non-Canonical Mode (Raw)
- Character-by-character input
- No line editing
- Immediate input delivery
- Required for editors, games

### Cbreak Mode
- Like raw but keeps signals
- Ctrl+C still works

## 4. Implementation Patterns

### Using stty
```bash
stty raw -echo    # Raw mode
stty cooked       # Canonical mode
```

### Using termios (C)
```c
struct termios raw;
tcgetattr(STDIN_FILENO, &raw);
raw.c_lflag &= ~(ICANON | ECHO);
tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
```

### Python
```python
import tty, termios
tty.setraw(sys.stdin.fileno())
```

## 5. Important Flags

- ICANON - Canonical mode
- ECHO - Echo input
- ISIG - Enable signals
- IXON - Flow control

## 6. Provide Response

Based on the user's query:
1. Explain the relevant mode
2. Provide code to enter/exit the mode
3. Show proper cleanup patterns
4. Note what features are enabled/disabled
5. Include cross-platform considerations
