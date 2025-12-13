# Advanced Topics

## 1. Terminal Multiplexers

### tmux

```bash
# Start new session
tmux
tmux new -s session_name

# Attach to session
tmux attach -t session_name
tmux a

# Detach
Ctrl+b d

# Key bindings (after prefix Ctrl+b)
c     # New window
n     # Next window
p     # Previous window
%     # Split horizontally
"     # Split vertically
o     # Switch pane
x     # Kill pane
z     # Zoom pane (toggle)
d     # Detach
[     # Enter copy mode
]     # Paste
:     # Command prompt

# List sessions
tmux ls

# Kill session
tmux kill-session -t session_name
```

### GNU Screen

```bash
# Start session
screen
screen -S session_name

# Detach
Ctrl+a d

# Reattach
screen -r
screen -r session_name

# Key bindings (after prefix Ctrl+a)
c     # New window
n     # Next window
p     # Previous window
|     # Split vertically
S     # Split horizontally
tab   # Switch region
X     # Close region
k     # Kill window
d     # Detach

# List sessions
screen -ls
```

## 2. Terminal Recording

```bash
# script command
script output.txt           # Start recording
# ... commands ...
exit                        # Stop recording

# With timing for playback
script -t 2>timing.txt output.txt
scriptreplay timing.txt output.txt

# asciinema
asciinema rec demo.cast
asciinema play demo.cast
asciinema upload demo.cast
```

## 3. Serial Console Configuration

```bash
# Connect to serial console
screen /dev/ttyUSB0 115200
minicom -D /dev/ttyUSB0 -b 115200
picocom -b 115200 /dev/ttyUSB0

# Configure serial port
stty -F /dev/ttyUSB0 115200 cs8 -cstopb -parenb

# Common baud rates
# 9600, 19200, 38400, 57600, 115200
```

## 4. SSH and PTY Allocation

```bash
# Force PTY allocation
ssh -t user@host command

# Disable PTY allocation
ssh -T user@host command

# Multiple -t for forced allocation (through jump hosts)
ssh -tt user@host command

# Request specific terminal type
ssh -t -e none user@host 'export TERM=xterm-256color; bash'
```

## 5. Unicode and Character Encoding

```bash
# Check current locale
locale

# Set UTF-8 locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Check terminal encoding capability
echo $TERM
locale charmap

# Test Unicode support
echo "Unicode test: Hello World 中文 Emoji test"
printf '\u2603'  # Snowman

# Check file encoding
file -i filename.txt

# Convert encoding
iconv -f ISO-8859-1 -t UTF-8 input.txt > output.txt
```

## 6. Raw Mode Programming Pattern

```c
#include <termios.h>
#include <unistd.h>
#include <stdlib.h>

struct termios orig_termios;

void disable_raw_mode() {
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
}

void enable_raw_mode() {
    tcgetattr(STDIN_FILENO, &orig_termios);
    atexit(disable_raw_mode);

    struct termios raw = orig_termios;

    // Input flags
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);

    // Output flags
    raw.c_oflag &= ~(OPOST);

    // Control flags
    raw.c_cflag |= (CS8);

    // Local flags
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);

    // Control characters
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 1;

    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}
```

## 7. Querying Terminal Capabilities

```bash
# Query terminal for cursor position
printf '\e[6n'
# Response: \e[{row};{col}R

# Query terminal type (device attributes)
printf '\e[c'
# Response: \e[?{params}c

# Query background color (some terminals)
printf '\e]11;?\e\\'

# Query terminal size in pixels
printf '\e[14t'

# Query terminal size in cells
printf '\e[18t'
```

## 8. Mouse Support

### Enable Mouse Tracking

```bash
# Enable mouse tracking
printf '\e[?1000h'  # Basic mouse tracking
printf '\e[?1002h'  # Button event tracking
printf '\e[?1003h'  # All motion tracking

# Disable mouse tracking
printf '\e[?1000l'

# SGR extended mode (better coordinates)
printf '\e[?1006h'
```

### Mouse Event Format

```
Basic mode: \e[Mbxy
  M = button state (32 + button)
  b = 32 + button (0=left, 1=middle, 2=right)
  x = column + 32
  y = row + 32

SGR mode: \e[<button;x;yM (press) or \e[<button;x;ym (release)
```

## 9. Bracketed Paste Mode

```bash
# Enable bracketed paste
printf '\e[?2004h'

# Disable
printf '\e[?2004l'

# Pasted text is wrapped:
# \e[200~ <pasted content> \e[201~
```

## 10. Focus Events

```bash
# Enable focus reporting
printf '\e[?1004h'

# Disable
printf '\e[?1004l'

# Focus in: \e[I
# Focus out: \e[O
```

## 11. OSC Commands

```bash
# Set window title
printf '\e]0;Title\a'
printf '\e]2;Title\a'

# Set clipboard (OSC 52)
printf '\e]52;c;%s\a' "$(echo -n 'text' | base64)"

# Hyperlinks (some terminals)
printf '\e]8;;https://example.com\e\\Link Text\e]8;;\e\\'

# Working directory (some terminals)
printf '\e]7;file://%s%s\a' "$(hostname)" "$(pwd)"

# Notification (iTerm2)
printf '\e]9;Notification text\a'
```

## 12. Terminal Graphics

### Sixel Graphics

```bash
# Check sixel support
printf '\e[c'  # Look for ;4; in response

# Display sixel image (requires sixel-enabled terminal)
img2sixel image.png
```

### Kitty Graphics Protocol

```bash
# Used by Kitty terminal for inline images
# Supports PNG, JPEG, GIF
```

### iTerm2 Image Protocol

```bash
# Display image in iTerm2
printf '\e]1337;File=inline=1:'
base64 < image.png
printf '\a'
```

## 13. Building a Simple Terminal Editor

Key components:
1. Raw mode for character-by-character input
2. Screen clearing and cursor positioning
3. Reading keyboard input
4. Handling special keys (arrows, home, end)
5. Text buffer management
6. Status line display

```c
// Basic structure
while (1) {
    // Refresh screen
    clear_screen();
    draw_rows();
    draw_status_bar();
    position_cursor();

    // Read input
    int c = read_key();

    // Process input
    process_keypress(c);
}
```

## 14. Quick Reference Card

### Essential Commands

| Action | Unix/Linux | Windows (cmd) | PowerShell |
|--------|------------|---------------|------------|
| Clear screen | `clear` | `cls` | `Clear-Host` |
| List directory | `ls -la` | `dir` | `Get-ChildItem` |
| Change directory | `cd path` | `cd path` | `Set-Location` |
| Show current dir | `pwd` | `cd` | `Get-Location` |
| Environment vars | `env` | `set` | `Get-ChildItem Env:` |
| Exit terminal | `exit` | `exit` | `exit` |

### File Descriptors

| FD | Stream | Redirect |
|----|--------|----------|
| 0 | stdin | `< file` |
| 1 | stdout | `> file` |
| 2 | stderr | `2> file` |
| &1 | stdout ref | `2>&1` |

### Common Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Misuse of command |
| 126 | Not executable |
| 127 | Not found |
| 128+N | Killed by signal N |
| 130 | Ctrl+C (SIGINT) |

### Control Characters

| Key | Action |
|-----|--------|
| Ctrl+C | Interrupt (SIGINT) |
| Ctrl+D | EOF |
| Ctrl+Z | Suspend (SIGTSTP) |
| Ctrl+\ | Quit (SIGQUIT) |
| Ctrl+S | Pause output |
| Ctrl+Q | Resume output |
| Ctrl+L | Clear screen |
