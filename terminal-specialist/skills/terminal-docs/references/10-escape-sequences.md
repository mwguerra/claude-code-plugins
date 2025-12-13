# Escape Sequences and Control Characters

## 1. Control Characters

| Char | Ctrl+ | ASCII | Name | Description |
|------|-------|-------|------|-------------|
| `^@` | Ctrl+@ | 0 | NUL | Null |
| `^A` | Ctrl+A | 1 | SOH | Start of heading |
| `^B` | Ctrl+B | 2 | STX | Start of text |
| `^C` | Ctrl+C | 3 | ETX | Interrupt (SIGINT) |
| `^D` | Ctrl+D | 4 | EOT | End of file/input |
| `^E` | Ctrl+E | 5 | ENQ | Enquiry |
| `^F` | Ctrl+F | 6 | ACK | Acknowledge |
| `^G` | Ctrl+G | 7 | BEL | Bell (beep) |
| `^H` | Ctrl+H | 8 | BS | Backspace |
| `^I` | Ctrl+I | 9 | TAB | Horizontal tab |
| `^J` | Ctrl+J | 10 | LF | Line feed (newline) |
| `^K` | Ctrl+K | 11 | VT | Vertical tab |
| `^L` | Ctrl+L | 12 | FF | Form feed (clear screen) |
| `^M` | Ctrl+M | 13 | CR | Carriage return |
| `^N` | Ctrl+N | 14 | SO | Shift out |
| `^O` | Ctrl+O | 15 | SI | Shift in |
| `^Q` | Ctrl+Q | 17 | DC1 | Resume output (XON) |
| `^S` | Ctrl+S | 19 | DC3 | Pause output (XOFF) |
| `^U` | Ctrl+U | 21 | NAK | Kill line |
| `^W` | Ctrl+W | 23 | ETB | Delete word |
| `^Z` | Ctrl+Z | 26 | SUB | Suspend (SIGTSTP) |
| `^[` | Ctrl+[ | 27 | ESC | Escape |
| `^\` | Ctrl+\ | 28 | FS | Quit (SIGQUIT) |
| `^?` | | 127 | DEL | Delete |

## 2. ANSI Escape Sequences

All ANSI sequences start with ESC (`\e`, `\033`, `\x1b`) followed by `[` (CSI - Control Sequence Introducer).

### Escape Representations

| Format | Example | Description |
|--------|---------|-------------|
| `\e` | `\e[31m` | Bash/shell |
| `\033` | `\033[31m` | Octal |
| `\x1b` | `\x1b[31m` | Hexadecimal |
| `^[` | `^[[31m` | Caret notation |

## 3. Cursor Movement

```bash
# Move cursor
\e[H          # Home (1,1)
\e[{r};{c}H   # Move to row r, column c
\e[{r};{c}f   # Same as H

\e[{n}A       # Move up n lines
\e[{n}B       # Move down n lines
\e[{n}C       # Move forward n columns
\e[{n}D       # Move backward n columns

\e[{n}E       # Move to beginning of line n down
\e[{n}F       # Move to beginning of line n up
\e[{n}G       # Move to column n

# Save/restore cursor
\e[s          # Save cursor position (SCO)
\e[u          # Restore cursor position (SCO)
\e7           # Save cursor (DEC)
\e8           # Restore cursor (DEC)
```

## 4. Screen Clearing

```bash
\e[J          # Clear from cursor to end of screen
\e[0J         # Same as above
\e[1J         # Clear from cursor to beginning of screen
\e[2J         # Clear entire screen
\e[3J         # Clear entire screen and scrollback

\e[K          # Clear from cursor to end of line
\e[0K         # Same as above
\e[1K         # Clear from cursor to beginning of line
\e[2K         # Clear entire line
```

## 5. Text Formatting (SGR - Select Graphic Rendition)

```bash
# Format: \e[{attr1};{attr2};...m

\e[0m         # Reset all attributes
\e[1m         # Bold
\e[2m         # Dim
\e[3m         # Italic
\e[4m         # Underline
\e[5m         # Blink
\e[7m         # Reverse video
\e[8m         # Hidden
\e[9m         # Strikethrough

\e[22m        # Normal intensity (not bold/dim)
\e[23m        # Not italic
\e[24m        # Not underlined
\e[25m        # Not blinking
\e[27m        # Not reversed
\e[28m        # Not hidden
\e[29m        # Not strikethrough
```

## 6. Colors

### 4-bit Colors (16 colors)

```bash
# Foreground: 30-37, 90-97 (bright)
# Background: 40-47, 100-107 (bright)

\e[30m        # Black
\e[31m        # Red
\e[32m        # Green
\e[33m        # Yellow
\e[34m        # Blue
\e[35m        # Magenta
\e[36m        # Cyan
\e[37m        # White
\e[39m        # Default foreground

\e[40m        # Black background
\e[41m        # Red background
\e[42m        # Green background
\e[43m        # Yellow background
\e[44m        # Blue background
\e[45m        # Magenta background
\e[46m        # Cyan background
\e[47m        # White background
\e[49m        # Default background

# Bright versions
\e[90m        # Bright black (gray)
\e[91m        # Bright red
...
\e[97m        # Bright white
```

### 8-bit Colors (256 colors)

```bash
\e[38;5;{n}m  # Foreground (n = 0-255)
\e[48;5;{n}m  # Background (n = 0-255)

# Color ranges:
# 0-7: Standard colors
# 8-15: High intensity colors
# 16-231: 216 colors (6x6x6 cube)
# 232-255: Grayscale (24 shades)
```

### 24-bit True Color

```bash
\e[38;2;{r};{g};{b}m  # Foreground RGB
\e[48;2;{r};{g};{b}m  # Background RGB

# Example: Orange text
printf '\e[38;2;255;165;0mOrange text\e[0m\n'
```

## 7. Using tput for Portable Sequences

```bash
# Colors
tput setaf 1      # Red foreground
tput setab 4      # Blue background
tput sgr0         # Reset

# Formatting
tput bold         # Bold
tput dim          # Dim
tput smul         # Start underline
tput rmul         # End underline
tput rev          # Reverse
tput smso         # Start standout
tput rmso         # End standout

# Cursor
tput cup 10 20    # Move to row 10, col 20
tput home         # Move to 0,0
tput sc           # Save cursor
tput rc           # Restore cursor
tput civis        # Hide cursor
tput cnorm        # Show cursor

# Screen
tput clear        # Clear screen
tput el           # Clear to end of line
tput ed           # Clear to end of screen
tput smcup        # Enter alternate screen
tput rmcup        # Exit alternate screen
```

## 8. Alternate Screen Buffer

Many terminal applications use an alternate screen buffer:

```bash
# Enter alternate screen
tput smcup
# or
printf '\e[?1049h'

# Exit alternate screen
tput rmcup
# or
printf '\e[?1049l'
```

## 9. Cursor Visibility

```bash
# Hide cursor
printf '\e[?25l'
tput civis

# Show cursor
printf '\e[?25h'
tput cnorm
```

## 10. Scrolling

```bash
# Set scrolling region (rows n to m)
\e[{n};{m}r

# Scroll up n lines
\e[{n}S

# Scroll down n lines
\e[{n}T

# Reset scrolling region
\e[r
```

## 11. Terminal Queries

```bash
# Query cursor position
printf '\e[6n'
# Response: \e[{row};{col}R

# Query terminal type
printf '\e[c'
# Response: \e[?{params}c

# Query terminal size (xterm)
printf '\e[18t'
# Response: \e[8;{rows};{cols}t
```

## 12. OSC Sequences (Operating System Commands)

```bash
# Set window title
printf '\e]0;Window Title\a'
printf '\e]2;Window Title\a'

# Set icon name
printf '\e]1;Icon Name\a'

# Hyperlinks (some terminals)
printf '\e]8;;https://example.com\e\\Link Text\e]8;;\e\\'
```

## 13. Common Patterns

### Progress Bar

```bash
progress_bar() {
    local width=50
    local percent=$1
    local filled=$((width * percent / 100))
    local empty=$((width - filled))

    printf "\r["
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "] %3d%%" "$percent"
}
```

### Spinner

```bash
spinner() {
    local chars='|/-\'
    local i=0
    while true; do
        printf "\r${chars:$i:1}"
        i=$(((i + 1) % 4))
        sleep 0.1
    done
}
```

### Colored Output Function

```bash
color() {
    local color=$1
    shift
    local text="$*"

    case $color in
        red)     printf '\e[31m%s\e[0m' "$text" ;;
        green)   printf '\e[32m%s\e[0m' "$text" ;;
        yellow)  printf '\e[33m%s\e[0m' "$text" ;;
        blue)    printf '\e[34m%s\e[0m' "$text" ;;
        *)       printf '%s' "$text" ;;
    esac
}
```
