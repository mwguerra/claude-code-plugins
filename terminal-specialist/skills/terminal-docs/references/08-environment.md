# Environment Variables

## 1. Key Terminal Environment Variables

| Variable | Description |
|----------|-------------|
| `TERM` | Terminal type (e.g., xterm-256color, vt100) |
| `SHELL` | User's default shell path |
| `PATH` | Executable search path |
| `HOME` | User's home directory |
| `USER` | Current username |
| `LANG` | Locale setting |
| `LC_*` | Locale category settings |
| `COLUMNS` | Terminal width (may not be auto-updated) |
| `LINES` | Terminal height (may not be auto-updated) |
| `PS1` | Primary prompt string |
| `PS2` | Secondary prompt string |
| `PWD` | Current working directory |
| `OLDPWD` | Previous working directory |
| `DISPLAY` | X11 display server |
| `COLORTERM` | Color terminal type |
| `TERM_PROGRAM` | Terminal emulator name |

## 2. Working with Environment Variables

### Bash

```bash
# Set variable
export VAR="value"
VAR="value"         # Shell variable (not exported)

# Read variable
echo "$VAR"
echo "${VAR}"
echo "${VAR:-default}"  # Default if unset

# Unset variable
unset VAR

# List all environment variables
env
printenv
export -p

# Set for single command
VAR=value command

# Check if set
if [[ -v VAR ]]; then
    echo "VAR is set"
fi

if [[ -z "${VAR+x}" ]]; then
    echo "VAR is unset"
fi
```

### Zsh

```zsh
# Similar to bash
export VAR="value"

# Associative arrays for environment
typeset -A myarray
export myarray

# List exported variables
export
```

### Fish

```fish
# Set variable
set -x VAR "value"       # Export (environment)
set VAR "value"          # Local variable
set -gx VAR "value"      # Global and exported

# Unset
set -e VAR

# List
set -x                   # Show exported
```

### PowerShell

```powershell
# Set variable
$env:VAR = "value"

# Read variable
$env:VAR
$env:PATH

# Remove variable
Remove-Item Env:VAR

# List all
Get-ChildItem Env:
[Environment]::GetEnvironmentVariables()

# Permanent setting
[Environment]::SetEnvironmentVariable("VAR", "value", "User")
[Environment]::SetEnvironmentVariable("VAR", "value", "Machine")
```

### C

```c
#include <stdlib.h>

// Get variable
char *value = getenv("PATH");

// Set variable
setenv("VAR", "value", 1);  // 1 = overwrite existing
putenv("VAR=value");        // Alternative

// Unset variable
unsetenv("VAR");
```

### Python

```python
import os

# Get variable
value = os.environ.get('VAR', 'default')
value = os.environ['VAR']  # Raises KeyError if not set

# Set variable
os.environ['VAR'] = 'value'

# Delete variable
del os.environ['VAR']

# List all
for key, value in os.environ.items():
    print(f"{key}={value}")
```

## 3. TERM Variable and terminfo

The `TERM` variable specifies the terminal type, used to look up capabilities:

```bash
# Common TERM values
xterm
xterm-256color
screen
screen-256color
tmux
tmux-256color
vt100
dumb
linux

# Query terminal capabilities
infocmp $TERM

# Get specific capability
tput colors     # Number of colors
tput cols       # Columns
tput lines      # Lines
tput bold       # Bold capability
tput sgr0       # Reset

# Terminfo database locations
/usr/share/terminfo/
/lib/terminfo/
~/.terminfo/
```

## 4. PATH Variable

```bash
# View PATH
echo "$PATH"
echo "$PATH" | tr ':' '\n'  # One per line

# Add to PATH
export PATH="$PATH:/new/path"       # Append
export PATH="/new/path:$PATH"       # Prepend

# Remove duplicates (bash)
PATH=$(echo "$PATH" | tr ':' '\n' | sort -u | tr '\n' ':')
```

## 5. Locale Variables

| Variable | Description |
|----------|-------------|
| `LANG` | Default locale |
| `LC_ALL` | Override all LC_* |
| `LC_COLLATE` | Sorting order |
| `LC_CTYPE` | Character classification |
| `LC_MESSAGES` | Message language |
| `LC_MONETARY` | Money formatting |
| `LC_NUMERIC` | Number formatting |
| `LC_TIME` | Date/time formatting |

```bash
# View locale settings
locale

# Set UTF-8 locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# List available locales
locale -a
```

## 6. Prompt Customization

### Bash PS1

```bash
# Escape sequences for PS1
\u    # Username
\h    # Hostname (short)
\H    # Hostname (full)
\w    # Current directory (full)
\W    # Current directory (basename)
\d    # Date
\t    # Time (24h)
\T    # Time (12h)
\@    # Time (12h AM/PM)
\n    # Newline
\$    # $ (or # for root)
\!    # History number
\#    # Command number

# Example
export PS1='\u@\h:\w\$ '
```

### Zsh PROMPT

```zsh
# Prompt escape sequences
%n    # Username
%m    # Hostname (short)
%M    # Hostname (full)
%~    # Current directory (~ for home)
%/    # Current directory (full)
%d    # Current directory (full)
%*    # Time (24h with seconds)
%D    # Date

# Example
export PROMPT='%n@%m:%~%# '
```

## 7. Environment Inheritance

```
Parent Process
├── VAR1=value1
├── VAR2=value2
│
└── Child Process (fork)
    ├── VAR1=value1    (inherited)
    ├── VAR2=value2    (inherited)
    └── VAR3=value3    (new, not in parent)
```

## 8. Common Patterns

### Check Variable Set

```bash
# Check if set (empty or not)
if [[ -v VAR ]]; then
    echo "VAR is set (possibly empty)"
fi

# Check if set and non-empty
if [[ -n "${VAR:-}" ]]; then
    echo "VAR is set and non-empty"
fi

# Check if unset or empty
if [[ -z "${VAR:-}" ]]; then
    echo "VAR is unset or empty"
fi
```

### Default Values

```bash
# Use default if unset or empty
echo "${VAR:-default}"

# Set default if unset or empty
: "${VAR:=default}"

# Error if unset or empty
echo "${VAR:?Variable not set}"

# Use alternate if set and non-empty
echo "${VAR:+alternate}"
```

### Exporting Functions (Bash)

```bash
# Export function
my_func() {
    echo "Hello"
}
export -f my_func

# Now available in subshells
bash -c 'my_func'
```
