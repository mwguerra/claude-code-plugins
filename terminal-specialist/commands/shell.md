---
description: Shell configuration guide - startup files, environment variables, and shell options for bash/zsh
---

# Shell Configuration Guide

You are providing shell configuration help. Follow these steps:

## 1. Query

The user needs help with: $ARGUMENTS

## 2. Read Documentation

Read the shells documentation:
`skills/terminal-docs/references/04-shells.md`

## 3. Common Shells

| Shell | Default Path | Notes |
|-------|-------------|-------|
| bash | /bin/bash | Linux default |
| zsh | /bin/zsh | macOS default |
| fish | /usr/bin/fish | User-friendly |
| dash | /bin/dash | Fast, POSIX |

## 4. Startup Files

### Bash
| File | When |
|------|------|
| ~/.bash_profile | Login shells |
| ~/.bashrc | Interactive shells |
| ~/.bash_logout | On exit |

### Zsh
| File | When |
|------|------|
| ~/.zshenv | Always |
| ~/.zprofile | Login shells |
| ~/.zshrc | Interactive |

## 5. Shell Options

### Bash
```bash
set -e           # Exit on error
set -u           # Error on undefined
set -x           # Debug mode
set -o pipefail  # Pipeline errors
```

### Check Shell Type
```bash
# Login shell?
shopt -q login_shell && echo "Login"

# Interactive?
[[ $- == *i* ]] && echo "Interactive"
```

## 6. Provide Response

Based on the user's query:
1. Identify the shell they're using
2. Explain relevant startup files
3. Provide configuration examples
4. Note differences between shell types
5. Include testing/verification steps
