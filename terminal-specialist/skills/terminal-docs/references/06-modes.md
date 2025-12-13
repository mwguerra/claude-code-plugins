# Terminal Modes and Line Discipline

## 1. Terminal Modes Overview

Terminals can operate in different modes that control how input is processed:

| Mode | Description |
|------|-------------|
| **Canonical (Cooked)** | Line-by-line input with editing |
| **Non-canonical (Raw)** | Character-by-character input |
| **cbreak** | Partial raw mode |

## 2. Canonical vs Non-Canonical Mode

```
Canonical Mode (Default):
┌─────────────────────────────────────────┐
│ User types: H e l l o Enter             │
│                           │             │
│                           ▼             │
│ Line buffer: "Hello\n"                  │
│                  │                      │
│                  ▼                      │
│ Application receives complete line      │
└─────────────────────────────────────────┘

Non-Canonical Mode:
┌─────────────────────────────────────────┐
│ User types: H                           │
│             │                           │
│             ▼                           │
│ Application receives 'H' immediately    │
│                                         │
│ User types: e                           │
│             │                           │
│             ▼                           │
│ Application receives 'e' immediately    │
└─────────────────────────────────────────┘
```

## 3. Terminal Attributes (termios)

```c
#include <termios.h>
#include <unistd.h>

struct termios original, raw;

// Save original settings
tcgetattr(STDIN_FILENO, &original);

// Create raw mode settings
raw = original;

// Input flags
raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);

// Output flags
raw.c_oflag &= ~(OPOST);

// Control flags
raw.c_cflag |= (CS8);

// Local flags
raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);

// Control characters
raw.c_cc[VMIN] = 0;   // Minimum chars to read
raw.c_cc[VTIME] = 1;  // Timeout in 1/10 seconds

// Apply settings
tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);

// Restore original settings
tcsetattr(STDIN_FILENO, TCSAFLUSH, &original);
```

## 4. termios Flags Reference

### Input Flags (c_iflag)

| Flag | Description |
|------|-------------|
| `BRKINT` | Signal on break |
| `ICRNL` | Map CR to NL |
| `IGNBRK` | Ignore break |
| `IGNCR` | Ignore CR |
| `IGNPAR` | Ignore parity errors |
| `INLCR` | Map NL to CR |
| `INPCK` | Enable parity checking |
| `ISTRIP` | Strip 8th bit |
| `IXOFF` | Enable start/stop input |
| `IXON` | Enable start/stop output |
| `PARMRK` | Mark parity errors |

### Output Flags (c_oflag)

| Flag | Description |
|------|-------------|
| `OPOST` | Post-process output |
| `ONLCR` | Map NL to CR-NL |
| `OCRNL` | Map CR to NL |
| `ONOCR` | No CR at column 0 |
| `ONLRET` | NL performs CR |
| `OFILL` | Use fill characters |

### Control Flags (c_cflag)

| Flag | Description |
|------|-------------|
| `CSIZE` | Character size mask (CS5, CS6, CS7, CS8) |
| `CSTOPB` | 2 stop bits |
| `CREAD` | Enable receiver |
| `PARENB` | Enable parity |
| `PARODD` | Odd parity |
| `HUPCL` | Hangup on close |
| `CLOCAL` | Ignore modem control lines |

### Local Flags (c_lflag)

| Flag | Description |
|------|-------------|
| `ECHO` | Enable echo |
| `ECHOE` | Echo erase as BS-SP-BS |
| `ECHOK` | Echo NL after kill |
| `ECHONL` | Echo NL |
| `ICANON` | Canonical mode |
| `IEXTEN` | Extended functions |
| `ISIG` | Enable signals |
| `NOFLSH` | Disable flush after interrupt |
| `TOSTOP` | Background write sends SIGTTOU |

## 5. Control Characters (c_cc)

| Index | Default | Description |
|-------|---------|-------------|
| `VEOF` | Ctrl+D | End of file |
| `VEOL` | | Additional end of line |
| `VERASE` | Ctrl+H/DEL | Erase character |
| `VINTR` | Ctrl+C | Interrupt |
| `VKILL` | Ctrl+U | Kill line |
| `VMIN` | 1 | Minimum chars for read |
| `VQUIT` | Ctrl+\ | Quit |
| `VSTART` | Ctrl+Q | Resume output |
| `VSTOP` | Ctrl+S | Suspend output |
| `VSUSP` | Ctrl+Z | Suspend |
| `VTIME` | 0 | Read timeout |

## 6. Using stty

```bash
# Display all settings
stty -a

# Display settings in parseable form
stty -g

# Enable raw mode
stty raw

# Enable cooked mode
stty cooked

# Disable echo
stty -echo

# Enable echo
stty echo

# Set special characters
stty erase ^H       # Set erase character
stty intr ^C        # Set interrupt character
stty eof ^D         # Set EOF character

# Set character size
stty cs8            # 8-bit characters

# Set baud rate
stty 115200

# Save and restore settings
saved=$(stty -g)
stty raw
# ... do something
stty "$saved"
```

## 7. Common Mode Configurations

### Raw Mode

```bash
stty raw -echo
# Or in C:
# c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG)
# c_iflag &= ~(IXON | ICRNL)
```

### Cbreak Mode

Like raw mode but keeps signal processing:

```bash
stty -icanon min 1
# Or in C:
# c_lflag &= ~(ICANON | ECHO)
# Keep ISIG set
```

### Password Input

```bash
stty -echo
read -s password
stty echo
```

## 8. Python termios Example

```python
import sys
import tty
import termios

def get_char():
    """Read a single character without waiting for Enter."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = sys.stdin.read(1)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return ch

def get_password():
    """Read password with echo disabled."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        new = termios.tcgetattr(fd)
        new[3] &= ~termios.ECHO  # Disable echo
        termios.tcsetattr(fd, termios.TCSADRAIN, new)
        password = input()
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    return password
```

## 9. tcsetattr Timing

| Mode | Description |
|------|-------------|
| `TCSANOW` | Change immediately |
| `TCSADRAIN` | Change after output drain |
| `TCSAFLUSH` | Change after output drain, discard input |
