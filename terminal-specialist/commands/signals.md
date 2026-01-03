---
description: Unix signal handling - SIGINT, SIGTERM, SIGHUP with handler patterns and best practices
allowed-tools: Read
argument-hint: "[SIGINT | SIGTERM | SIGHUP | all]"
---

# Signal Handling Guide

You are providing signal handling guidance. Follow these steps:

## 1. Query

The user needs help with: $ARGUMENTS

## 2. Read Documentation

Read the signal handling documentation:
`skills/terminal-docs/references/09-signals.md`

## 3. Common Signals

| Signal | Number | Keyboard | Description |
|--------|--------|----------|-------------|
| SIGHUP | 1 | | Hangup |
| SIGINT | 2 | Ctrl+C | Interrupt |
| SIGQUIT | 3 | Ctrl+\ | Quit |
| SIGKILL | 9 | | Force kill |
| SIGTERM | 15 | | Graceful terminate |
| SIGTSTP | 20 | Ctrl+Z | Terminal stop |
| SIGCONT | 18 | | Continue |
| SIGWINCH | 28 | | Window resize |

## 4. Signal Handling Patterns

### Bash
```bash
trap 'cleanup' EXIT
trap 'echo "Interrupted"' INT TERM
```

### C
```c
struct sigaction sa;
sa.sa_handler = handler;
sigemptyset(&sa.sa_mask);
sa.sa_flags = SA_RESTART;
sigaction(SIGINT, &sa, NULL);
```

### Python
```python
import signal
signal.signal(signal.SIGINT, handler)
```

## 5. Safety Considerations

- Only use async-signal-safe functions in handlers
- Set flags in handlers, process in main loop
- Be aware of race conditions

## 6. Provide Response

Based on the user's query:
1. Identify the signals they need to handle
2. Provide appropriate handler patterns
3. Note signal safety considerations
4. Include cleanup/restoration code
5. Mention platform differences if relevant
