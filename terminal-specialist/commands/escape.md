---
description: ANSI escape sequence reference and examples
---

# ANSI Escape Sequence Reference

You are providing escape sequence reference. Follow these steps:

## 1. Query

The user is looking for: $ARGUMENTS

## 2. Read Documentation

Read the escape sequence documentation:
`skills/terminal-docs/references/10-escape-sequences.md`

## 3. Common Categories

### Control Characters
- ^C (Ctrl+C) - SIGINT
- ^D (Ctrl+D) - EOF
- ^Z (Ctrl+Z) - SIGTSTP
- ESC (\e, \033, \x1b)

### Cursor Movement
```bash
\e[H         # Home
\e[{r};{c}H  # Move to row, col
\e[{n}A      # Up n lines
\e[{n}B      # Down n lines
\e[{n}C      # Forward n cols
\e[{n}D      # Back n cols
\e[s / \e[u  # Save/restore cursor
```

### Screen Clearing
```bash
\e[2J        # Clear screen
\e[3J        # Clear with scrollback
\e[K         # Clear to end of line
\e[2K        # Clear entire line
```

### Text Formatting
```bash
\e[0m        # Reset
\e[1m        # Bold
\e[3m        # Italic
\e[4m        # Underline
\e[7m        # Reverse
```

### Colors
```bash
# 4-bit: \e[{30-37}m (fg), \e[{40-47}m (bg)
# 256: \e[38;5;{n}m (fg), \e[48;5;{n}m (bg)
# RGB: \e[38;2;{r};{g};{b}m
```

## 4. Provide Response

Based on the user's query:
1. Find the specific escape sequences they need
2. Provide the exact syntax
3. Show usage examples
4. Note any terminal compatibility issues
5. Suggest tput alternatives for portability
