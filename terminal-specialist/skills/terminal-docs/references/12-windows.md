# Windows-Specific Concepts

## 1. Console Architecture

```
┌─────────────────────────────────────────┐
│        Console Host (conhost.exe)        │
│        or Windows Terminal               │
├─────────────────────────────────────────┤
│            Console API                   │
│      (kernel32.dll functions)            │
├─────────────────────────────────────────┤
│              ConDrv                      │
│        (Console Driver)                  │
├─────────────────────────────────────────┤
│        Console Application               │
│     (cmd.exe, PowerShell, etc.)          │
└─────────────────────────────────────────┘
```

## 2. Console API Functions (Win32)

```c
#include <windows.h>

// Handle retrieval
HANDLE hStdIn = GetStdHandle(STD_INPUT_HANDLE);
HANDLE hStdOut = GetStdHandle(STD_OUTPUT_HANDLE);
HANDLE hStdErr = GetStdHandle(STD_ERROR_HANDLE);

// Console buffer info
CONSOLE_SCREEN_BUFFER_INFO csbi;
GetConsoleScreenBufferInfo(hStdOut, &csbi);
int columns = csbi.srWindow.Right - csbi.srWindow.Left + 1;
int rows = csbi.srWindow.Bottom - csbi.srWindow.Top + 1;

// Set cursor position
COORD pos = {10, 5};
SetConsoleCursorPosition(hStdOut, pos);

// Set text attributes
SetConsoleTextAttribute(hStdOut,
    FOREGROUND_RED | FOREGROUND_INTENSITY);

// Console mode
DWORD mode;
GetConsoleMode(hStdIn, &mode);
SetConsoleMode(hStdIn, mode | ENABLE_VIRTUAL_TERMINAL_INPUT);
```

## 3. Console Modes (Windows)

### Input Modes

```c
// Input mode flags
ENABLE_ECHO_INPUT           // Echo typed characters
ENABLE_INSERT_MODE          // Insert mode
ENABLE_LINE_INPUT           // Line input mode (canonical)
ENABLE_MOUSE_INPUT          // Mouse events
ENABLE_PROCESSED_INPUT      // Process Ctrl+C
ENABLE_QUICK_EDIT_MODE      // Mouse selection
ENABLE_VIRTUAL_TERMINAL_INPUT  // VT input sequences
ENABLE_WINDOW_INPUT         // Window resize events
```

### Output Modes

```c
// Output mode flags
ENABLE_PROCESSED_OUTPUT     // Process control characters
ENABLE_WRAP_AT_EOL_OUTPUT   // Wrap at end of line
ENABLE_VIRTUAL_TERMINAL_PROCESSING  // VT sequences
DISABLE_NEWLINE_AUTO_RETURN // Don't auto CR on LF
```

### Enabling VT Processing

```c
// Enable VT processing for ANSI escape sequences
HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
DWORD mode;
GetConsoleMode(hOut, &mode);
SetConsoleMode(hOut, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);

// Now ANSI sequences work
printf("\x1b[31mRed text\x1b[0m\n");
```

## 4. Virtual Terminal Sequences (Windows 10+)

Windows 10 and later support ANSI/VT100 escape sequences:

```c
// Enable VT processing
HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
DWORD mode;
GetConsoleMode(hOut, &mode);
SetConsoleMode(hOut, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);

// Now ANSI sequences work
printf("\x1b[31mRed text\x1b[0m\n");
```

### PowerShell

