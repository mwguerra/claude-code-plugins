# Terminal Fundamentals

## 1. What is a Terminal?

A **terminal** (or terminal emulator) is a program that provides a text-based interface for interacting with a computer's operating system through a shell. Historically, terminals were physical hardware devices (teletypewriters/TTYs), but modern terminals are software emulations.

## 2. Key Terminology

| Term | Definition |
|------|------------|
| **TTY** | Teletypewriter - the original hardware terminals; now refers to terminal devices in Unix |
| **PTY** | Pseudo-terminal - a software emulation of a terminal device |
| **Console** | The primary terminal connected directly to the system (physical or virtual) |
| **Terminal Emulator** | Software that emulates a hardware terminal (e.g., xterm, GNOME Terminal, iTerm2, Windows Terminal) |
| **Shell** | Command interpreter that runs inside a terminal (e.g., bash, zsh, PowerShell) |
| **Command Line** | The text interface where commands are entered |

## 3. The Terminal Stack

```
┌─────────────────────────────────────────┐
│           User Input/Output             │
├─────────────────────────────────────────┤
│         Terminal Emulator               │
│    (xterm, Windows Terminal, iTerm2)    │
├─────────────────────────────────────────┤
│         PTY (Pseudo-Terminal)           │
│         Master ←──→ Slave               │
├─────────────────────────────────────────┤
│              Shell                      │
│      (bash, zsh, PowerShell, cmd)       │
├─────────────────────────────────────────┤
│         Operating System                │
│      (Kernel, System Calls)             │
└─────────────────────────────────────────┘
```

## 4. PTY Architecture (Unix/Linux)

A pseudo-terminal consists of two parts:

- **PTY Master**: Held by the terminal emulator; receives input and sends output
- **PTY Slave**: Attached to the shell/process; appears as a real terminal device

```
Terminal Emulator ←→ PTY Master ←→ PTY Slave ←→ Shell ←→ Child Processes
       ↑                                            ↓
   User sees                                   Commands run
    output                                      and produce
                                                 output
```

## 5. Device Files (Unix/Linux)

| Path | Description |
|------|-------------|
| `/dev/tty` | Current controlling terminal |
| `/dev/tty[0-63]` | Virtual console devices |
| `/dev/pts/*` | Pseudo-terminal slave devices |
| `/dev/ptmx` | PTY master multiplexor |
| `/dev/console` | System console |
| `/dev/null` | Null device (discards all input) |
| `/dev/zero` | Produces infinite null bytes |
| `/dev/stdin` | Symlink to fd 0 |
| `/dev/stdout` | Symlink to fd 1 |
| `/dev/stderr` | Symlink to fd 2 |

## 6. Terminal Emulators

### Common Terminal Emulators

| Platform | Terminal Emulators |
|----------|-------------------|
| Linux | GNOME Terminal, Konsole, xterm, Alacritty, Kitty, Terminator |
| macOS | Terminal.app, iTerm2, Alacritty, Kitty, Hyper |
| Windows | Windows Terminal, ConHost, ConEmu, Cmder, Hyper |
| Cross-platform | Alacritty, Kitty, Hyper, Warp |

### Terminal Capabilities

Terminals vary in their feature support:

| Feature | Description |
|---------|-------------|
| True color (24-bit) | 16 million colors |
| 256 colors | Extended color palette |
| Unicode | Full character set support |
| Ligatures | Font ligature rendering |
| GPU acceleration | Hardware-accelerated rendering |
| Sixel graphics | Inline image display |
| OSC 52 | Clipboard integration |

## 7. Building a Terminal Emulator

Understanding how to build a terminal emulator reveals the full complexity of terminal systems.

### Core Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                    Terminal Emulator Application                    │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │
│  │   Input     │  │   Parser    │  │  Terminal   │  │  Renderer │ │
│  │  Handler    │──▶│  (VT/ANSI) │──▶│   State    │──▶│  (Grid)   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘ │
│        ▲                                                    │      │
│        │                                                    ▼      │
│  ┌─────────────┐                                    ┌───────────┐ │
│  │  Keyboard   │                                    │  Display  │ │
│  │   Events    │                                    │  (GPU/SW) │ │
│  └─────────────┘                                    └───────────┘ │
│                                                                     │
├────────────────────────────────────────────────────────────────────┤
│                         PTY Interface                               │
│                    (read/write to child process)                    │
└────────────────────────────────────────────────────────────────────┘
```

### Essential Components

#### 1. PTY Management

The terminal emulator must create and manage a pseudo-terminal pair:

```c
// Unix/Linux: Create PTY pair
#include <pty.h>
#include <utmp.h>

