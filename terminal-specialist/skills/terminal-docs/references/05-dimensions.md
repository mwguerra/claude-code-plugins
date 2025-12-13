# Terminal Dimensions and Geometry

## 1. Getting Terminal Size

### Unix/Linux (C)

```c
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdio.h>

int main() {
    struct winsize w;

    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0) {
        printf("Rows: %d\n", w.ws_row);
        printf("Columns: %d\n", w.ws_col);
        printf("X pixels: %d\n", w.ws_xpixel);
        printf("Y pixels: %d\n", w.ws_ypixel);
    }

    return 0;
}
```

### Bash

```bash
# Using tput
echo "Columns: $(tput cols)"
echo "Rows: $(tput lines)"

# Using stty
stty size  # Returns: rows cols

# Using environment variables (may not be accurate)
echo "COLUMNS: $COLUMNS"
echo "LINES: $LINES"

# Force shell to update
shopt -s checkwinsize
```

### Python

```python
import os
import shutil

# shutil method (Python 3.3+)
size = shutil.get_terminal_size()
print(f"Columns: {size.columns}, Rows: {size.lines}")

# os method
size = os.get_terminal_size()
print(f"Columns: {size.columns}, Lines: {size.lines}")

# Fallback with default
size = shutil.get_terminal_size(fallback=(80, 24))
```

### Node.js

```javascript
// Get terminal size
const columns = process.stdout.columns;
const rows = process.stdout.rows;

// Listen for resize
process.stdout.on('resize', () => {
    console.log(`New size: ${process.stdout.columns}x${process.stdout.rows}`);
});
```

### PowerShell

```powershell
$host.UI.RawUI.WindowSize.Width   # Columns
$host.UI.RawUI.WindowSize.Height  # Rows
$host.UI.RawUI.BufferSize         # Buffer dimensions

# Or using .NET
[Console]::WindowWidth
[Console]::WindowHeight
```

## 2. Setting Terminal Size

```bash
# Using stty (sets COLUMNS and LINES)
stty rows 50 cols 132

# Using escape sequence (request terminal resize)
printf '\e[8;50;132t'

# Resize using escape sequence (xterm)
echo -e "\e[8;40;120t"  # 40 rows, 120 cols
```

## 3. Handling Terminal Resize

### Signal Handling (Unix/Linux)

```c
#include <signal.h>
#include <sys/ioctl.h>
#include <unistd.h>

volatile sig_atomic_t resize_flag = 0;

void handle_sigwinch(int sig) {
    resize_flag = 1;
}

int main() {
    struct sigaction sa;
    sa.sa_handler = handle_sigwinch;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(SIGWINCH, &sa, NULL);

    while (1) {
        if (resize_flag) {
            resize_flag = 0;
            struct winsize w;
            ioctl(STDOUT_FILENO, TIOCGWINSZ, &w);
            // Handle resize...
        }
        // Main loop...
    }
}
```

### Bash

```bash
# Trap SIGWINCH
trap 'handle_resize' WINCH

handle_resize() {
    COLUMNS=$(tput cols)
    LINES=$(tput lines)
    echo "Resized to ${COLUMNS}x${LINES}"
}
```

### Python

```python
import signal
import shutil

def handle_resize(signum, frame):
    size = shutil.get_terminal_size()
    print(f"Resized to {size.columns}x{size.lines}")

signal.signal(signal.SIGWINCH, handle_resize)
```

## 4. Common Terminal Dimensions

| Environment | Typical Size |
|-------------|--------------|
| Default terminal | 80x24 |
| Modern terminal | 120x40 |
| Maximized window | Varies |
| Serial console | 80x24 |
| Virtual console | 80x25 |

## 5. Escape Sequences for Size

### Query Terminal Size

```bash
# Query cursor position (returns current position)
printf '\e[6n'
# Response: \e[{row};{col}R

# Query terminal size in cells (xterm)
printf '\e[18t'
# Response: \e[8;{rows};{cols}t

# Query terminal size in pixels (xterm)
printf '\e[14t'
# Response: \e[4;{height};{width}t
```

### Set Terminal Size

```bash
# Resize to rows x cols
printf '\e[8;{rows};{cols}t'

# Examples
printf '\e[8;24;80t'   # Standard 80x24
printf '\e[8;50;120t'  # Larger terminal
```

## 6. The winsize Structure

```c
struct winsize {
    unsigned short ws_row;      // Number of rows (lines)
    unsigned short ws_col;      // Number of columns
    unsigned short ws_xpixel;   // Horizontal size in pixels
    unsigned short ws_ypixel;   // Vertical size in pixels
};
```

## 7. Buffer vs Window Size

On some systems, the buffer size differs from window size:

| Concept | Description |
|---------|-------------|
| Window size | Visible area of terminal |
| Buffer size | Total scrollback buffer |

### Windows Console

```c
CONSOLE_SCREEN_BUFFER_INFO csbi;
GetConsoleScreenBufferInfo(hStdOut, &csbi);

// Window size
int windowCols = csbi.srWindow.Right - csbi.srWindow.Left + 1;
int windowRows = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;

// Buffer size
int bufferCols = csbi.dwSize.X;
int bufferRows = csbi.dwSize.Y;
```

## 8. How Terminal Size Information Flows

Understanding how terminal size is communicated between components is essential for building responsive terminal applications.

### Unix/Linux: The Complete Flow

The kernel maintains a `winsize` structure for each terminal device (PTY). This is stored in the **PTY driver** in the kernel, not in the shell or application.

