# Redirection and Pipes

## 1. Basic Redirection (Bash)

```bash
# Output redirection
command > file          # Redirect stdout (overwrite)
command >> file         # Redirect stdout (append)
command 2> file         # Redirect stderr
command 2>> file        # Redirect stderr (append)
command &> file         # Redirect both stdout and stderr
command > file 2>&1     # Redirect stderr to stdout
command &>> file        # Append both (Bash 4+)

# Input redirection
command < file          # Redirect stdin from file
command << EOF          # Here document
content
EOF
command <<< "string"    # Here string

# Null redirection
command > /dev/null     # Discard stdout
command 2> /dev/null    # Discard stderr
command &> /dev/null    # Discard both
```

## 2. File Descriptor Manipulation

```bash
# File descriptor manipulation
exec 3> file            # Open fd 3 for writing
exec 3< file            # Open fd 3 for reading
exec 3<> file           # Open fd 3 for read/write
exec 3>&-               # Close fd 3

# Duplicate file descriptors
command 2>&1            # Duplicate fd 1 to fd 2
command >&2             # Redirect stdout to stderr

# Move file descriptors
exec 3>&1               # Copy stdout to fd 3
exec 1>&4               # Restore stdout from fd 4

# Open file for specific purpose
exec 3< input.txt       # Open for reading
exec 4> output.txt      # Open for writing
read line <&3           # Read from fd 3
echo "data" >&4         # Write to fd 4
exec 3<&-               # Close fd 3
exec 4>&-               # Close fd 4
```

## 3. Advanced Redirection

```bash
# Swap stdout and stderr
command 3>&1 1>&2 2>&3 3>&-

# Redirect to multiple destinations
command | tee file              # stdout to file and stdout
command | tee -a file           # Append
command 2>&1 | tee file         # Both streams

# Process substitution
diff <(command1) <(command2)    # Compare outputs
command > >(process)            # Output through process
command < <(process)            # Input from process

# Named pipes (FIFOs)
mkfifo mypipe
command1 > mypipe &
command2 < mypipe
rm mypipe
```

## 4. Here Documents

```bash
# Basic here document
cat << EOF
Line 1
Line 2
Variable: $VAR
EOF

# Quoted delimiter (no expansion)
cat << 'EOF'
Line 1
$VAR is not expanded
EOF

# Remove leading tabs
cat <<- EOF
	This line has a tab
	Tabs are removed
EOF
```

## 5. Pipes

```bash
# Simple pipe
command1 | command2

# Pipeline with error handling
set -o pipefail
command1 | command2 | command3

# Check individual exit codes
cmd1 | cmd2 | cmd3
echo "${PIPESTATUS[@]}"    # Array of exit codes
echo "${PIPESTATUS[0]}"    # First command's exit code

# Named pipe (FIFO)
mkfifo /tmp/mypipe
producer > /tmp/mypipe &
consumer < /tmp/mypipe
```

## 6. Tee and Process Substitution

```bash
# tee - split output
command | tee file                    # Write to file and stdout
command | tee file1 file2             # Multiple files
command | tee -a file                 # Append
command 2>&1 | tee file               # Include stderr

# Process substitution
# Write to multiple processes
command | tee >(process1) >(process2) > /dev/null

# Compare outputs
diff <(sort file1) <(sort file2)

# Log and display
command | tee >(logger -t myapp)
```

## 7. PowerShell Redirection

```powershell
# Output streams in PowerShell
# 1 - Success output (stdout)
# 2 - Error output (stderr)
# 3 - Warning
# 4 - Verbose
# 5 - Debug
# 6 - Information
# * - All streams

# Redirection
command > file          # Redirect success stream
command 2> file         # Redirect error stream
command *> file         # Redirect all streams
command >> file         # Append

# Redirect to $null (discard)
command > $null
command 2> $null

# Redirect stream to another stream
command 2>&1            # Errors to success stream

# Piping (object pipeline, not text)
Get-Process | Where-Object {$_.CPU -gt 100} | Sort-Object CPU
```

## 8. Windows cmd.exe Redirection

```batch
:: Output redirection
command > file
command >> file         :: Append
command 2> file         :: Stderr
command 2>&1           :: Stderr to stdout
command > file 2>&1    :: Both to file

:: Input redirection
command < file

:: Pipe
command1 | command2

:: NUL device (like /dev/null)
command > NUL
command 2> NUL
```

## 9. Common Patterns

### Log Both to File and Display

```bash
# Using tee
command 2>&1 | tee -a logfile

# Using process substitution
command > >(tee -a stdout.log) 2> >(tee -a stderr.log >&2)
```

### Capture Output and Exit Code

```bash
# Capture output
output=$(command)
exitcode=$?

# Capture with stderr
output=$(command 2>&1)

# Capture separately
{ output=$(command 2>&1 1>&3 3>&-); } 3>&1
stderr=$output
```

### Redirect Stdout and Stderr to Different Files

```bash
command > stdout.log 2> stderr.log
```

### Filter Errors

```bash
# Show only errors
command 2>&1 >/dev/null

# Suppress only errors
command 2>/dev/null
```

### Append with Timestamp

```bash
command 2>&1 | while read line; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') $line"
done >> logfile
```

## 10. Special File Descriptors

| Path | Description |
|------|-------------|
| `/dev/stdin` | Standard input (fd 0) |
| `/dev/stdout` | Standard output (fd 1) |
| `/dev/stderr` | Standard error (fd 2) |
| `/dev/null` | Discard output |
| `/dev/zero` | Infinite zeros |
| `/dev/tty` | Current terminal |
| `/dev/fd/N` | File descriptor N |

## 11. Coprocess

```bash
# Bash coprocess
coproc myproc { command; }
echo "input" >&${myproc[1]}
read output <&${myproc[0]}
```