```powershell
# VT sequences work in Windows Terminal and modern consoles
Write-Host "`e[31mRed text`e[0m"

# Or using $PSStyle (PowerShell 7.2+)
$PSStyle.Foreground.Red + "Red text" + $PSStyle.Reset
```

## 5. Windows Terminal vs ConHost

| Feature | ConHost (Legacy) | Windows Terminal |
|---------|------------------|------------------|
| VT Sequences | Partial (Win10+) | Full |
| True Color | Limited | Yes |
| Tabs | No | Yes |
| GPU Acceleration | No | Yes |
| Unicode | Partial | Full |
| Customization | Limited | Extensive |
| Profiles | No | Yes |
| Panes | No | Yes |

## 6. ConPTY (Pseudo Console)

Windows 10 introduced ConPTY for better PTY emulation:

```c
#include <windows.h>
#include <consoleapi.h>

HPCON hPC;
HRESULT hr;

// Create pipes for I/O
HANDLE hPipeIn, hPipeOut;
// ... CreatePipe setup ...

// Create pseudo console
COORD size = {80, 24};
hr = CreatePseudoConsole(size, hPipeIn, hPipeOut, 0, &hPC);

// Attach to process via PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE

// Resize
hr = ResizePseudoConsole(hPC, newSize);

// Close
ClosePseudoConsole(hPC);
```

## 7. Console Colors (Legacy API)

```c
// Legacy color attributes (before VT support)
#define FOREGROUND_BLUE      0x0001
#define FOREGROUND_GREEN     0x0002
#define FOREGROUND_RED       0x0004
#define FOREGROUND_INTENSITY 0x0008
#define BACKGROUND_BLUE      0x0010
#define BACKGROUND_GREEN     0x0020
#define BACKGROUND_RED       0x0040
#define BACKGROUND_INTENSITY 0x0080

// Set text color
SetConsoleTextAttribute(hStdOut,
    FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_INTENSITY);
```

## 8. Reading Console Input

```c
HANDLE hIn = GetStdHandle(STD_INPUT_HANDLE);
INPUT_RECORD ir;
DWORD read;

// Read single event
ReadConsoleInput(hIn, &ir, 1, &read);

switch (ir.EventType) {
    case KEY_EVENT:
        if (ir.Event.KeyEvent.bKeyDown) {
            WCHAR ch = ir.Event.KeyEvent.uChar.UnicodeChar;
            WORD vk = ir.Event.KeyEvent.wVirtualKeyCode;
            // Process key
        }
        break;
    case MOUSE_EVENT:
        COORD pos = ir.Event.MouseEvent.dwMousePosition;
        DWORD buttons = ir.Event.MouseEvent.dwButtonState;
        // Process mouse
        break;
    case WINDOW_BUFFER_SIZE_EVENT:
        COORD size = ir.Event.WindowBufferSizeEvent.dwSize;
        // Handle resize
        break;
}
```

## 9. Windows Subsystem for Linux (WSL)

```powershell
# List distributions
wsl --list --verbose

# Run Linux command
wsl ls -la

# Enter distribution
wsl

# Set default distribution
wsl --set-default Ubuntu

# Environment variables pass through
# Windows: PATH accessible as $PATH in WSL
# WSL: WSLENV controls variable sharing
```

## 10. PowerShell Console Features

```powershell
# Console size
$Host.UI.RawUI.WindowSize
$Host.UI.RawUI.BufferSize

# Cursor position
$Host.UI.RawUI.CursorPosition

# Colors
$Host.UI.RawUI.ForegroundColor = "Red"
$Host.UI.RawUI.BackgroundColor = "Black"

# Clear screen
Clear-Host

# Read key
$key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Set window title
$Host.UI.RawUI.WindowTitle = "My Console"
```

## 11. cmd.exe Specifics

```batch
:: Set console code page to UTF-8
chcp 65001

:: Enable delayed expansion
setlocal enabledelayedexpansion

:: Colors with escape sequences (Win10+)
echo [31mRed text[0m

:: Or use prompt for colors
prompt $e[32m$p$g$e[0m

:: Clear screen
cls

:: Console dimensions
mode con cols=120 lines=50
```

## 12. Detecting Windows Terminal Features

```python
import os

def is_windows_terminal():
    """Check if running in Windows Terminal."""
    return bool(os.environ.get('WT_SESSION'))

def is_conemu():
    """Check if running in ConEmu."""
    return bool(os.environ.get('ConEmuANSI'))

def supports_vt_sequences():
    """Check VT sequence support on Windows."""
    import sys
    if sys.platform != 'win32':
        return True

    # Windows 10+ with VT support
    import ctypes
    kernel32 = ctypes.windll.kernel32

    STD_OUTPUT_HANDLE = -11
    ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004

    handle = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
    mode = ctypes.c_ulong()

    if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
        return bool(mode.value & ENABLE_VIRTUAL_TERMINAL_PROCESSING)

    return False
```