```
┌─────────────────────────────────────────────────────────────┐
│                   Terminal Emulator                         │
│            (knows actual window pixel size)                 │
│                         │                                   │
│    User resizes ───────►│                                   │
│    window               │                                   │
└─────────────────────────┼───────────────────────────────────┘
                          │
                          │ ioctl(TIOCSWINSZ, &winsize)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    PTY Master                               │
│              (terminal emulator side)                       │
└─────────────────────────┼───────────────────────────────────┘
                          │
                          │ Kernel propagates to slave
                          │ and sends SIGWINCH to foreground
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    PTY Slave                                │
│               (shell/app side)                              │
│                         │                                   │
│         ioctl(TIOCGWINSZ) to read size                      │
└─────────────────────────┼───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   Shell / Application                       │
│              (bash, vim, htop, etc.)                        │
└─────────────────────────────────────────────────────────────┘
```

### The Key System Calls

**Terminal emulator sets the size:**
```c
// Called by terminal emulator when window is resized
struct winsize ws = {.ws_row = 40, .ws_col = 120};
ioctl(pty_master_fd, TIOCSWINSZ, &ws);
```

**Application reads the size:**
```c
// Called by shell/application to get current size
struct winsize ws;
ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws);
printf("Size: %d rows x %d cols\n", ws.ws_row, ws.ws_col);
```

### How Resize Notification Works

When the terminal emulator updates the size via `TIOCSWINSZ`:

1. Kernel updates the `winsize` structure in the PTY driver
2. Kernel sends **SIGWINCH** (signal 28) to the foreground process group
3. Applications catch this signal and re-query the size

```c
#include <signal.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdio.h>

volatile sig_atomic_t resize_needed = 0;
int current_rows, current_cols;

void handle_sigwinch(int sig) {
    resize_needed = 1;  // Set flag only - signal-safe
}

void update_size() {
    struct winsize ws;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0) {
        current_rows = ws.ws_row;
        current_cols = ws.ws_col;
        // Redraw with new dimensions
    }
}

int main() {
    signal(SIGWINCH, handle_sigwinch);
    update_size();  // Get initial size

    while (1) {
        if (resize_needed) {
            resize_needed = 0;
            update_size();
            printf("Resized to %dx%d\n", current_cols, current_rows);
        }
        // Main application loop...
    }
}
```

### Calculating Characters from Pixels

The terminal emulator is the only component that knows actual pixel dimensions and font metrics. It calculates character dimensions:

```
columns = window_width_pixels / font_cell_width
rows = window_height_pixels / font_cell_height
```

**Example:** With a 12-pixel-wide font in a 960px window:
```
960 / 12 = 80 columns
```

### Windows: Console Size Model

Windows uses a different model with the Console API. It distinguishes between:
- **Buffer size**: Total scrollback buffer dimensions
- **Window size**: Visible viewport dimensions

```c
#include <windows.h>

CONSOLE_SCREEN_BUFFER_INFO csbi;
HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
GetConsoleScreenBufferInfo(hOut, &csbi);

// Visible window size
int columns = csbi.srWindow.Right - csbi.srWindow.Left + 1;
int rows = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;

// Total buffer size
int bufferWidth = csbi.dwSize.X;
int bufferHeight = csbi.dwSize.Y;
```

### Windows Resize Events

Windows uses console events instead of signals:

```c
HANDLE hIn = GetStdHandle(STD_INPUT_HANDLE);
INPUT_RECORD ir;
DWORD read;

// Enable window input events
DWORD mode;
GetConsoleMode(hIn, &mode);
SetConsoleMode(hIn, mode | ENABLE_WINDOW_INPUT);

while (ReadConsoleInput(hIn, &ir, 1, &read)) {
    if (ir.EventType == WINDOW_BUFFER_SIZE_EVENT) {
        COORD newSize = ir.Event.WindowBufferSizeEvent.dwSize;
        printf("Resized to %dx%d\n", newSize.X, newSize.Y);
    }
}
```

### Escape Sequence Query (Alternative Method)

When `ioctl` isn't available (e.g., over certain serial connections), applications can query the terminal directly using escape sequences:

```bash
# Method 1: Ask terminal for size directly (xterm)
printf '\e[18t'
# Response: ESC[8;rows;colst

# Method 2: Position cursor at far corner and query position
printf '\e[9999;9999H'  # Move to (9999,9999) - will stop at actual max
printf '\e[6n'          # Query cursor position
# Response: ESC[row;colR
```

### Component Responsibilities Summary

| Component | Role |
|-----------|------|
| **Terminal Emulator** | Source of truth - calculates character size from pixels, calls `ioctl(TIOCSWINSZ)` |
| **Kernel/PTY Driver** | Stores the `winsize` structure, sends `SIGWINCH` on change |
| **Shell/Application** | Calls `ioctl(TIOCGWINSZ)` to read size, handles `SIGWINCH` |

The terminal emulator is the **source of truth** - it's the only component that actually knows the window's pixel dimensions and font metrics.

## 9. Responsive Terminal Applications

Best practices for handling terminal dimensions:

1. **Query size on startup** - Get initial dimensions
2. **Handle SIGWINCH** - React to resize events
3. **Use relative positioning** - Avoid hardcoded positions
4. **Test edge cases** - Very small/large terminals
5. **Provide fallbacks** - Default to 80x24 if unknown
6. **Don't call unsafe functions in signal handlers** - Set a flag and handle in main loop
7. **Consider both Unix and Windows** - Use appropriate APIs for each platform
