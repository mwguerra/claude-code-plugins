---
name: cross-platform
description: Cross-platform terminal compatibility guide
---

# Cross-Platform Compatibility Guide

You are providing cross-platform guidance. Follow these steps:

## 1. Query

The user needs help with: $ARGUMENTS

## 2. Read Documentation

Read the cross-platform documentation:
`skills/terminal-docs/references/13-cross-platform.md`

Also relevant:
- `skills/terminal-docs/references/12-windows.md`

## 3. Key Differences

### Line Endings
| Platform | Ending |
|----------|--------|
| Unix/Linux/macOS | LF (\n) |
| Windows | CR+LF (\r\n) |

### Path Separators
| Platform | Path | PATH |
|----------|------|------|
| Unix | / | : |
| Windows | \ | ; |

### Environment Variables
| Purpose | Unix | Windows |
|---------|------|---------|
| Home | $HOME | %USERPROFILE% |
| Temp | $TMPDIR | %TEMP% |
| User | $USER | %USERNAME% |

## 4. Common Patterns

### Portable Path Handling (Python)
```python
from pathlib import Path
path = Path('dir') / 'subdir' / 'file.txt'
```

### Color Support Detection
```python
def supports_color():
    if os.environ.get('NO_COLOR'):
        return False
    if not sys.stdout.isatty():
        return False
    return True
```

### Terminal Size
```python
import shutil
size = shutil.get_terminal_size(fallback=(80, 24))
```

## 5. Provide Response

Based on the user's query:
1. Identify the cross-platform concern
2. Show platform-specific implementations
3. Provide portable abstraction code
4. Note edge cases and gotchas
5. Recommend cross-platform libraries if applicable
