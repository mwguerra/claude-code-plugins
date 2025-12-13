# Cross-Platform Considerations

## 1. Line Endings

| Platform | Line Ending | Escape | Hex |
|----------|-------------|--------|-----|
| Unix/Linux/macOS | LF | `\n` | `0x0A` |
| Windows | CR+LF | `\r\n` | `0x0D 0x0A` |
| Classic Mac (pre-OS X) | CR | `\r` | `0x0D` |

### Converting Line Endings

```bash
# Unix to Windows
sed 's/$/\r/' file > file.crlf
unix2dos file

# Windows to Unix
sed 's/\r$//' file > file.lf
dos2unix file

# Using tr
tr -d '\r' < file.crlf > file.lf
```

### Python

```python
# Read with universal newlines (default)
with open('file.txt', 'r', newline=None) as f:
    content = f.read()

# Write with specific line ending
with open('file.txt', 'w', newline='\n') as f:  # Unix
    f.write(content)

with open('file.txt', 'w', newline='\r\n') as f:  # Windows
    f.write(content)
```

## 2. Path Separators

| Platform | Separator | Path Variable Separator |
|----------|-----------|-------------------------|
| Unix/Linux/macOS | `/` | `:` |
| Windows | `\` (also `/`) | `;` |

### Cross-Platform Path Handling

```python
import os
from pathlib import Path

# Platform-independent path joining
path = os.path.join('dir', 'subdir', 'file.txt')

# Using pathlib (recommended)
path = Path('dir') / 'subdir' / 'file.txt'

# Normalize path separators
path = os.path.normpath(path)

# Get appropriate separator
sep = os.sep        # Path separator
pathsep = os.pathsep  # PATH variable separator
```

```javascript
// Node.js
const path = require('path');

// Platform-independent join
const filepath = path.join('dir', 'subdir', 'file.txt');

// Get separator
const sep = path.sep;
const delimiter = path.delimiter;  // PATH separator
```

## 3. Terminal Type Detection

```python
import os
import sys
import platform

def get_terminal_info():
    info = {}

    # Operating system
    info['os'] = platform.system()  # 'Linux', 'Windows', 'Darwin'

    # Terminal type
    info['term'] = os.environ.get('TERM', 'unknown')

    # Color support
    info['colorterm'] = os.environ.get('COLORTERM', '')

    # Is TTY?
    info['stdin_tty'] = sys.stdin.isatty()
    info['stdout_tty'] = sys.stdout.isatty()

    # Terminal program
    info['term_program'] = os.environ.get('TERM_PROGRAM', '')

    # Windows specific
    if platform.system() == 'Windows':
        info['wt_session'] = os.environ.get('WT_SESSION', '')  # Windows Terminal
        info['conemu'] = os.environ.get('ConEmuANSI', '')

    return info
```

## 4. Cross-Platform Color Support

```python
import sys
import os

def supports_color():
    """Check if the terminal supports color."""

    # Forced color
    if os.environ.get('FORCE_COLOR'):
        return True

    # No color requested
    if os.environ.get('NO_COLOR'):
        return False

    # Not a TTY
    if not hasattr(sys.stdout, 'isatty') or not sys.stdout.isatty():
        return False

    # Windows
    if sys.platform == 'win32':
        # Windows 10+ supports ANSI
        import platform
        version = platform.version().split('.')
        if int(version[0]) >= 10:
            return True
        # Check for Windows Terminal or ConEmu
        return bool(os.environ.get('WT_SESSION') or
                   os.environ.get('ConEmuANSI'))

    # Unix-like - check TERM
    term = os.environ.get('TERM', '')
    if term == 'dumb':
        return False

    return True
```

## 5. Portable Terminal Size

```python
import shutil
import os
import sys

