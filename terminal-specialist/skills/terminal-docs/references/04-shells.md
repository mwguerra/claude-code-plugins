# Shells

## 1. Shell Overview

A shell is a command interpreter that:
- Reads commands from stdin or scripts
- Parses and interprets commands
- Executes programs and built-in commands
- Manages job control
- Provides scripting capabilities

## 2. Common Unix/Linux Shells

| Shell | Path | Description |
|-------|------|-------------|
| **sh** | `/bin/sh` | Bourne shell - POSIX standard |
| **bash** | `/bin/bash` | Bourne Again Shell - most common Linux default |
| **zsh** | `/bin/zsh` | Z shell - macOS default, highly customizable |
| **fish** | `/usr/bin/fish` | Friendly Interactive Shell - user-friendly |
| **dash** | `/bin/dash` | Debian Almquist Shell - fast, minimal |
| **ksh** | `/bin/ksh` | Korn shell - advanced features |
| **tcsh** | `/bin/tcsh` | Enhanced C shell |

## 3. Windows Shells

| Shell | Description |
|-------|-------------|
| **cmd.exe** | Classic Windows command interpreter |
| **PowerShell** | Object-oriented shell with .NET integration |
| **PowerShell Core** | Cross-platform version of PowerShell |
| **WSL Bash** | Linux shells via Windows Subsystem for Linux |

## 4. Shell Startup Files

### Bash

```
Login Shell                    Non-Login Interactive Shell
     │                                    │
     ▼                                    ▼
/etc/profile                        ~/.bashrc
     │
     ▼
~/.bash_profile
(or ~/.bash_login
 or ~/.profile)
     │
     ▼
~/.bashrc (if sourced)
```

| File | When Read | Purpose |
|------|-----------|---------|
| `/etc/profile` | Login shells | System-wide settings |
| `~/.bash_profile` | Login shells | User login settings |
| `~/.bashrc` | Non-login interactive | User interactive settings |
| `~/.bash_logout` | Login shell exit | Cleanup tasks |

### Zsh

| File | When Read |
|------|-----------|
| `/etc/zshenv` | Always |
| `~/.zshenv` | Always |
| `/etc/zprofile` | Login shells |
| `~/.zprofile` | Login shells |
| `/etc/zshrc` | Interactive shells |
| `~/.zshrc` | Interactive shells |
| `/etc/zlogin` | Login shells |
| `~/.zlogin` | Login shells |
| `~/.zlogout` | Login shell exit |

### Fish

| File | When Read |
|------|-----------|
| `~/.config/fish/config.fish` | Every fish session |
| `~/.config/fish/conf.d/*.fish` | Every fish session |
| `~/.config/fish/functions/*.fish` | On demand (autoloaded) |

## 5. Shell Types

```bash
# Check if login shell
shopt -q login_shell && echo "Login shell" || echo "Non-login shell"  # Bash

# Check if interactive
[[ $- == *i* ]] && echo "Interactive" || echo "Non-interactive"

# Force login shell
bash -l
bash --login

# Force non-interactive
bash -c "command"
```

| Type | Description |
|------|-------------|
| Login shell | First shell after login (ssh, console login) |
| Non-login | Subshells, new terminal windows |
| Interactive | Attached to terminal, accepts user input |
| Non-interactive | Running scripts, no user interaction |

## 6. Shell Built-ins vs External Commands

Built-in commands are part of the shell itself:

```bash
# List bash built-ins
enable -a

# Check if command is built-in
type cd      # cd is a shell builtin
type ls      # ls is /bin/ls

# Common built-ins
cd, echo, pwd, export, alias, source, exit, read, test, [, [[
```

### Why Built-ins Matter

- No process fork required (faster)
- Can modify shell state (cd, export)
- Behavior may differ from external commands

## 7. Shell Options

### Bash Options

```bash
# Set options
set -e          # Exit on error
set -u          # Error on undefined variables
set -x          # Print commands before execution
set -o pipefail # Pipeline fails if any command fails

# Combined
set -euo pipefail

# Unset options
set +e

# List all options
set -o

# Shopt options (Bash specific)
shopt -s globstar    # Enable ** glob
shopt -s nullglob    # Glob with no matches returns empty
shopt -u dotglob     # Disable matching hidden files
```

### Common Set Options

| Option | Description |
|--------|-------------|
| `-e` / `errexit` | Exit on non-zero status |
| `-u` / `nounset` | Error on undefined variables |
| `-x` / `xtrace` | Print commands |
| `-v` / `verbose` | Print shell input |
| `-n` / `noexec` | Check syntax only |
| `-f` / `noglob` | Disable filename expansion |
| `-o pipefail` | Pipeline return status |

## 8. PowerShell Specifics

```powershell
# Execution Policy
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned

# Profiles
$PROFILE                           # Current user, current host
$PROFILE.CurrentUserAllHosts       # Current user, all hosts
$PROFILE.AllUsersCurrentHost       # All users, current host
$PROFILE.AllUsersAllHosts          # All users, all hosts

# Error handling
$ErrorActionPreference = "Stop"    # Similar to set -e
$Error                             # Array of recent errors

# Exit codes
$LASTEXITCODE   # Exit code from native commands
$?              # Success status of last command (boolean)
```

## 9. Shell Variables

### Special Variables (Bash)

| Variable | Description |
|----------|-------------|
| `$0` | Script name |
| `$1-$9` | Positional parameters |
| `$#` | Number of arguments |
| `$@` | All arguments (as separate words) |
| `$*` | All arguments (as single word) |
| `$$` | Current shell PID |
| `$!` | Last background process PID |
| `$?` | Last command exit status |
| `$-` | Current shell options |
| `$_` | Last argument of previous command |

### Variable Expansion

```bash
# Default value
${VAR:-default}   # Use default if unset or empty
${VAR:=default}   # Set and use default if unset or empty
${VAR:+value}     # Use value if VAR is set
${VAR:?error}     # Error if unset or empty

# String manipulation
${#VAR}           # Length
${VAR#pattern}    # Remove shortest prefix match
${VAR##pattern}   # Remove longest prefix match
${VAR%pattern}    # Remove shortest suffix match
${VAR%%pattern}   # Remove longest suffix match
${VAR/pat/rep}    # Replace first match
${VAR//pat/rep}   # Replace all matches
```
