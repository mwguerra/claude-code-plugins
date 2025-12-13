# Signal Handling

## 1. Terminal-Related Signals

| Signal | Number | Default Action | Keyboard | Description |
|--------|--------|----------------|----------|-------------|
| `SIGHUP` | 1 | Terminate | | Hangup (terminal closed) |
| `SIGINT` | 2 | Terminate | Ctrl+C | Interrupt |
| `SIGQUIT` | 3 | Core dump | Ctrl+\ | Quit |
| `SIGKILL` | 9 | Terminate | | Kill (cannot be caught) |
| `SIGTERM` | 15 | Terminate | | Graceful termination |
| `SIGTSTP` | 20 | Stop | Ctrl+Z | Terminal stop |
| `SIGCONT` | 18 | Continue | | Continue if stopped |
| `SIGTTIN` | 21 | Stop | | Background read from terminal |
| `SIGTTOU` | 22 | Stop | | Background write to terminal |
| `SIGWINCH` | 28 | Ignore | | Window size changed |
| `SIGPIPE` | 13 | Terminate | | Broken pipe |
| `SIGCHLD` | 17 | Ignore | | Child process status changed |

## 2. Signal Handling in Different Environments

### Bash

```bash
# Trap signals
trap 'echo "Caught SIGINT"' INT
trap 'echo "Caught SIGTERM"' TERM
trap 'cleanup' EXIT

# Ignore signal
trap '' INT

# Reset to default
trap - INT

# List traps
trap -p

# Trap multiple signals
trap 'handler' INT TERM HUP

# Common patterns
cleanup() {
    echo "Cleaning up..."
    rm -f /tmp/tempfile.$$
}
trap cleanup EXIT
```

### C

```c
#include <signal.h>
#include <stdio.h>

void handler(int sig) {
    printf("Caught signal %d\n", sig);
}

int main() {
    // Simple handler
    signal(SIGINT, handler);

    // Using sigaction (preferred)
    struct sigaction sa;
    sa.sa_handler = handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;  // Restart interrupted syscalls
    sigaction(SIGINT, &sa, NULL);

    // Ignore signal
    signal(SIGINT, SIG_IGN);

    // Default handling
    signal(SIGINT, SIG_DFL);

    while(1) pause();
}
```

### Python

```python
import signal
import sys

def handler(signum, frame):
    print(f"Caught signal {signum}")
    sys.exit(0)

# Register handler
signal.signal(signal.SIGINT, handler)
signal.signal(signal.SIGTERM, handler)

# Ignore signal
signal.signal(signal.SIGPIPE, signal.SIG_IGN)

# Use default handler
signal.signal(signal.SIGINT, signal.SIG_DFL)

# Context manager for temporary handler
from contextlib import contextmanager

@contextmanager
def signal_handler(sig, handler):
    old_handler = signal.signal(sig, handler)
    try:
        yield
    finally:
        signal.signal(sig, old_handler)
```

### Node.js

```javascript
// Handle signals
process.on('SIGINT', () => {
    console.log('Caught SIGINT');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('Caught SIGTERM');
    // Graceful shutdown
    server.close(() => {
        process.exit(0);
    });
});

// Ignore SIGPIPE
process.on('SIGPIPE', () => {});
```

## 3. Sending Signals

```bash
# By PID
kill -SIGTERM 1234
kill -15 1234
kill 1234           # SIGTERM by default

# By name
kill -SIGKILL 1234
kill -9 1234

# To process group
kill -SIGTERM -1234

# To job
kill %1

# Common signals
kill -SIGHUP 1234    # Reload configuration
kill -SIGINT 1234    # Interrupt (like Ctrl+C)
kill -SIGTERM 1234   # Graceful termination
kill -SIGKILL 1234   # Force kill (cannot be caught)
kill -SIGSTOP 1234   # Pause process (cannot be caught)
kill -SIGCONT 1234   # Resume process
kill -SIGUSR1 1234   # User-defined signal 1
kill -SIGUSR2 1234   # User-defined signal 2

# pkill and killall
pkill -SIGTERM processname
pkill -f "pattern"   # Match full command line
killall -SIGTERM processname
```

## 4. Signal Numbers

| Signal | Linux | macOS |
|--------|-------|-------|
| SIGHUP | 1 | 1 |
| SIGINT | 2 | 2 |
| SIGQUIT | 3 | 3 |
| SIGKILL | 9 | 9 |
| SIGUSR1 | 10 | 30 |
| SIGUSR2 | 12 | 31 |
| SIGTERM | 15 | 15 |
| SIGCHLD | 17 | 20 |
| SIGCONT | 18 | 19 |
| SIGSTOP | 19 | 17 |
| SIGTSTP | 20 | 18 |
| SIGWINCH | 28 | 28 |

```bash
# List all signals
kill -l

# Get signal number
kill -l SIGTERM  # Returns 15
```

## 5. Signal Safety

### Async-Signal-Safe Functions

Only certain functions are safe to call from signal handlers:

```c
// Safe to call
_exit(), write(), signal()

// NOT safe (may cause undefined behavior)
printf(), malloc(), free()
```

### Safe Signal Handler Pattern

```c
volatile sig_atomic_t got_signal = 0;

void handler(int sig) {
    got_signal = 1;  // Just set flag
}

int main() {
    signal(SIGINT, handler);

    while (!got_signal) {
        // Main loop
    }

    // Handle signal safely here
    printf("Signal received\n");
}
```

## 6. Signal Masks

```c
#include <signal.h>

sigset_t set, oldset;

// Initialize empty set
sigemptyset(&set);

// Add signal to set
sigaddset(&set, SIGINT);
sigaddset(&set, SIGTERM);

// Block signals
sigprocmask(SIG_BLOCK, &set, &oldset);

// Critical section - signals blocked

// Unblock signals
sigprocmask(SIG_SETMASK, &oldset, NULL);

// Wait for signal
int sig;
sigwait(&set, &sig);
```

## 7. Common Patterns

### Graceful Shutdown

```bash
#!/bin/bash
cleanup() {
    echo "Shutting down..."
    # Stop services
    # Save state
    # Remove temp files
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main application
while true; do
    # do work
    sleep 1
done
```

### Reload Configuration

```bash
#!/bin/bash
reload_config() {
    echo "Reloading configuration..."
    source /etc/myapp/config
}

trap reload_config SIGHUP

while true; do
    # Main loop
    sleep 1
done
```

### Child Process Handling

```c
void sigchld_handler(int sig) {
    int status;
    pid_t pid;

    // Reap all terminated children
    while ((pid = waitpid(-1, &status, WNOHANG)) > 0) {
        if (WIFEXITED(status)) {
            printf("Child %d exited with %d\n",
                   pid, WEXITSTATUS(status));
        }
    }
}

int main() {
    struct sigaction sa;
    sa.sa_handler = sigchld_handler;
    sa.sa_flags = SA_RESTART | SA_NOCLDSTOP;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGCHLD, &sa, NULL);
    // ...
}
```

## 8. Real-time Signals

```c
// Real-time signals: SIGRTMIN to SIGRTMAX
// Guaranteed delivery and queuing

union sigval value;
value.sival_int = 42;

sigqueue(pid, SIGRTMIN, value);
```