int master_fd, slave_fd;
char slave_name[256];

// Create PTY pair
if (openpty(&master_fd, &slave_fd, slave_name, NULL, NULL) == -1) {
    perror("openpty");
    exit(1);
}

// Fork child process
pid_t pid = fork();
if (pid == 0) {
    // Child: becomes the shell
    close(master_fd);
    setsid();                          // Create new session
    ioctl(slave_fd, TIOCSCTTY, 0);     // Set controlling terminal

    // Redirect stdio to PTY slave
    dup2(slave_fd, STDIN_FILENO);
    dup2(slave_fd, STDOUT_FILENO);
    dup2(slave_fd, STDERR_FILENO);
    close(slave_fd);

    // Execute shell
    execlp("/bin/bash", "bash", NULL);
} else {
    // Parent: terminal emulator
    close(slave_fd);
    // master_fd is used for all I/O with child
}
```

#### 2. Terminal State (Screen Buffer)

The terminal maintains a grid of cells representing the screen:

```c
typedef struct {
    uint32_t codepoint;      // Unicode character
    uint32_t fg_color;       // Foreground color (RGB or indexed)
    uint32_t bg_color;       // Background color
    uint8_t  attributes;     // Bold, italic, underline, etc.
    uint8_t  width;          // Character width (1 or 2 for wide chars)
} Cell;

typedef struct {
    Cell *cells;             // Grid of cells (rows * cols)
    int rows;
    int cols;
    int cursor_row;
    int cursor_col;
    int scroll_top;          // Scroll region top
    int scroll_bottom;       // Scroll region bottom

    // Saved cursor state (for ESC 7 / ESC 8)
    int saved_cursor_row;
    int saved_cursor_col;

    // Current attributes for new characters
    uint32_t current_fg;
    uint32_t current_bg;
    uint8_t current_attrs;

    // Modes
    bool cursor_visible;
    bool origin_mode;        // DECOM
    bool autowrap;           // DECAWM
    bool insert_mode;
    bool application_cursor; // DECCKM
    bool bracketed_paste;
    bool mouse_tracking;
    bool alternate_screen;   // Alternate screen buffer

    // Alternate screen buffer
    Cell *alt_cells;
    int alt_cursor_row;
    int alt_cursor_col;
} TerminalState;
```

#### 3. VT/ANSI Parser

A state machine that parses escape sequences from the PTY output:

```c
typedef enum {
    STATE_GROUND,           // Normal character processing
    STATE_ESCAPE,           // After ESC
    STATE_CSI_ENTRY,        // After ESC [
    STATE_CSI_PARAM,        // Reading CSI parameters
    STATE_CSI_INTERMEDIATE, // CSI intermediate bytes
    STATE_OSC_STRING,       // Operating System Command
    STATE_DCS_ENTRY,        // Device Control String
    // ... more states
} ParserState;

typedef struct {
    ParserState state;
    int params[16];         // Numeric parameters
    int param_count;
    char intermediates[4];  // Intermediate characters
    int intermediate_count;
    char osc_string[4096];  // OSC string buffer
    int osc_len;
} Parser;

void parse_byte(Parser *p, TerminalState *term, uint8_t byte) {
    switch (p->state) {
    case STATE_GROUND:
        if (byte == 0x1B) {  // ESC
            p->state = STATE_ESCAPE;
        } else if (byte >= 0x20 && byte < 0x7F) {
            // Printable character
            put_char(term, byte);
        } else if (byte < 0x20) {
            // Control character (CR, LF, BS, TAB, etc.)
            handle_control_char(term, byte);
        }
        break;

    case STATE_ESCAPE:
        if (byte == '[') {
            p->state = STATE_CSI_ENTRY;
            p->param_count = 0;
        } else if (byte == ']') {
            p->state = STATE_OSC_STRING;
            p->osc_len = 0;
        } else if (byte == '7') {
            save_cursor(term);
            p->state = STATE_GROUND;
        } else if (byte == '8') {
            restore_cursor(term);
            p->state = STATE_GROUND;
        }
        // ... handle other escape sequences
        break;

    case STATE_CSI_PARAM:
        if (byte >= '0' && byte <= '9') {
            // Accumulate parameter digit
            p->params[p->param_count] = p->params[p->param_count] * 10 + (byte - '0');
        } else if (byte == ';') {
            // Next parameter
            p->param_count++;
        } else if (byte >= 0x40 && byte <= 0x7E) {
            // Final byte - execute CSI sequence
            execute_csi(term, p, byte);
            p->state = STATE_GROUND;
        }
        break;

    // ... other states
    }
}

