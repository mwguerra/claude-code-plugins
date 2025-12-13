# Standard Streams: stdin, stdout, stderr

## 1. Overview

Every process in Unix/Linux/Windows has three standard streams automatically opened:

| Stream | File Descriptor | C Constant | Purpose |
|--------|-----------------|------------|---------|
| **stdin** | 0 | `STDIN_FILENO` | Standard input - where the process reads input |
| **stdout** | 1 | `STDOUT_FILENO` | Standard output - where the process writes normal output |
| **stderr** | 2 | `STDERR_FILENO` | Standard error - where the process writes error/diagnostic messages |

## 2. File Descriptors

File descriptors are non-negative integers that identify open files/streams in a process.

```c
// C example
#include <unistd.h>

// These are always available:
// 0 = stdin
// 1 = stdout
// 2 = stderr

write(1, "Hello stdout\n", 13);  // Write to stdout
write(2, "Hello stderr\n", 13);  // Write to stderr

char buf[100];
read(0, buf, 100);  // Read from stdin
```

## 3. Buffering Behavior

Streams have different default buffering modes:

| Stream | Default Buffering | Description |
|--------|-------------------|-------------|
| **stdin** | Line-buffered (terminal) / Fully buffered (file) | Input is processed line by line or in blocks |
| **stdout** | Line-buffered (terminal) / Fully buffered (file) | Output is flushed on newline (terminal) or when buffer fills |
| **stderr** | Unbuffered | Output is written immediately |

### Buffering Modes

| Mode | Description | Typical Use |
|------|-------------|-------------|
| **Unbuffered** | I/O happens immediately | stderr, critical output |
| **Line-buffered** | Buffer flushed on newline | Interactive terminal stdout |
| **Fully-buffered** | Buffer flushed when full (typically 4KB-64KB) | File I/O, pipes |

### Controlling Buffering (C)

```c
#include <stdio.h>

// Disable buffering entirely
setvbuf(stdout, NULL, _IONBF, 0);

// Line buffering
setvbuf(stdout, NULL, _IOLBF, 0);

// Full buffering with custom buffer
char buffer[8192];
setvbuf(stdout, buffer, _IOFBF, sizeof(buffer));

// Force flush
fflush(stdout);
```

### Controlling Buffering (Shell)

```bash
# Run command with unbuffered output
stdbuf -o0 command

# Line-buffered output
stdbuf -oL command

# Using unbuffer (from expect package)
unbuffer command

# Python unbuffered mode
python -u script.py
PYTHONUNBUFFERED=1 python script.py
```

## 4. Checking if Connected to Terminal

### Unix/Linux (C)

```c
#include <unistd.h>

if (isatty(STDIN_FILENO)) {
    printf("stdin is a terminal\n");
}
if (isatty(STDOUT_FILENO)) {
    printf("stdout is a terminal\n");
}
```

### Bash

```bash
if [ -t 0 ]; then
    echo "stdin is a terminal"
fi

if [ -t 1 ]; then
    echo "stdout is a terminal"
fi
```

### Python

```python
import sys
import os

print(f"stdin is TTY: {sys.stdin.isatty()}")
print(f"stdout is TTY: {sys.stdout.isatty()}")
print(f"stderr is TTY: {sys.stderr.isatty()}")

# Alternative using os module
print(f"stdin is TTY: {os.isatty(0)}")
```

### Node.js

```javascript
process.stdin.isTTY   // true if stdin is a terminal
process.stdout.isTTY  // true if stdout is a terminal
process.stderr.isTTY  // true if stderr is a terminal
```

## 5. Stream Inheritance

When a process forks:
- Child inherits all open file descriptors
- File descriptors point to same underlying file descriptions
- Changes to file offset affect both processes

```
Parent Process                    Child Process (after fork)
┌─────────────────┐              ┌─────────────────┐
│ fd 0 → stdin    │──────────────│ fd 0 → stdin    │
│ fd 1 → stdout   │──────────────│ fd 1 → stdout   │
│ fd 2 → stderr   │──────────────│ fd 2 → stderr   │
│ fd 3 → file.txt │──────────────│ fd 3 → file.txt │
└─────────────────┘              └─────────────────┘
         │                                │
         └────────────┬───────────────────┘
                      ▼
              File Description
              (shared state)
```

## 6. Redirecting Streams Programmatically

### C

```c
#include <unistd.h>
#include <fcntl.h>

// Redirect stdout to file
int fd = open("output.txt", O_WRONLY | O_CREAT | O_TRUNC, 0644);
dup2(fd, STDOUT_FILENO);
close(fd);

// Redirect stderr to stdout
dup2(STDOUT_FILENO, STDERR_FILENO);
```

### Python

```python
import sys

# Redirect stdout
sys.stdout = open('output.txt', 'w')

# Redirect stderr to stdout
sys.stderr = sys.stdout

# Restore
sys.stdout = sys.__stdout__
sys.stderr = sys.__stderr__
```