def get_terminal_size():
    """Get terminal size cross-platform."""

    # Try shutil first (Python 3.3+)
    try:
        return shutil.get_terminal_size()
    except:
        pass

    # Try environment variables
    try:
        return (int(os.environ['COLUMNS']), int(os.environ['LINES']))
    except:
        pass

    # Try ioctl on Unix
    if sys.platform != 'win32':
        try:
            import fcntl
            import termios
            import struct
            result = fcntl.ioctl(0, termios.TIOCGWINSZ,
                               b'\x00\x00\x00\x00\x00\x00\x00\x00')
            rows, cols = struct.unpack('hh', result[:4])
            return (cols, rows)
        except:
            pass

    # Default fallback
    return (80, 24)
```

## 6. Cross-Platform Key Input

```python
import sys

def getch():
    """Read a single character without waiting for Enter."""
    if sys.platform == 'win32':
        import msvcrt
        return msvcrt.getch().decode('utf-8')
    else:
        import tty
        import termios
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return ch
```

## 7. Environment Variable Differences

| Purpose | Unix | Windows |
|---------|------|---------|
| Home directory | `$HOME` | `%USERPROFILE%` |
| Temp directory | `$TMPDIR` or `/tmp` | `%TEMP%` |
| User name | `$USER` | `%USERNAME%` |
| Path separator | `:` | `;` |
| Null device | `/dev/null` | `NUL` |

### Cross-Platform Environment Access

```python
import os
from pathlib import Path

# Home directory
home = Path.home()  # Works on all platforms

# Temp directory
import tempfile
temp = tempfile.gettempdir()

# User name
user = os.environ.get('USER') or os.environ.get('USERNAME')
# Or
import getpass
user = getpass.getuser()
```

## 8. Signal Differences

| Signal | Unix | Windows |
|--------|------|---------|
| SIGINT | Yes | Yes (Ctrl+C) |
| SIGTERM | Yes | No |
| SIGKILL | Yes | No |
| SIGWINCH | Yes | No |
| SIGHUP | Yes | No |

### Cross-Platform Signal Handling

```python
import signal
import sys

def setup_signal_handlers():
    # Ctrl+C - works on all platforms
    signal.signal(signal.SIGINT, handle_interrupt)

    # Unix-specific signals
    if sys.platform != 'win32':
        signal.signal(signal.SIGTERM, handle_terminate)
        signal.signal(signal.SIGHUP, handle_hangup)
```

## 9. Executable Extensions

| Platform | Executables |
|----------|-------------|
| Unix/Linux/macOS | No extension required |
| Windows | `.exe`, `.bat`, `.cmd`, `.com` |

### Finding Executables

```python
import shutil

# Find executable in PATH
path = shutil.which('python')

# Windows: searches for .exe, .bat, etc.
# Unix: searches for executable files
```

## 10. Process Management Differences

| Feature | Unix | Windows |
|---------|------|---------|
| Fork | `fork()` | Not available |
| Spawn | `spawn()` | `CreateProcess()` |
| Signals | Full support | Limited |
| Process groups | Yes | Job objects |
| PTY | `/dev/pts/*` | ConPTY |

### Cross-Platform Process Creation

```python
import subprocess
import sys

# Works on all platforms
result = subprocess.run(['python', 'script.py'],
                       capture_output=True,
                       text=True)

# Shell commands
if sys.platform == 'win32':
    subprocess.run('dir', shell=True)
else:
    subprocess.run('ls -la', shell=True)
```

## 11. File System Differences

| Feature | Unix | Windows |
|---------|------|---------|
| Case sensitivity | Yes | No (usually) |
| Hidden files | `.filename` | Attribute |
| Symlinks | Full support | Limited |
| Max path | 4096 chars | 260 chars (default) |

## 12. Shell Differences

| Feature | Bash | PowerShell | cmd.exe |
|---------|------|------------|---------|
| Variables | `$VAR` | `$env:VAR` | `%VAR%` |
| Assignment | `VAR=val` | `$var = val` | `set VAR=val` |
| Pipes | Text streams | Object streams | Text streams |
| Exit code | `$?` | `$LASTEXITCODE` | `%ERRORLEVEL%` |