void execute_csi(TerminalState *term, Parser *p, char final) {
    int n = p->params[0] ? p->params[0] : 1;  // Default to 1

    switch (final) {
    case 'A': cursor_up(term, n); break;
    case 'B': cursor_down(term, n); break;
    case 'C': cursor_forward(term, n); break;
    case 'D': cursor_backward(term, n); break;
    case 'H': cursor_position(term, p->params[0], p->params[1]); break;
    case 'J': erase_in_display(term, p->params[0]); break;
    case 'K': erase_in_line(term, p->params[0]); break;
    case 'm': set_graphics_rendition(term, p); break;  // Colors/attributes
    // ... many more
    }
}
```

#### 4. Input Handling

Convert keyboard events to escape sequences for the PTY:

```c
void handle_key(int master_fd, KeyEvent *event) {
    char buf[32];
    int len = 0;

    if (event->key == KEY_ENTER) {
        buf[0] = '\r';  // Carriage return
        len = 1;
    } else if (event->key == KEY_BACKSPACE) {
        buf[0] = 0x7F;  // DEL or 0x08 (BS) depending on mode
        len = 1;
    } else if (event->key == KEY_UP) {
        // Application mode vs normal mode
        if (application_cursor_mode) {
            len = sprintf(buf, "\x1bOA");
        } else {
            len = sprintf(buf, "\x1b[A");
        }
    } else if (event->key == KEY_DOWN) {
        len = sprintf(buf, application_cursor_mode ? "\x1bOB" : "\x1b[B");
    } else if (event->key == KEY_RIGHT) {
        len = sprintf(buf, application_cursor_mode ? "\x1bOC" : "\x1b[C");
    } else if (event->key == KEY_LEFT) {
        len = sprintf(buf, application_cursor_mode ? "\x1bOD" : "\x1b[D");
    } else if (event->key == KEY_HOME) {
        len = sprintf(buf, "\x1b[H");
    } else if (event->key == KEY_END) {
        len = sprintf(buf, "\x1b[F");
    } else if (event->key == KEY_F1) {
        len = sprintf(buf, "\x1bOP");  // Or \x1b[11~ depending on terminal
    } else if (event->ctrl && event->key >= 'a' && event->key <= 'z') {
        // Ctrl+letter produces control character
        buf[0] = event->key - 'a' + 1;  // Ctrl+A = 0x01, etc.
        len = 1;
    } else if (event->unicode) {
        // Regular character - encode as UTF-8
        len = encode_utf8(buf, event->unicode);
    }

    // Handle bracketed paste mode
    if (event->is_paste && bracketed_paste_mode) {
        write(master_fd, "\x1b[200~", 6);
        write(master_fd, event->paste_text, event->paste_len);
        write(master_fd, "\x1b[201~", 6);
    } else if (len > 0) {
        write(master_fd, buf, len);
    }
}
```

#### 5. Rendering

Draw the terminal state to the screen:

```c
void render_terminal(TerminalState *term, Renderer *r) {
    for (int row = 0; row < term->rows; row++) {
        for (int col = 0; col < term->cols; col++) {
            Cell *cell = &term->cells[row * term->cols + col];

            // Set colors
            set_foreground(r, cell->fg_color);
            set_background(r, cell->bg_color);

            // Apply attributes
            if (cell->attributes & ATTR_BOLD) set_bold(r, true);
            if (cell->attributes & ATTR_ITALIC) set_italic(r, true);
            if (cell->attributes & ATTR_UNDERLINE) set_underline(r, true);
            if (cell->attributes & ATTR_REVERSE) {
                // Swap fg/bg
                swap_colors(r);
            }

            // Calculate pixel position
            int x = col * font_cell_width;
            int y = row * font_cell_height;

            // Draw background
            fill_rect(r, x, y, font_cell_width, font_cell_height);

            // Draw character (handle wide characters)
            if (cell->codepoint != 0 && cell->codepoint != ' ') {
                draw_glyph(r, x, y, cell->codepoint);
            }

            // Skip next cell if wide character
            if (cell->width == 2) col++;
        }
    }

    // Draw cursor
    if (term->cursor_visible) {
        int x = term->cursor_col * font_cell_width;
        int y = term->cursor_row * font_cell_height;
        draw_cursor(r, x, y, cursor_style);
    }
}
```

### Main Event Loop

```c
int main() {
    // Initialize window/graphics
    Window *window = create_window(80 * font_width, 24 * font_height);

    // Create PTY and spawn shell
    int master_fd = create_pty_and_spawn_shell();

    // Initialize terminal state
    TerminalState term = {0};
    term.rows = 24;
    term.cols = 80;
    term.cells = calloc(term.rows * term.cols, sizeof(Cell));

    // Initialize parser
    Parser parser = {0};

    // Main loop
    while (running) {
        // Handle window/input events
        Event event;
        while (poll_event(&event)) {
            if (event.type == EVENT_KEY) {
                handle_key(master_fd, &event.key);
            } else if (event.type == EVENT_RESIZE) {
                // Update terminal size
                term.rows = event.resize.height / font_height;
                term.cols = event.resize.width / font_width;
                resize_cells(&term);

                // Notify PTY of new size
                struct winsize ws = {term.rows, term.cols, 0, 0};
                ioctl(master_fd, TIOCSWINSZ, &ws);
            } else if (event.type == EVENT_CLOSE) {
                running = false;
            }
        }

        // Read output from PTY
        char buf[4096];
        ssize_t n = read(master_fd, buf, sizeof(buf));
        if (n > 0) {
            for (int i = 0; i < n; i++) {
                parse_byte(&parser, &term, buf[i]);
            }
        }

        // Render
        render_terminal(&term, renderer);
        present(window);
    }

    return 0;
}
```

### Key Challenges in Building a Terminal Emulator

| Challenge | Description |
|-----------|-------------|
| **Escape Sequence Parsing** | Hundreds of sequences to support (VT100, VT220, xterm, etc.) |
| **Unicode & Wide Characters** | Handle multi-byte UTF-8, combining characters, emoji, CJK |
| **Performance** | Efficient rendering for large scrollback, fast output |
| **Correctness** | Match behavior of reference terminals (xterm, VT100) |
| **Font Rendering** | Monospace alignment, ligatures, fallback fonts |
| **Selection & Clipboard** | Mouse selection, copy/paste integration |
| **Scrollback Buffer** | Efficient storage for thousands of lines |
| **Sixel/Graphics** | Inline image protocols |
| **OSC Sequences** | Hyperlinks, notifications, clipboard |

### Required Knowledge Areas

1. **Operating Systems**
   - Process creation (fork/exec)
   - PTY/TTY subsystem
   - Signal handling
   - File descriptor I/O

2. **Text Processing**
   - Unicode (UTF-8, code points, grapheme clusters)
   - Character width (wcwidth)
   - Bidirectional text (optional)

3. **VT/ANSI Standards**
   - Control characters
   - Escape sequences (CSI, OSC, DCS)
   - Terminal modes
   - Character attributes

4. **Graphics**
   - 2D rendering (software or GPU)
   - Font rasterization
   - Color management

5. **Event Handling**
   - Keyboard input mapping
   - Mouse events
   - Window management

### Reference Implementations

| Terminal | Language | Notes |
|----------|----------|-------|
| xterm | C | Reference implementation, most complete |
| Alacritty | Rust | GPU-accelerated, modern |
| Kitty | C/Python | GPU-accelerated, extensible |
| st | C | Simple, minimal (~2000 lines) |
| VTE | C | Library used by GNOME Terminal |
| Windows Terminal | C++ | Modern Windows terminal |
| mintty | C | Cygwin/MSYS2 terminal |

### Testing Your Terminal

```bash
# Test basic functionality
vttest              # Comprehensive VT compatibility test
tput colors         # Check color support
echo -e "\e[31mRed\e[0m"  # Basic color test

# Test Unicode
echo "Hello 世界 🎉"
printf '\u2603'     # Snowman

# Test cursor movement
tput cup 10 20; echo "Here"

# Test alternate screen
tput smcup; sleep 2; tput rmcup
```
