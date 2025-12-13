# Job Control and Process Management

## 1. Process Groups and Sessions

```
Session (SID)
├── Process Group 1 (Foreground)
│   ├── Process A (Group Leader)
│   └── Process B
├── Process Group 2 (Background Job 1)
│   └── Process C
└── Process Group 3 (Background Job 2)
    ├── Process D (Group Leader)
    └── Process E
```

## 2. Key Concepts

| Concept | Description |
|---------|-------------|
| **Session** | Collection of process groups, led by login shell |
| **Session Leader** | Process that created the session (usually the shell) |
| **Process Group** | Collection of related processes (a job) |
| **Foreground Group** | The process group receiving terminal input |
| **Background Group** | Process groups not receiving terminal input |
| **Controlling Terminal** | Terminal associated with the session |

## 3. Job Control Commands

```bash
# Run command in background
command &

# List jobs
jobs
jobs -l    # Include PIDs
jobs -p    # Only PIDs

# Bring job to foreground
fg %1      # Job number 1
fg %+      # Current job
fg %-      # Previous job
fg %cmd    # Job starting with "cmd"
fg %%      # Current job

# Send job to background
bg %1
bg         # Current stopped job

# Suspend current job
Ctrl+Z     # Sends SIGTSTP

# Disown job (detach from shell)
disown %1
disown -a  # All jobs
disown -h  # Mark job to not receive SIGHUP

# Wait for job
wait %1
wait $pid
wait       # Wait for all background jobs
```

## 4. Job Specifiers

| Specifier | Description |
|-----------|-------------|
| `%n` | Job number n |
| `%+` or `%%` | Current job |
| `%-` | Previous job |
| `%string` | Job beginning with string |
| `%?string` | Job containing string |

## 5. Process States

```
      ┌───────────────────────────────────────────────────┐
      │                                                   │
      ▼                                                   │
  ┌───────┐    fork()    ┌───────┐                       │
  │ READY │◄────────────│ NEW   │                       │
  └───┬───┘              └───────┘                       │
      │                                                   │
      │ scheduled                                         │
      ▼                                                   │
  ┌───────┐                                              │
  │RUNNING│──────────────────────────────────────────────┤
  └───┬───┘                                              │
      │                                                   │
      ├──── I/O or event wait ────►┌─────────┐           │
      │                            │ WAITING │───────────┘
      │                            └─────────┘   event complete
      │
      ├──── SIGSTOP/SIGTSTP ──────►┌─────────┐
      │                            │ STOPPED │
      │◄───── SIGCONT ────────────└─────────┘
      │
      │
      ▼
  ┌────────┐    wait()    ┌────────┐
  │ ZOMBIE │─────────────►│REMOVED │
  └────────┘              └────────┘
```

## 6. Process Control System Calls

```c
#include <unistd.h>
#include <sys/types.h>
#include <signal.h>

// Get IDs
pid_t pid = getpid();      // Process ID
pid_t ppid = getppid();    // Parent process ID
pid_t pgid = getpgrp();    // Process group ID
pid_t sid = getsid(0);     // Session ID

// Set process group
setpgid(pid, pgid);
setpgid(0, 0);  // Make current process group leader

// Create new session
setsid();  // Creates new session, becomes session leader

// Set foreground process group
tcsetpgrp(STDIN_FILENO, pgid);

// Get foreground process group
pid_t fg_pgid = tcgetpgrp(STDIN_FILENO);
```

## 7. The nohup Command

```bash
# Run command immune to hangups
nohup command &

# Output goes to nohup.out by default
nohup command > output.log 2>&1 &

# Modern alternative: disown
command &
disown

# Or prevent hangup signal
command &
disown -h
```

## 8. Background Processes

### Running in Background

```bash
# Start in background
command &

# Move running process to background
Ctrl+Z      # Suspend
bg          # Resume in background

# Keep running after terminal closes
nohup command &
# or
command & disown
# or
setsid command
```

### Background Process I/O

Background processes that try to read from terminal receive SIGTTIN:

```bash
# This will be stopped
cat &      # Tries to read stdin, receives SIGTTIN

# Solution: redirect input
cat < input.txt &
```

## 9. Process Priority (Nice)

```bash
# Start with lower priority
nice -n 10 command

# Change priority of running process
renice -n 10 -p $PID

# Nice values: -20 (highest) to 19 (lowest)
# Only root can set negative values
```

## 10. Daemon Creation

```c
#include <unistd.h>
#include <stdlib.h>
#include <sys/stat.h>

void daemonize() {
    // Fork and exit parent
    pid_t pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);

    // Create new session
    if (setsid() < 0) exit(EXIT_FAILURE);

    // Fork again to prevent terminal acquisition
    pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);

    // Set file permissions
    umask(0);

    // Change to root directory
    chdir("/");

    // Close standard file descriptors
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);

    // Redirect to /dev/null
    open("/dev/null", O_RDONLY);  // stdin
    open("/dev/null", O_WRONLY);  // stdout
    open("/dev/null", O_WRONLY);  // stderr
}
```

## 11. Process Information

```bash
# View process tree
pstree
pstree -p   # With PIDs
pstree -u   # With usernames

# View sessions and process groups
ps -eo pid,ppid,pgid,sid,comm

# View job control info
ps -j

# Interactive process viewer
top
htop
```

## 12. Checking Process State

```bash
# Check if process exists
kill -0 $PID 2>/dev/null && echo "Running" || echo "Not running"

# Get process state
ps -p $PID -o state=
# States: R (running), S (sleeping), D (disk sleep), Z (zombie), T (stopped)
```
