# Exit Codes and Process Termination

## 1. Exit Code Basics

An exit code (or exit status, return code) is an integer value returned by a process when it terminates. This value indicates success or failure to the parent process.

| Platform | Range | Success Value |
|----------|-------|---------------|
| Unix/Linux | 0-255 | 0 |
| Windows | 0-4294967295 (32-bit) | 0 |

## 2. Standard Exit Codes (Unix/Linux)

### POSIX/BSD Standard Codes

| Code | Name | Meaning |
|------|------|---------|
| 0 | `EXIT_SUCCESS` | Success |
| 1 | `EXIT_FAILURE` | General errors |
| 2 | | Misuse of shell command |
| 64 | `EX_USAGE` | Command line usage error |
| 65 | `EX_DATAERR` | Data format error |
| 66 | `EX_NOINPUT` | Cannot open input |
| 67 | `EX_NOUSER` | User doesn't exist |
| 68 | `EX_NOHOST` | Host doesn't exist |
| 69 | `EX_UNAVAILABLE` | Service unavailable |
| 70 | `EX_SOFTWARE` | Internal software error |
| 71 | `EX_OSERR` | System error |
| 72 | `EX_OSFILE` | Critical OS file missing |
| 73 | `EX_CANTCREAT` | Can't create output file |
| 74 | `EX_IOERR` | I/O error |
| 75 | `EX_TEMPFAIL` | Temporary failure |
| 76 | `EX_PROTOCOL` | Protocol error |
| 77 | `EX_NOPERM` | Permission denied |
| 78 | `EX_CONFIG` | Configuration error |
| 126 | | Command not executable |
| 127 | | Command not found |
| 128+N | | Killed by signal N |
| 130 | | Killed by Ctrl+C (SIGINT) |
| 137 | | Killed by SIGKILL (128+9) |
| 143 | | Killed by SIGTERM (128+15) |

## 3. Accessing Exit Codes

### Bash

```bash
# $? contains exit code of last command
command
echo "Exit code: $?"

# Using in conditionals
if command; then
    echo "Success"
else
    echo "Failed with code: $?"
fi

# PIPESTATUS array for pipeline exit codes
cmd1 | cmd2 | cmd3
echo "Exit codes: ${PIPESTATUS[0]} ${PIPESTATUS[1]} ${PIPESTATUS[2]}"

# Exit with specific code
exit 0    # Success
exit 1    # Failure
```

### Zsh

```zsh
# Similar to bash but uses pipestatus (lowercase)
cmd1 | cmd2 | cmd3
echo "Exit codes: ${pipestatus[@]}"
```

### PowerShell

```powershell
# $LASTEXITCODE for native commands
cmd /c exit 42
$LASTEXITCODE  # Returns 42

# $? for PowerShell commands (boolean)
Get-Process
$?  # Returns True or False

# Exit with code
exit 0
```

### cmd.exe

```batch
:: %ERRORLEVEL% contains exit code
command
echo Exit code: %ERRORLEVEL%

:: Conditional execution
command && echo Success || echo Failed

:: Exit with code
exit /b 0
```

### C

```c
#include <stdlib.h>
#include <sys/wait.h>

int main() {
    // Exit with success
    exit(EXIT_SUCCESS);  // or exit(0);

    // Exit with failure
    exit(EXIT_FAILURE);  // or exit(1);

    // From child process
    pid_t pid = fork();
    if (pid == 0) {
        exit(42);  // Child exits with 42
    }

    // Parent waits and gets exit code
    int status;
    wait(&status);

    if (WIFEXITED(status)) {
        int exit_code = WEXITSTATUS(status);
        printf("Child exited with: %d\n", exit_code);
    }

    if (WIFSIGNALED(status)) {
        int signal = WTERMSIG(status);
        printf("Child killed by signal: %d\n", signal);
    }
}
```

### Python

```python
import sys
import subprocess

# Exit with code
sys.exit(0)    # Success
sys.exit(1)    # Failure
sys.exit("Error message")  # Prints to stderr, exits with 1

# Get exit code from subprocess
result = subprocess.run(['ls', '-la'])
print(f"Exit code: {result.returncode}")

# With check=True, raises CalledProcessError on non-zero exit
try:
    subprocess.run(['false'], check=True)
except subprocess.CalledProcessError as e:
    print(f"Command failed with exit code: {e.returncode}")
```

### Node.js

```javascript
// Exit with code
process.exit(0);    // Success
process.exit(1);    // Failure

// Get exit code from child process
const { spawn } = require('child_process');
const child = spawn('ls', ['-la']);
child.on('close', (code) => {
    console.log(`Exit code: ${code}`);
});
```

## 4. Exit Code Truncation

Exit codes are limited to 8 bits (0-255) in Unix/Linux:

```c
exit(256);  // Becomes 0 (256 % 256)
exit(257);  // Becomes 1 (257 % 256)
exit(-1);   // Becomes 255 (unsigned interpretation)
```

## 5. Process Termination Methods

| Method | Description | Exit Code |
|--------|-------------|-----------|
| `exit(n)` | Normal termination | n |
| `_exit(n)` | Immediate termination (no cleanup) | n |
| `return n` | From main() | n |
| Signal | Killed by signal | 128 + signal number |
| `abort()` | Abnormal termination (SIGABRT) | 128 + 6 = 134 |

## 6. Common Signal Exit Codes

| Signal | Number | Exit Code (128+N) |
|--------|--------|-------------------|
| SIGHUP | 1 | 129 |
| SIGINT | 2 | 130 |
| SIGQUIT | 3 | 131 |
| SIGKILL | 9 | 137 |
| SIGTERM | 15 | 143 |
| SIGPIPE | 13 | 141 |
